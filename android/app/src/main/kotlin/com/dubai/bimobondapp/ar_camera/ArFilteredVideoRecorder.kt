package com.dubai.bimobondapp.ar_camera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import androidx.core.content.ContextCompat
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.min

/**
 * Encodes filtered ARGB frames + microphone audio into an H.264/AAC MP4.
 * Lazily starts on the first frame so dimensions match the preview aspect.
 */
class ArFilteredVideoRecorder {

    private val lock = Any()
    private var videoCodec: MediaCodec? = null
    private var audioCodec: MediaCodec? = null
    private var audioRecord: AudioRecord? = null
    private var muxer: MediaMuxer? = null
    private var inputSurface: Surface? = null
    private var videoTrackIndex = -1
    private var audioTrackIndex = -1
    private var pendingVideoFormat: MediaFormat? = null
    private var pendingAudioFormat: MediaFormat? = null
    private var muxerStarted = false
    private var expectAudio = false
    private var frameIndex = 0L
    private var width = 0
    private var height = 0
    private var outputFile: File? = null
    private var appContext: Context? = null
    private val armed = AtomicBoolean(false)
    private val running = AtomicBoolean(false)
    private var drainThread: HandlerThread? = null
    private var drainHandler: Handler? = null
    private var audioThread: Thread? = null
    private var totalAudioSamples = 0L

    fun isRecording(): Boolean = armed.get() || running.get()

    /** Prepare output path; encoder starts on first [offerFrame]. */
    fun arm(output: File, context: Context? = null) {
        synchronized(lock) {
            abortInternal()
            outputFile = output
            appContext = context?.applicationContext
            armed.set(true)
            frameIndex = 0
            totalAudioSamples = 0L
        }
    }

    fun offerFrame(bitmap: Bitmap) {
        if (!armed.get() && !running.get()) return
        synchronized(lock) {
            if (!running.get()) {
                if (!armed.get()) return
                val out = outputFile ?: return
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
        armed.set(false)
        if (!running.getAndSet(false)) {
            synchronized(lock) {
                val empty = outputFile
                outputFile = null
                return empty
            }
        }
        try {
            videoCodec?.signalEndOfInputStream()
        } catch (_: Exception) {
        }
        // Join audio outside the lock — audio drain also takes [lock].
        stopAudioCapture()
        try {
            Thread.sleep(250)
        } catch (_: InterruptedException) {
        }
        synchronized(lock) {
            val out = outputFile
            releaseInternal()
            Log.i(TAG, "recording stopped frames=$frameIndex")
            return out
        }
    }

    fun abort() {
        armed.set(false)
        val wasRunning = running.getAndSet(false)
        if (wasRunning) {
            stopAudioCapture()
        }
        synchronized(lock) {
            if (wasRunning) {
                releaseInternal()
            }
            outputFile = null
        }
    }

    private fun startEncoder(output: File, srcW: Int, srcH: Int) {
        val maxEdge = MAX_EDGE
        val scale = min(1f, maxEdge.toFloat() / max(srcW, srcH))
        width = ((srcW * scale).toInt() and 1.inv()).coerceAtLeast(2)
        height = ((srcH * scale).toInt() and 1.inv()).coerceAtLeast(2)
        videoTrackIndex = -1
        audioTrackIndex = -1
        pendingVideoFormat = null
        pendingAudioFormat = null
        muxerStarted = false
        totalAudioSamples = 0L

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(
                MediaFormat.KEY_BIT_RATE,
                (width * height * 3).coerceIn(1_500_000, 6_000_000),
            )
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        inputSurface = encoder.createInputSurface()
        encoder.start()
        videoCodec = encoder
        muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        expectAudio = startAudioEncoder()
        if (!expectAudio) {
            Log.w(TAG, "recording without audio (mic unavailable)")
        }

        val thread = HandlerThread("ar-video-drain").also { it.start() }
        drainThread = thread
        drainHandler = Handler(thread.looper)
        running.set(true)
        armed.set(false)
        drainHandler?.post { drainVideoLoop() }
        // Don't stall forever if AAC format never arrives.
        if (expectAudio) {
            drainHandler?.postDelayed({
                synchronized(lock) {
                    if (!muxerStarted && pendingVideoFormat != null && pendingAudioFormat == null) {
                        Log.w(TAG, "audio track timeout — muxing video only")
                        expectAudio = false
                        maybeStartMuxerLocked()
                    }
                }
            }, 800)
        }
        Log.i(
            TAG,
            "encoder started ${output.name} ${width}x$height audio=$expectAudio (src ${srcW}x$srcH)",
        )
    }

    private fun hasMicPermission(): Boolean {
        val ctx = appContext ?: return false
        return ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun startAudioEncoder(): Boolean {
        if (!hasMicPermission()) return false

        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            CHANNEL_CONFIG,
            AUDIO_ENCODING,
        )
        if (minBuf <= 0) return false
        val bufferSize = max(minBuf, SAMPLE_RATE)

        val recorder = try {
            AudioRecord(
                MediaRecorder.AudioSource.CAMCORDER,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_ENCODING,
                bufferSize,
            )
        } catch (e: Exception) {
            Log.w(TAG, "AudioRecord create failed", e)
            return false
        }
        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            try {
                recorder.release()
            } catch (_: Exception) {
            }
            return false
        }

        val aacFormat = MediaFormat.createAudioFormat(
            MediaFormat.MIMETYPE_AUDIO_AAC,
            SAMPLE_RATE,
            CHANNEL_COUNT,
        ).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BIT_RATE)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, bufferSize)
        }

        val encoder = try {
            MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).also {
                it.configure(aacFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                it.start()
            }
        } catch (e: Exception) {
            Log.w(TAG, "AAC encoder failed", e)
            try {
                recorder.release()
            } catch (_: Exception) {
            }
            return false
        }

        audioRecord = recorder
        audioCodec = encoder
        try {
            recorder.startRecording()
        } catch (e: Exception) {
            Log.w(TAG, "AudioRecord start failed", e)
            try {
                encoder.stop()
                encoder.release()
            } catch (_: Exception) {
            }
            audioCodec = null
            try {
                recorder.release()
            } catch (_: Exception) {
            }
            audioRecord = null
            return false
        }

        audioThread = Thread({ audioCaptureLoop(bufferSize) }, "ar-audio-capture").also {
            it.isDaemon = true
            it.start()
        }
        return true
    }

    private fun audioCaptureLoop(bufferSize: Int) {
        val pcm = ByteArray(bufferSize)
        val bufferInfo = MediaCodec.BufferInfo()
        while (running.get()) {
            val recorder = audioRecord ?: break
            val encoder = audioCodec ?: break
            val read = try {
                recorder.read(pcm, 0, pcm.size)
            } catch (_: Exception) {
                break
            }
            if (read <= 0) continue

            val ptsUs = totalAudioSamples * 1_000_000L / SAMPLE_RATE
            totalAudioSamples += read / BYTES_PER_SAMPLE

            var remaining = read
            var offset = 0
            while (remaining > 0 && running.get()) {
                val inIndex = try {
                    encoder.dequeueInputBuffer(10_000)
                } catch (_: Exception) {
                    -1
                }
                if (inIndex < 0) break
                val inBuf = encoder.getInputBuffer(inIndex) ?: break
                inBuf.clear()
                val chunk = min(remaining, inBuf.capacity())
                inBuf.put(pcm, offset, chunk)
                encoder.queueInputBuffer(inIndex, 0, chunk, ptsUs, 0)
                offset += chunk
                remaining -= chunk
            }

            drainAudioEncoder(encoder, bufferInfo, endOfStream = false)
        }

        // Flush encoder
        val encoder = audioCodec
        if (encoder != null) {
            try {
                val inIndex = encoder.dequeueInputBuffer(50_000)
                if (inIndex >= 0) {
                    val ptsUs = totalAudioSamples * 1_000_000L / SAMPLE_RATE
                    encoder.queueInputBuffer(
                        inIndex,
                        0,
                        0,
                        ptsUs,
                        MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                    )
                }
            } catch (_: Exception) {
            }
            drainAudioEncoder(encoder, bufferInfo, endOfStream = true)
        }
    }

    private fun drainAudioEncoder(
        encoder: MediaCodec,
        bufferInfo: MediaCodec.BufferInfo,
        endOfStream: Boolean,
    ) {
        while (true) {
            val outIndex = try {
                encoder.dequeueOutputBuffer(bufferInfo, if (endOfStream) 20_000 else 0)
            } catch (_: Exception) {
                break
            }
            when {
                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return
                    if (!running.get()) return
                }
                outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    synchronized(lock) {
                        pendingAudioFormat = encoder.outputFormat
                        maybeStartMuxerLocked()
                    }
                }
                outIndex >= 0 -> {
                    val encoded = encoder.getOutputBuffer(outIndex)
                    if (encoded != null &&
                        bufferInfo.size > 0 &&
                        bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0
                    ) {
                        writeSample(audioTrackIndex, encoded, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outIndex, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        return
                    }
                }
                else -> return
            }
        }
    }

    private fun drainVideoLoop() {
        val bufferInfo = MediaCodec.BufferInfo()
        while (running.get() || muxerStarted) {
            val encoder = videoCodec ?: break
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
                    synchronized(lock) {
                        pendingVideoFormat = encoder.outputFormat
                        maybeStartMuxerLocked()
                    }
                }
                outIndex >= 0 -> {
                    val encoded = encoder.getOutputBuffer(outIndex)
                    if (encoded != null &&
                        bufferInfo.size > 0 &&
                        bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0
                    ) {
                        writeSample(videoTrackIndex, encoded, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outIndex, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        break
                    }
                }
            }
        }
    }

    private fun maybeStartMuxerLocked() {
        if (muxerStarted) return
        val mux = muxer ?: return
        val videoFormat = pendingVideoFormat ?: return
        if (expectAudio && pendingAudioFormat == null) return

        videoTrackIndex = mux.addTrack(videoFormat)
        val audioFormat = pendingAudioFormat
        audioTrackIndex = if (audioFormat != null) mux.addTrack(audioFormat) else -1
        mux.start()
        muxerStarted = true
        Log.i(TAG, "muxer started video=$videoTrackIndex audio=$audioTrackIndex")
    }

    private fun writeSample(track: Int, buffer: ByteBuffer, info: MediaCodec.BufferInfo) {
        if (track < 0) return
        synchronized(lock) {
            if (!muxerStarted) return
            try {
                buffer.position(info.offset)
                buffer.limit(info.offset + info.size)
                muxer?.writeSampleData(track, buffer, info)
            } catch (e: Exception) {
                Log.w(TAG, "writeSample failed track=$track", e)
            }
        }
    }

    /** FILL_CENTER style draw — never stretches the face. */
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
        canvas.drawBitmap(bitmap, srcRect, Rect(0, 0, dstW, dstH), null)
    }

    private fun stopAudioCapture() {
        try {
            audioRecord?.stop()
        } catch (_: Exception) {
        }
        try {
            audioThread?.join(500)
        } catch (_: Exception) {
        }
        audioThread = null
    }

    private fun abortInternal() {
        val wasRunning = running.getAndSet(false)
        if (wasRunning) {
            // Caller may already hold [lock]; stop mic without joining here.
            try {
                audioRecord?.stop()
            } catch (_: Exception) {
            }
            releaseInternal()
        }
        armed.set(false)
    }

    private fun releaseInternal() {
        try {
            inputSurface?.release()
        } catch (_: Exception) {
        }
        inputSurface = null
        try {
            videoCodec?.stop()
            videoCodec?.release()
        } catch (_: Exception) {
        }
        videoCodec = null
        try {
            audioCodec?.stop()
            audioCodec?.release()
        } catch (_: Exception) {
        }
        audioCodec = null
        try {
            audioRecord?.release()
        } catch (_: Exception) {
        }
        audioRecord = null
        try {
            if (muxerStarted) muxer?.stop()
            muxer?.release()
        } catch (_: Exception) {
        }
        muxer = null
        muxerStarted = false
        expectAudio = false
        pendingVideoFormat = null
        pendingAudioFormat = null
        videoTrackIndex = -1
        audioTrackIndex = -1
        drainThread?.quitSafely()
        drainThread = null
        drainHandler = null
        width = 0
        height = 0
        appContext = null
    }

    companion object {
        private const val TAG = "ArFilteredVideoRecorder"
        private const val FRAME_RATE = 20
        private const val MAX_EDGE = 720
        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_COUNT = 1
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_ENCODING = AudioFormat.ENCODING_PCM_16BIT
        private const val BYTES_PER_SAMPLE = 2 // mono PCM16
        private const val AUDIO_BIT_RATE = 128_000
    }
}
