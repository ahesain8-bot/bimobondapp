package com.dubai.bimobondapp.ar_camera

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.min

/**
 * Encodes filtered ARGB frames into an H.264 MP4 with parallel mic audio.
 * Video starts on the first [offerFrame]; audio is remuxed with video on [stop].
 */
class ArFilteredVideoRecorder {

    private val lock = Any()
    private var codec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var inputSurface: Surface? = null
    private var trackIndex = -1
    private var muxerStarted = false
    private var frameIndex = 0L
    private var width = 0
    private var height = 0

    private var finalOutputFile: File? = null
    private var videoTempFile: File? = null
    private var audioTempFile: File? = null
    private var mediaRecorder: MediaRecorder? = null
    private var audioRecording = false

    private val armed = AtomicBoolean(false)
    private val running = AtomicBoolean(false)
    private var drainThread: HandlerThread? = null
    private var drainHandler: Handler? = null

    fun isRecording(): Boolean = armed.get() || running.get()

    fun arm(output: File) {
        synchronized(lock) {
            abortInternal()
            finalOutputFile = output
            val parent = output.parentFile ?: output.absoluteFile.parentFile
            val base = output.nameWithoutExtension
            videoTempFile = File(parent, "${base}_v.mp4")
            audioTempFile = File(parent, "${base}_a.m4a")
            videoTempFile?.delete()
            audioTempFile?.delete()
            armed.set(true)
            frameIndex = 0
           
        }
    }

    fun offerFrame(bitmap: Bitmap) {
        if (!armed.get() && !running.get()) return
        synchronized(lock) {
            if (!running.get()) {
                if (!armed.get()) return
                val out = videoTempFile ?: return
                startEncoder(out, bitmap.width, bitmap.height)
            }
        }
        if (!running.get()) return
        val surface = inputSurface ?: return
        try {
            val canvas = surface.lockHardwareCanvas()
            try {
                canvas.drawColor(Color.BLACK)
                drawCenterCrop(canvas, bitmap, width, height)
            } finally {
                surface.unlockCanvasAndPost(canvas)
            }
            frameIndex++
        } catch (e: Exception) {
            Log.w(TAG, "offerFrame failed", e)
        }
    }

    fun stop(): File? {
        synchronized(lock) {
            armed.set(false)
            val hadVideo = running.getAndSet(false)
            if (hadVideo) {
                try {
                    codec?.signalEndOfInputStream()
                } catch (_: Exception) {
                }
                try {
                    Thread.sleep(150)
                } catch (_: InterruptedException) {
                }
            }
            releaseVideoEncoder()
            stopMicRecorder()

            val video = videoTempFile
            val audio = audioTempFile
            val finalOut = finalOutputFile
            Log.i(
                TAG,
                "recording stopped frames=$frameIndex " +
                    "videoBytes=${video?.length() ?: 0} audioBytes=${audio?.length() ?: 0}",
            )

            val result = when {
                finalOut == null -> null
                video != null && video.exists() && video.length() > 0L -> {
                    muxAv(video, audio, finalOut)
                }
                else -> null
            }

            cleanupTemps()
            finalOutputFile = null
            return result
        }
    }

    fun abort() {
        synchronized(lock) {
            armed.set(false)
            running.set(false)
            releaseVideoEncoder()
            stopMicRecorder()
            cleanupTemps()
            finalOutputFile = null
        }
    }

    private fun startMicRecorder() {
        val audioFile = audioTempFile ?: return
        try {
            @Suppress("DEPRECATION")
            val recorder = MediaRecorder()
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioSamplingRate(44_100)
            recorder.setAudioEncodingBitRate(128_000)
            recorder.setAudioChannels(1)
            recorder.setOutputFile(audioFile.absolutePath)
            recorder.prepare()
            recorder.start()
            mediaRecorder = recorder
            audioRecording = true
            Log.i(TAG, "mic recorder started ${audioFile.name}")
        } catch (e: SecurityException) {
            Log.e(TAG, "mic permission missing — video will be silent", e)
            releaseMicOnly()
        } catch (e: Exception) {
            Log.e(TAG, "mic recorder failed — video will be silent", e)
            releaseMicOnly()
        }
    }

    private fun stopMicRecorder() {
        val recorder = mediaRecorder ?: return
        try {
            if (audioRecording) {
                recorder.stop()
            }
        } catch (e: Exception) {
            Log.w(TAG, "mic stop failed", e)
        }
        audioRecording = false
        try {
            recorder.release()
        } catch (_: Exception) {
        }
        mediaRecorder = null
    }

    private fun releaseMicOnly() {
        audioRecording = false
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {
        }
        mediaRecorder = null
    }

    private fun startEncoder(output: File, srcW: Int, srcH: Int) {
        val maxEdge = MAX_EDGE
        val scale = min(1f, maxEdge.toFloat() / max(srcW, srcH))
        width = ((srcW * scale).toInt() and 1.inv()).coerceAtLeast(2)
        height = ((srcH * scale).toInt() and 1.inv()).coerceAtLeast(2)
        trackIndex = -1
        muxerStarted = false

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(
                MediaFormat.KEY_BIT_RATE,
                (width * height * 4).coerceIn(4_000_000, 12_000_000),
            )
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        inputSurface = encoder.createInputSurface()
        encoder.start()
        codec = encoder
        muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        val thread = HandlerThread("ar-video-drain").also { it.start() }
        drainThread = thread
        drainHandler = Handler(thread.looper)
        running.set(true)
        armed.set(false)
        startMicRecorder()   
        drainHandler?.post { drainLoop() }
        Log.i(TAG, "encoder started ${output.name} ${width}x$height (src ${srcW}x$srcH)")
    }

    private fun drawCenterCrop(canvas: Canvas, bitmap: Bitmap, dstW: Int, dstH: Int) {
        val srcW = bitmap.width.toFloat()
        val srcH = bitmap.height.toFloat()
        if (srcW <= 0f || srcH <= 0f) return

        val srcAspect = srcW / srcH
        val dstAspect = dstW.toFloat() / dstH.toFloat()
        val srcRect: Rect
        if (srcAspect > dstAspect) {
            val newW = srcH * dstAspect
            val left = (srcW - newW) * 0.5f
            srcRect = Rect(left.toInt(), 0, (left + newW).toInt(), srcH.toInt())
        } else {
            val newH = srcW / dstAspect
            val top = (srcH - newH) * 0.5f
            srcRect = Rect(0, top.toInt(), srcW.toInt(), (top + newH).toInt())
        }
        val paint = android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG)
        canvas.drawBitmap(bitmap, srcRect, Rect(0, 0, dstW, dstH), paint)
    }

    private fun abortInternal() {
        running.set(false)
        armed.set(false)
        releaseVideoEncoder()
        stopMicRecorder()
        cleanupTemps()
        finalOutputFile = null
    }

    private fun drainLoop() {
        val bufferInfo = MediaCodec.BufferInfo()
        while (running.get() || muxerStarted) {
            val encoder = codec ?: break
            val outIndex = try {
                encoder.dequeueOutputBuffer(bufferInfo, 10_000)
            } catch (_: Exception) {
                break
            }
            when {
                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!running.get()) break
                }
                outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    val mux = muxer ?: break
                    if (muxerStarted) continue
                    trackIndex = mux.addTrack(encoder.outputFormat)
                    mux.start()
                    muxerStarted = true
                }
                outIndex >= 0 -> {
                    val encoded = encoder.getOutputBuffer(outIndex)
                    if (encoded != null && bufferInfo.size > 0 && muxerStarted) {
                        encoded.position(bufferInfo.offset)
                        encoded.limit(bufferInfo.offset + bufferInfo.size)
                        muxer?.writeSampleData(trackIndex, encoded, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outIndex, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        break
                    }
                }
            }
        }
    }

    private fun releaseVideoEncoder() {
        try {
            inputSurface?.release()
        } catch (_: Exception) {
        }
        inputSurface = null
        try {
            codec?.stop()
            codec?.release()
        } catch (_: Exception) {
        }
        codec = null
        try {
            if (muxerStarted) muxer?.stop()
            muxer?.release()
        } catch (_: Exception) {
        }
        muxer = null
        muxerStarted = false
        drainThread?.quitSafely()
        drainThread = null
        drainHandler = null
        width = 0
        height = 0
    }

    private fun cleanupTemps() {
        try {
            videoTempFile?.delete()
        } catch (_: Exception) {
        }
        try {
            audioTempFile?.delete()
        } catch (_: Exception) {
        }
        videoTempFile = null
        audioTempFile = null
    }

    /**
     * Copies H.264 from [videoFile] and AAC from [audioFile] into [outFile].
     * Falls back to video-only if audio is missing.
     */
    private fun muxAv(videoFile: File, audioFile: File?, outFile: File): File {
        outFile.delete()
        val hasAudio = audioFile != null && audioFile.exists() && audioFile.length() > 512L
        if (!hasAudio) {
            Log.w(TAG, "mux: no usable audio, copying video only")
            videoFile.copyTo(outFile, overwrite = true)
            return outFile
        }

        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            videoExtractor.setDataSource(videoFile.absolutePath)
            audioExtractor.setDataSource(audioFile!!.absolutePath)

            val videoTrack = findTrack(videoExtractor, "video/")
            val audioTrack = findTrack(audioExtractor, "audio/")
            if (videoTrack < 0) {
                Log.e(TAG, "mux: video track missing")
                videoFile.copyTo(outFile, overwrite = true)
                return outFile
            }

            muxer = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            videoExtractor.selectTrack(videoTrack)
            val outVideo = muxer.addTrack(videoExtractor.getTrackFormat(videoTrack))
            var outAudio = -1
            if (audioTrack >= 0) {
                audioExtractor.selectTrack(audioTrack)
                outAudio = muxer.addTrack(audioExtractor.getTrackFormat(audioTrack))
            }
            muxer.start()

            copySamples(videoExtractor, muxer, outVideo)
            if (outAudio >= 0) {
                copySamples(audioExtractor, muxer, outAudio)
            }

            Log.i(
                TAG,
                "mux ok out=${outFile.length()}b videoIn=${videoFile.length()}b audioIn=${audioFile.length()}b",
            )
            return outFile
        } catch (e: Exception) {
            Log.e(TAG, "mux failed — returning video only", e)
            try {
                outFile.delete()
            } catch (_: Exception) {
            }
            videoFile.copyTo(outFile, overwrite = true)
            return outFile
        } finally {
            try {
                videoExtractor.release()
            } catch (_: Exception) {
            }
            try {
                audioExtractor.release()
            } catch (_: Exception) {
            }
            try {
                muxer?.stop()
            } catch (_: Exception) {
            }
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun findTrack(extractor: MediaExtractor, mimePrefix: String): Int {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith(mimePrefix)) return i
        }
        return -1
    }

    private fun copySamples(extractor: MediaExtractor, muxer: MediaMuxer, trackIndex: Int) {
        val buffer = ByteBuffer.allocate(1024 * 1024)
        val info = MediaCodec.BufferInfo()
        extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break
            info.offset = 0
            info.size = sampleSize
            info.presentationTimeUs = extractor.sampleTime.coerceAtLeast(0L)
            info.flags = extractor.sampleFlags
            muxer.writeSampleData(trackIndex, buffer, info)
            if (!extractor.advance()) break
        }
    }

    companion object {
        private const val TAG = "ArFilteredVideoRecorder"
        const val MAX_EDGE = 1280
        const val FRAME_RATE = 30
    }
}
