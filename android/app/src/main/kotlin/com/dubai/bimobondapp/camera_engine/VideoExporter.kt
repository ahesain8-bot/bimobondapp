package com.dubai.bimobondapp.camera_engine

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.max
import kotlin.math.min

/**
 * Phase 11: production-safe export / compression.
 *
 * Default profile: ≤1080×1920, 30 FPS, H.264, ~8 Mbps.
 * - Never loads the full video into RAM (Media3 Transformer streams).
 * - Prefer hardware encode; transmux/passthrough when already within profile.
 * - 4K sources are downscaled before encode.
 */
@OptIn(UnstableApi::class)
class VideoExporter(private val context: Context) {
    companion object {
        private const val TAG = "VideoExporter"

        /** Portrait short-side / long-side caps (9:16). */
        const val MAX_WIDTH = 1080
        const val MAX_HEIGHT = 1920
        const val TARGET_FPS = 30
        /** Mid of 6–10 Mbps band for 1080p. */
        const val TARGET_BITRATE = 8_000_000
        /** Skip re-encode when estimated bitrate is at/under this. */
        const val PASSTHROUGH_BITRATE = 10_000_000
        const val PASSTHROUGH_MAX_BYTES = 150L * 1024L * 1024L
    }

    data class Probe(
        val width: Int,
        val height: Int,
        val durationMs: Long,
        val rotation: Int,
        val fileBytes: Long,
        val estimatedBitrate: Long,
    ) {
        val needsDownscale: Boolean
            get() {
                val w = if (rotation % 180 != 0) height else width
                val h = if (rotation % 180 != 0) width else height
                return w > MAX_WIDTH || h > MAX_HEIGHT
            }

        val withinProfile: Boolean
            get() = !needsDownscale &&
                fileBytes in 1..PASSTHROUGH_MAX_BYTES &&
                (estimatedBitrate <= 0L || estimatedBitrate <= PASSTHROUGH_BITRATE)
    }

    data class ExportOutcome(
        val ok: Boolean,
        val path: String? = null,
        val passthrough: Boolean = false,
        val width: Int = 0,
        val height: Int = 0,
        val fileBytes: Long = 0L,
        val error: String? = null,
    )

    private val mainHandler = Handler(Looper.getMainLooper())
    private val exporting = AtomicBoolean(false)
    private val progressPct = AtomicInteger(0)
    @Volatile
    private var transformer: Transformer? = null
    @Volatile
    private var pendingComplete: ((ExportOutcome) -> Unit)? = null
    @Volatile
    private var pendingOutput: File? = null

    fun isExporting(): Boolean = exporting.get()
    fun progressPercent(): Int = progressPct.get()

    fun probe(input: File): Probe? {
        if (!input.exists() || input.length() == 0L) return null
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(input.absolutePath)
            val w = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull() ?: 0
            val h = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull() ?: 0
            val dur = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            val rot = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            val bitrateMeta = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
                ?.toLongOrNull() ?: 0L
            val bytes = input.length()
            val estimated = when {
                bitrateMeta > 0L -> bitrateMeta
                dur > 0L -> (bytes * 8L * 1000L) / dur
                else -> 0L
            }
            Probe(
                width = w,
                height = h,
                durationMs = dur,
                rotation = rot,
                fileBytes = bytes,
                estimatedBitrate = estimated,
            )
        } catch (t: Throwable) {
            Log.w(TAG, "probe failed", t)
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }
    }

    /**
     * Export [input] to [output]. Passthrough-copies when already within profile
     * unless [force] is true.
     */
    fun export(
        input: File,
        output: File,
        force: Boolean = false,
        onProgress: ((Int) -> Unit)? = null,
        onComplete: (ExportOutcome) -> Unit,
    ) {
        if (!exporting.compareAndSet(false, true)) {
            onComplete(ExportOutcome(ok = false, error = "export_in_progress"))
            return
        }
        progressPct.set(0)
        synchronized(this) {
            pendingComplete = onComplete
            pendingOutput = output
        }
        onProgress?.invoke(0)

        val probe = probe(input)
        if (probe == null) {
            finish(ExportOutcome(ok = false, error = "probe_failed"))
            return
        }

        if (!force && probe.withinProfile) {
            return try {
                output.parentFile?.mkdirs()
                output.delete()
                input.copyTo(output, overwrite = true)
                progressPct.set(100)
                onProgress?.invoke(100)
                finish(
                    ExportOutcome(
                        ok = true,
                        path = output.absolutePath,
                        passthrough = true,
                        width = displayWidth(probe),
                        height = displayHeight(probe),
                        fileBytes = output.length(),
                    ),
                )
            } catch (t: Throwable) {
                finish(ExportOutcome(ok = false, error = t.message ?: "passthrough_failed"))
            }
        }

        output.parentFile?.mkdirs()
        output.delete()

        val targetW: Int
        val targetH: Int
        if (probe.needsDownscale) {
            val pair = scaledSize(probe)
            targetW = pair.first
            targetH = pair.second
        } else {
            targetW = displayWidth(probe).coerceAtMost(MAX_WIDTH)
            targetH = displayHeight(probe).coerceAtMost(MAX_HEIGHT)
        }

        val bitrate = bitrateFor(targetW, targetH)

        try {
            val mediaItem = MediaItem.fromUri(Uri.fromFile(input))
            val videoEffects = listOf(
                Presentation.createForWidthAndHeight(
                    targetW,
                    targetH,
                    Presentation.LAYOUT_SCALE_TO_FIT,
                ),
            )
            val edited = EditedMediaItem.Builder(mediaItem)
                .setFrameRate(TARGET_FPS)
                .setEffects(Effects(/* audioProcessors= */ emptyList(), videoEffects))
                .build()

            val encoderFactory = DefaultEncoderFactory.Builder(context.applicationContext)
                .setRequestedVideoEncoderSettings(
                    VideoEncoderSettings.Builder()
                        .setBitrate(bitrate)
                        .build(),
                )
                .build()

            val listener = object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    transformer = null
                    progressPct.set(100)
                    onProgress?.invoke(100)
                    val ok = output.exists() && output.length() > 0
                    finish(
                        ExportOutcome(
                            ok = ok,
                            path = if (ok) output.absolutePath else null,
                            passthrough = false,
                            width = targetW,
                            height = targetH,
                            fileBytes = if (ok) output.length() else 0L,
                            error = if (ok) null else "export_empty",
                        ),
                    )
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    Log.e(TAG, "export error", exportException)
                    transformer = null
                    try {
                        output.delete()
                    } catch (_: Exception) {
                    }
                    finish(
                        ExportOutcome(
                            ok = false,
                            error = exportException.message ?: "export_failed",
                        ),
                    )
                }
            }

            val t = Transformer.Builder(context.applicationContext)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoderFactory)
                .addListener(listener)
                .build()
            transformer = t

            // Progress polling (Transformer has getProgress on some versions via ProgressHolder).
            scheduleProgressPoll(t, onProgress)

            t.start(edited, output.absolutePath)
            Log.i(
                TAG,
                "export start ${probe.width}x${probe.height} → ${targetW}x$targetH " +
                    "@${bitrate / 1_000_000}Mbps",
            )
        } catch (t: Throwable) {
            Log.e(TAG, "export start failed", t)
            transformer = null
            finish(ExportOutcome(ok = false, error = t.message ?: "export_start_failed"))
        }
    }

    /**
     * Cancels an in-flight Transformer export and always invokes the pending
     * completion callback so callers waiting on a latch cannot hang.
     */
    fun cancel() {
        try {
            transformer?.cancel()
        } catch (_: Throwable) {
        }
        transformer = null
        progressPct.set(0)
        if (pendingComplete != null) {
            val out = pendingOutput
            try {
                out?.delete()
            } catch (_: Exception) {
            }
            finish(ExportOutcome(ok = false, error = "export_cancelled"))
        } else {
            exporting.set(false)
            pendingOutput = null
        }
    }

    private fun finish(outcome: ExportOutcome) {
        val cb: ((ExportOutcome) -> Unit)?
        synchronized(this) {
            cb = pendingComplete
            pendingComplete = null
            pendingOutput = null
            exporting.set(false)
        }
        if (cb != null) {
            try {
                cb(outcome)
            } catch (t: Throwable) {
                Log.w(TAG, "export complete callback", t)
            }
        }
    }

    private fun scheduleProgressPoll(t: Transformer, onProgress: ((Int) -> Unit)?) {
        val holder = androidx.media3.transformer.ProgressHolder()
        fun tick() {
            if (!exporting.get() || transformer !== t) return
            try {
                val state = t.getProgress(holder)
                if (state == Transformer.PROGRESS_STATE_AVAILABLE) {
                    val pct = holder.progress.coerceIn(0, 100)
                    progressPct.set(pct)
                    onProgress?.invoke(pct)
                }
            } catch (_: Throwable) {
            }
            mainHandler.postDelayed({ tick() }, 250)
        }
        mainHandler.postDelayed({ tick() }, 250)
    }

    private fun displayWidth(p: Probe): Int =
        if (p.rotation % 180 != 0) p.height else p.width

    private fun displayHeight(p: Probe): Int =
        if (p.rotation % 180 != 0) p.width else p.height

    /** Scale so both edges fit within 1080×1920, even dimensions. */
    private fun scaledSize(p: Probe): Pair<Int, Int> {
        val srcW = displayWidth(p).coerceAtLeast(2).toDouble()
        val srcH = displayHeight(p).coerceAtLeast(2).toDouble()
        val scale = min(MAX_WIDTH / srcW, MAX_HEIGHT / srcH).coerceAtMost(1.0)
        var w = (srcW * scale).toInt() and 1.inv()
        var h = (srcH * scale).toInt() and 1.inv()
        w = w.coerceAtLeast(2)
        h = h.coerceAtLeast(2)
        return w to h
    }

    /** 6–10 Mbps band scaled by pixel count vs 1080p. */
    private fun bitrateFor(width: Int, height: Int): Int {
        val pixels = width.toLong() * height.toLong()
        val ref = 1080L * 1920L
        val scaled = (TARGET_BITRATE.toLong() * pixels) / max(1L, ref)
        return scaled.coerceIn(6_000_000L, 10_000_000L).toInt()
    }

    /** Best-effort track duration from extractor (unused probe fallback). */
    @Suppress("unused")
    private fun extractorDurationUs(file: File): Long {
        val ex = MediaExtractor()
        return try {
            ex.setDataSource(file.absolutePath)
            for (i in 0 until ex.trackCount) {
                val f = ex.getTrackFormat(i)
                if (f.containsKey(MediaFormat.KEY_DURATION)) {
                    return f.getLong(MediaFormat.KEY_DURATION)
                }
            }
            0L
        } catch (_: Throwable) {
            0L
        } finally {
            ex.release()
        }
    }
}
