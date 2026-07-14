package com.dubai.bimobondapp.ar_camera

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.min

/**
 * Encodes filtered ARGB frames into an H.264 MP4.
 * Lazily starts on the first frame so dimensions match the preview aspect (no stretch/pinch).
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
    private var outputFile: File? = null
    private val armed = AtomicBoolean(false)
    private val running = AtomicBoolean(false)
    private var drainThread: HandlerThread? = null
    private var drainHandler: Handler? = null

    fun isRecording(): Boolean = armed.get() || running.get()

    /** Prepare output path; encoder starts on first [offerFrame]. */
    fun arm(output: File) {
        synchronized(lock) {
            abortInternal()
            outputFile = output
            armed.set(true)
            frameIndex = 0
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
        synchronized(lock) {
            armed.set(false)
            if (!running.getAndSet(false)) {
                val empty = outputFile
                outputFile = null
                return empty
            }
            try {
                codec?.signalEndOfInputStream()
            } catch (_: Exception) {
            }
            try {
                Thread.sleep(150)
            } catch (_: InterruptedException) {
            }
            val out = outputFile
            releaseInternal()
            Log.i(TAG, "recording stopped frames=$frameIndex")
            return out
        }
    }

    fun abort() {
        synchronized(lock) {
            armed.set(false)
            if (running.getAndSet(false)) {
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
        trackIndex = -1
        muxerStarted = false

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
        codec = encoder
        muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        val thread = HandlerThread("ar-video-drain").also { it.start() }
        drainThread = thread
        drainHandler = Handler(thread.looper)
        running.set(true)
        armed.set(false)
        drainHandler?.post { drainLoop() }
        Log.i(TAG, "encoder started ${output.name} ${width}x$height (src ${srcW}x$srcH)")
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

    private fun abortInternal() {
        if (running.getAndSet(false)) {
            releaseInternal()
        }
        armed.set(false)
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

    private fun releaseInternal() {
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

    companion object {
        private const val TAG = "ArFilteredVideoRecorder"
        private const val FRAME_RATE = 20
        private const val MAX_EDGE = 720
    }
}
