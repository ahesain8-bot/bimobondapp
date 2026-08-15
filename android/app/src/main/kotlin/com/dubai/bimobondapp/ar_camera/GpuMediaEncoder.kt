package com.dubai.bimobondapp.ar_camera

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.view.Surface
import java.io.File

/**
 * Hardware H.264 MediaCodec + MediaMuxer encoder for recording GPU-composited video.
 * Connects directly to an EGL input surface to encode 1080p/720p 30 FPS MP4 files
 * without CPU memory copies.
 */
class GpuMediaEncoder {

    private var mediaCodec: MediaCodec? = null
    private var mediaMuxer: MediaMuxer? = null
    private var inputSurface: Surface? = null

    private var videoTrackIndex = -1
    private var isMuxerStarted = false

    @Volatile
    var isRecording = false
        private set

    fun prepare(
        outputFile: File,
        width: Int = 720,
        height: Int = 1280,
        bitRate: Int = 6_000_000,
        frameRate: Int = 30,
    ): Surface {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val surface = codec.createInputSurface()
        inputSurface = surface
        codec.start()
        mediaCodec = codec

        mediaMuxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        isRecording = true
        return surface
    }

    fun drainEncoder(endOfStream: Boolean) {
        val codec = mediaCodec ?: return
        val muxer = mediaMuxer ?: return

        if (endOfStream) {
            try {
                codec.signalEndOfInputStream()
            } catch (_: Exception) {
            }
        }

        val bufferInfo = MediaCodec.BufferInfo()
        while (true) {
            val status = codec.dequeueOutputBuffer(bufferInfo, 10_000L)
            if (status == MediaCodec.INFO_TRY_AGAIN_LATER) {
                if (!endOfStream) break
            } else if (status == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                if (isMuxerStarted) {
                    throw RuntimeException("Format changed twice")
                }
                val newFormat = codec.outputFormat
                videoTrackIndex = muxer.addTrack(newFormat)
                muxer.start()
                isMuxerStarted = true
            } else if (status >= 0) {
                val encodedData = codec.getOutputBuffer(status) ?: continue
                if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                    bufferInfo.size = 0
                }
                if (bufferInfo.size != 0) {
                    if (!isMuxerStarted) {
                        throw RuntimeException("Muxer not started")
                    }
                    encodedData.position(bufferInfo.offset)
                    encodedData.limit(bufferInfo.offset + bufferInfo.size)
                    muxer.writeSampleData(videoTrackIndex, encodedData, bufferInfo)
                }
                codec.releaseOutputBuffer(status, false)
                if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                    break
                }
            }
        }
    }

    fun stop() {
        if (!isRecording) return
        isRecording = false
        try {
            drainEncoder(true)
        } catch (_: Exception) {
        }
        try {
            mediaCodec?.stop()
            mediaCodec?.release()
        } catch (_: Exception) {
        }
        mediaCodec = null

        try {
            if (isMuxerStarted) {
                mediaMuxer?.stop()
            }
            mediaMuxer?.release()
        } catch (_: Exception) {
        }
        mediaMuxer = null
        isMuxerStarted = false
        videoTrackIndex = -1

        try {
            inputSurface?.release()
        } catch (_: Exception) {
        }
        inputSurface = null
    }
}
