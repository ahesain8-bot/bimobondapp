package com.dubai.bimobondapp.camera_engine

import android.content.Context
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
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

/**
 * Phase 1 native template export: sequential image holds + video trims →
 * Media3 Transformer (MediaCodec H.264) → optional [AudioMusicMixer] music mux.
 */
@OptIn(UnstableApi::class)
class TemplateCompositionEncoder(private val context: Context) {
    companion object {
        private const val TAG = "TplCompositionEnc"
        private const val EXPORT_TIMEOUT_MIN = 8L
    }

    data class Clip(
        val type: String,
        val path: String,
        val durationMs: Long,
        val trimStartMs: Long? = null,
        val trimEndMs: Long? = null,
        val volume: Float = 1f,
    )

    data class AudioTrack(
        val path: String,
        val startMs: Long = 0L,
        val endMs: Long? = null,
        val volume: Float = 1f,
    )

    data class Request(
        val width: Int,
        val height: Int,
        val fps: Int,
        val bitrate: Int,
        val clips: List<Clip>,
        val audio: AudioTrack? = null,
    )

    data class Outcome(
        val ok: Boolean,
        val path: String? = null,
        val error: String? = null,
    )

    private val mainHandler = Handler(Looper.getMainLooper())

    fun compose(request: Request): Outcome {
        if (request.clips.isEmpty()) {
            return Outcome(ok = false, error = "no_clips")
        }
        val width = even(request.width.coerceIn(2, 1080))
        val height = even(request.height.coerceIn(2, 1920))
        val fps = request.fps.coerceIn(15, 60)
        val bitrate = request.bitrate.coerceIn(1_000_000, 20_000_000)

        val cacheDir = File(context.cacheDir, "template_export").apply { mkdirs() }
        val silentOut = File(
            cacheDir,
            "tpl_native_${System.currentTimeMillis()}.mp4",
        )
        silentOut.delete()

        val removeSourceAudio = request.audio != null
        val editedItems = ArrayList<EditedMediaItem>(request.clips.size)
        for (clip in request.clips) {
            val file = File(clip.path)
            if (!file.exists() || file.length() <= 0L) {
                return Outcome(ok = false, error = "missing_clip:${clip.path}")
            }
            val item = buildEditedItem(
                clip = clip,
                width = width,
                height = height,
                fps = fps,
                removeAudio = removeSourceAudio,
            ) ?: return Outcome(ok = false, error = "bad_clip:${clip.path}")
            editedItems.add(item)
        }

        val estimatedMs = request.clips.sumOf { it.durationMs.coerceAtLeast(200L) }
        val silentResult = runTransformer(
            editedItems = editedItems,
            output = silentOut,
            bitrate = bitrate,
            estimatedDurationMs = estimatedMs,
        )
        if (!silentResult.ok || silentResult.path == null) {
            silentOut.delete()
            return silentResult
        }

        val audio = request.audio
        if (audio == null || audio.path.isBlank()) {
            return Outcome(ok = true, path = silentOut.absolutePath)
        }
        val musicFile = File(audio.path)
        if (!musicFile.exists() || musicFile.length() <= 0L) {
            Log.w(TAG, "audio missing — returning silent compose")
            return Outcome(ok = true, path = silentOut.absolutePath)
        }

        val mixedOut = File(
            cacheDir,
            "tpl_native_audio_${System.currentTimeMillis()}.mp4",
        )
        mixedOut.delete()
        val mixed = AudioMusicMixer.mixToMp4(
            videoFile = silentOut,
            micFile = null,
            config = AudioMusicMixer.Config(
                musicPath = musicFile.absolutePath,
                musicOffsetMs = audio.startMs.coerceAtLeast(0L),
                musicVolume = audio.volume.coerceIn(0f, 1f),
                originalVolume = 0f,
            ),
            outFile = mixedOut,
        )
        return if (mixed && mixedOut.exists() && mixedOut.length() > 0L) {
            silentOut.delete()
            Outcome(ok = true, path = mixedOut.absolutePath)
        } else {
            Log.w(TAG, "audio mux failed — returning silent compose")
            mixedOut.delete()
            Outcome(ok = true, path = silentOut.absolutePath)
        }
    }

    private fun buildEditedItem(
        clip: Clip,
        width: Int,
        height: Int,
        fps: Int,
        removeAudio: Boolean,
    ): EditedMediaItem? {
        val uri = Uri.fromFile(File(clip.path))
        val type = clip.type.trim().lowercase()
        val builder = MediaItem.Builder().setUri(uri)

        if (type == "image") {
            val holdMs = clip.durationMs.coerceIn(200L, 60_000L)
            builder.setImageDurationMs(holdMs)
        } else {
            val start = (clip.trimStartMs ?: 0L).coerceAtLeast(0L)
            val end = clip.trimEndMs
            val clipping = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(start)
            if (end != null && end > start) {
                clipping.setEndPositionMs(end)
            } else if (clip.durationMs > 0L) {
                clipping.setEndPositionMs(start + clip.durationMs)
            }
            builder.setClippingConfiguration(clipping.build())
        }

        val videoEffects = listOf(
            Presentation.createForWidthAndHeight(
                width,
                height,
                Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP,
            ),
        )

        return EditedMediaItem.Builder(builder.build())
            .setFrameRate(fps)
            .setRemoveAudio(removeAudio || type == "image")
            .setEffects(Effects(/* audioProcessors= */ emptyList(), videoEffects))
            .build()
    }

    private fun runTransformer(
        editedItems: List<EditedMediaItem>,
        output: File,
        bitrate: Int,
        estimatedDurationMs: Long,
    ): Outcome {
        val done = CountDownLatch(1)
        val finished = AtomicBoolean(false)
        var outcome = Outcome(ok = false, error = "export_timeout")

        fun complete(result: Outcome) {
            if (!finished.compareAndSet(false, true)) return
            outcome = result
            done.countDown()
        }

        val encoderFactory = DefaultEncoderFactory.Builder(context.applicationContext)
            .setRequestedVideoEncoderSettings(
                VideoEncoderSettings.Builder()
                    .setBitrate(bitrate)
                    .build(),
            )
            .build()

        val listener = object : Transformer.Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                val ok = output.exists() && output.length() > 0L
                complete(
                    Outcome(
                        ok = ok,
                        path = if (ok) output.absolutePath else null,
                        error = if (ok) null else "export_empty",
                    ),
                )
            }

            override fun onError(
                composition: Composition,
                exportResult: ExportResult,
                exportException: ExportException,
            ) {
                Log.e(TAG, "transformer error", exportException)
                try {
                    output.delete()
                } catch (_: Exception) {
                }
                complete(
                    Outcome(
                        ok = false,
                        error = exportException.message ?: "export_failed",
                    ),
                )
            }
        }

        try {
            @Suppress("DEPRECATION")
            val sequence = EditedMediaItemSequence.Builder(editedItems).build()
            val composition = Composition.Builder(sequence).build()
            val transformer = Transformer.Builder(context.applicationContext)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoderFactory)
                .addListener(listener)
                .build()

            // Transformer must start on a looper thread; use main.
            val startLatch = CountDownLatch(1)
            var startError: String? = null
            mainHandler.post {
                try {
                    transformer.start(composition, output.absolutePath)
                } catch (t: Throwable) {
                    Log.e(TAG, "transformer start", t)
                    startError = t.message ?: "export_start_failed"
                } finally {
                    startLatch.countDown()
                }
            }
            startLatch.await(15, TimeUnit.SECONDS)
            if (startError != null) {
                return Outcome(ok = false, error = startError)
            }

            val timeoutMin = max(
                EXPORT_TIMEOUT_MIN,
                (estimatedDurationMs.coerceAtLeast(1_000L) / 60_000L) + 2L,
            )
            if (!done.await(timeoutMin, TimeUnit.MINUTES)) {
                try {
                    transformer.cancel()
                } catch (_: Throwable) {
                }
                complete(Outcome(ok = false, error = "export_timeout"))
            }
        } catch (t: Throwable) {
            Log.e(TAG, "compose failed", t)
            return Outcome(ok = false, error = t.message ?: "compose_failed")
        }

        return outcome
    }

    private fun even(v: Int): Int = if (v % 2 == 0) v else v + 1
}
