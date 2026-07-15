package com.dubai.bimobondapp.ar_camera

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.nio.ByteBuffer

/** Concatenates same-codec H.264 segment MP4s into one file (TikTok multi-clip). */
object ArVideoSegmentMerger {
    private const val TAG = "ArVideoSegmentMerger"

    fun merge(inputs: List<File>, output: File): File? {
        if (inputs.isEmpty()) return null
        if (inputs.size == 1) {
            val only = inputs.first()
            return if (only.exists() && only.length() > 0L) only else null
        }

        var muxer: MediaMuxer? = null
        val extractors = ArrayList<MediaExtractor>()
        try {
            if (output.exists()) output.delete()
            muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            var videoTrack = -1
            var audioTrack = -1
            var started = false
            var videoPtsOffset = 0L
            var audioPtsOffset = 0L

            for (input in inputs) {
                if (!input.exists() || input.length() <= 0L) continue
                val extractor = MediaExtractor()
                extractor.setDataSource(input.absolutePath)
                extractors.add(extractor)

                var localVideo = -1
                var localAudio = -1
                for (i in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(i)
                    val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                    when {
                        mime.startsWith("video/") && localVideo < 0 -> localVideo = i
                        mime.startsWith("audio/") && localAudio < 0 -> localAudio = i
                    }
                }

                if (!started) {
                    if (localVideo >= 0) {
                        videoTrack = muxer.addTrack(extractor.getTrackFormat(localVideo))
                    }
                    if (localAudio >= 0) {
                        audioTrack = muxer.addTrack(extractor.getTrackFormat(localAudio))
                    }
                    if (videoTrack < 0 && audioTrack < 0) continue
                    muxer.start()
                    started = true
                }

                var maxVideoPts = 0L
                var maxAudioPts = 0L

                if (localVideo >= 0 && videoTrack >= 0) {
                    maxVideoPts = copyTrack(
                        extractor,
                        localVideo,
                        muxer,
                        videoTrack,
                        videoPtsOffset,
                    )
                }
                if (localAudio >= 0 && audioTrack >= 0) {
                    maxAudioPts = copyTrack(
                        extractor,
                        localAudio,
                        muxer,
                        audioTrack,
                        audioPtsOffset,
                    )
                }

                videoPtsOffset += maxVideoPts + 10_000L
                audioPtsOffset += maxAudioPts + 10_000L
                extractor.release()
                extractors.remove(extractor)
            }

            if (!started) return null
            muxer.stop()
            muxer.release()
            muxer = null
            return if (output.exists() && output.length() > 0L) output else null
        } catch (e: Exception) {
            Log.e(TAG, "merge failed", e)
            return null
        } finally {
            extractors.forEach {
                try {
                    it.release()
                } catch (_: Exception) {
                }
            }
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun copyTrack(
        extractor: MediaExtractor,
        trackIndex: Int,
        muxer: MediaMuxer,
        outTrack: Int,
        ptsOffset: Long,
    ): Long {
        extractor.selectTrack(trackIndex)
        val buffer = ByteBuffer.allocate(1024 * 1024)
        val info = MediaCodec.BufferInfo()
        var maxPts = 0L
        while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break
            info.offset = 0
            info.size = sampleSize
            info.presentationTimeUs = extractor.sampleTime + ptsOffset
            info.flags = extractor.sampleFlags
            maxPts = maxOf(maxPts, info.presentationTimeUs - ptsOffset)
            muxer.writeSampleData(outTrack, buffer, info)
            extractor.advance()
        }
        extractor.unselectTrack(trackIndex)
        return maxPts
    }
}
