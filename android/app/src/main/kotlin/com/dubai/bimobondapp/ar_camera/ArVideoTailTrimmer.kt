package com.dubai.bimobondapp.ar_camera

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.nio.ByteBuffer

/**
 * Remux helpers for layout video clips.
 *
 * Important: always preserve the container orientation hint. Dropping it makes
 * portrait CameraX clips look like landscape → [SegmentFit.cover] zooms/crops
 * incorrectly and cells look mirrored/warped in the grid.
 */
object ArVideoTailTrimmer {
    private const val TAG = "ArVideoTailTrimmer"

    /** Matches pro_video_editor LayeredCompositionBuilder.FLUSH_TAIL_US. */
    const val DEFAULT_TRIM_US = 120_000L

    /**
     * Keeps the first [maxDurationUs] of [input] (drops the rest).
     * Used to equalize layout cell lengths without pro_video_editor endTime
     * trims (those inject a transparent flush tail → black blink on loop).
     */
    fun trimToDuration(
        input: File,
        maxDurationUs: Long,
        output: File? = null,
    ): File? {
        if (!input.exists() || input.length() <= 0L) return null
        if (maxDurationUs < 300_000L) return input

        val durationUs = probeDurationUs(input) ?: return input
        if (durationUs <= maxDurationUs + 20_000L) {
            // Already short enough — still remux to guarantee orientation hint.
            return remux(
                input = input,
                cutUs = durationUs,
                output = output,
                label = "normalize",
            )
        }
        return remux(
            input = input,
            cutUs = maxDurationUs,
            output = output,
            label = "trimToDuration",
        )
    }

    fun trimEnd(
        input: File,
        trimUs: Long = DEFAULT_TRIM_US,
        output: File? = null,
    ): File? {
        if (!input.exists() || input.length() <= 0L) return null
        if (trimUs <= 0L) return input

        val durationUs = probeDurationUs(input) ?: return input
        val cutUs = durationUs - trimUs
        if (cutUs < 300_000L) {
            Log.w(TAG, "skip trimEnd: duration=${durationUs}us trim=${trimUs}us")
            return input
        }
        return remux(
            input = input,
            cutUs = cutUs,
            output = output,
            label = "trimEnd",
        )
    }

    private fun remux(
        input: File,
        cutUs: Long,
        output: File?,
        label: String,
    ): File? {
        val orientation = probeOrientation(input)
        val out = output ?: File(
            input.parentFile,
            "${label}_${System.currentTimeMillis()}_${input.name}",
        )
        if (out.exists()) out.delete()

        var muxer: MediaMuxer? = null
        var extractor: MediaExtractor? = null
        try {
            extractor = MediaExtractor().also { it.setDataSource(input.absolutePath) }
            muxer = MediaMuxer(out.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            if (orientation != 0) {
                muxer.setOrientationHint(orientation)
            }

            val trackMap = IntArray(extractor.trackCount) { -1 }
            var hasVideo = false
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("video/") && !mime.startsWith("audio/")) continue
                trackMap[i] = muxer.addTrack(format)
                if (mime.startsWith("video/")) hasVideo = true
            }
            if (!hasVideo) {
                Log.e(TAG, "no video track")
                return input
            }

            muxer.start()
            val buffer = ByteBuffer.allocate(1024 * 1024)
            val info = MediaCodec.BufferInfo()

            for (srcTrack in 0 until extractor.trackCount) {
                val dstTrack = trackMap[srcTrack]
                if (dstTrack < 0) continue
                extractor.selectTrack(srcTrack)
                extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                while (true) {
                    val sampleSize = extractor.readSampleData(buffer, 0)
                    if (sampleSize < 0) break
                    val pts = extractor.sampleTime
                    if (pts < 0L) {
                        extractor.advance()
                        continue
                    }
                    if (pts >= cutUs) break
                    info.offset = 0
                    info.size = sampleSize
                    info.presentationTimeUs = pts
                    info.flags = extractor.sampleFlags
                    muxer.writeSampleData(dstTrack, buffer, info)
                    extractor.advance()
                }
                extractor.unselectTrack(srcTrack)
            }

            muxer.stop()
            muxer.release()
            muxer = null
            extractor.release()
            extractor = null

            if (!out.exists() || out.length() <= 0L) {
                Log.e(TAG, "$label produced empty file")
                out.delete()
                return input
            }
            Log.i(
                TAG,
                "$label ok orientation=$orientation cutMs=${cutUs / 1000} -> ${out.name}",
            )
            return out
        } catch (e: Exception) {
            Log.e(TAG, "$label failed", e)
            try {
                out.delete()
            } catch (_: Exception) {
            }
            return input
        } finally {
            try {
                extractor?.release()
            } catch (_: Exception) {
            }
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun probeOrientation(file: File): Int {
        var retriever: MediaMetadataRetriever? = null
        try {
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(file.absolutePath)
            return retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION,
            )?.toIntOrNull()?.let { ((it % 360) + 360) % 360 } ?: 0
        } catch (e: Exception) {
            Log.w(TAG, "orientation probe failed", e)
            return 0
        } finally {
            try {
                retriever?.release()
            } catch (_: Exception) {
            }
        }
    }

    fun probeDurationUs(file: File): Long? {
        var extractor: MediaExtractor? = null
        try {
            extractor = MediaExtractor().also { it.setDataSource(file.absolutePath) }
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("video/")) continue
                if (format.containsKey(MediaFormat.KEY_DURATION)) {
                    val us = format.getLong(MediaFormat.KEY_DURATION)
                    if (us > 0L) return us
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "extractor duration failed", e)
        } finally {
            try {
                extractor?.release()
            } catch (_: Exception) {
            }
        }

        var retriever: MediaMetadataRetriever? = null
        try {
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(file.absolutePath)
            val ms = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION,
            )?.toLongOrNull() ?: return null
            return if (ms > 0L) ms * 1000L else null
        } catch (e: Exception) {
            Log.w(TAG, "retriever duration failed", e)
            return null
        } finally {
            try {
                retriever?.release()
            } catch (_: Exception) {
            }
        }
    }
}
