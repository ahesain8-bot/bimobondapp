package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import org.webrtc.CapturerObserver
import org.webrtc.JavaI420Buffer
import org.webrtc.SurfaceTextureHelper
import org.webrtc.VideoCapturer
import org.webrtc.VideoFrame
import org.webrtc.YuvHelper
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * WebRTC [VideoCapturer] that does **not** open Camera2.
 *
 * Pulls beautified frames from FaceWarp via bitmap readback and pushes
 * [VideoFrame]s into LiveKit on the [SurfaceTextureHelper] thread.
 *
 * Always publishes a fixed portrait size. Publishing a temporary landscape
 * buffer after a front→back flip (while the track is still 720x1280) produces
 * the horizontal-static corruption viewers see.
 */
class ArBeautyVideoCapturer : VideoCapturer {
    private var surfaceTextureHelper: SurfaceTextureHelper? = null
    private var capturerObserver: CapturerObserver? = null
    private var capturing = false
    @Volatile
    private var pausedForCameraSwitch = false
    /** After flip resume, drop a few captures so the first published frame is clean. */
    private val warmupSkipRemaining = AtomicInteger(0)
    private var width = 720
    private var height = 1280
    private var frameIntervalMs = 66L
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pumping = AtomicBoolean(false)
    private var rgbaScratch: ByteBuffer? = null
    private val framesPushed = AtomicInteger(0)
    private val skippedBad = AtomicInteger(0)

    private val pumpRunnable = object : Runnable {
        override fun run() {
            if (!capturing) {
                pumping.set(false)
                return
            }
            try {
                pushOneFrame()
            } catch (t: Throwable) {
                Log.w(TAG, "pushOneFrame failed", t)
            }
            val helper = surfaceTextureHelper
            if (capturing && helper != null) {
                helper.handler.postDelayed(this, frameIntervalMs)
            } else {
                pumping.set(false)
            }
        }
    }

    override fun initialize(
        helper: SurfaceTextureHelper?,
        context: Context?,
        observer: CapturerObserver?,
    ) {
        surfaceTextureHelper = helper
        capturerObserver = observer
    }

    override fun startCapture(width: Int, height: Int, framerate: Int) {
        val observer = capturerObserver
        val helper = surfaceTextureHelper
        if (observer == null || helper == null) {
            Log.e(TAG, "startCapture before initialize")
            return
        }
        this.width = (width.coerceIn(360, 720) and 1.inv()).coerceAtLeast(360)
        this.height = (height.coerceIn(640, 1280) and 1.inv()).coerceAtLeast(640)
        if (this.width > this.height) {
            this.width = 720 and 1.inv()
            this.height = 1280 and 1.inv()
        }
        val fps = framerate.coerceIn(18, 24)
        frameIntervalMs = (1000L / fps).coerceIn(42L, 56L)
        capturing = true
        framesPushed.set(0)
        skippedBad.set(0)

        val gl = ArCameraBridge.warpGlView
        if (gl == null) {
            Log.e(TAG, "warpGlView null — cannot push beauty frames")
            observer.onCapturerStarted(false)
            capturing = false
            return
        }

        mainHandler.post {
            try {
                gl.setCaptureEnabled(true)
                gl.setCaptureMaxEdge(1280)
                gl.requestCaptureNow()
                mainHandler.postDelayed({ gl.requestCaptureNow() }, 50L)
                mainHandler.postDelayed({ gl.requestCaptureNow() }, 120L)
            } catch (t: Throwable) {
                Log.w(TAG, "enable FaceWarp capture failed", t)
            }
        }

        observer.onCapturerStarted(true)
        if (pumping.compareAndSet(false, true)) {
            helper.handler.postDelayed(pumpRunnable, 180L)
        }
        Log.i(TAG, "bitmap beauty pump started ${this.width}x${this.height}@$fps")
    }

    override fun stopCapture() {
        capturing = false
        surfaceTextureHelper?.handler?.removeCallbacks(pumpRunnable)
        mainHandler.removeCallbacks(pumpRunnable)
        pumping.set(false)
        mainHandler.post {
            try {
                ArCameraBridge.warpGlView?.setCaptureEnabled(false)
            } catch (_: Throwable) {
            }
        }
        rgbaScratch = null
        capturerObserver?.onCapturerStopped()
        Log.i(TAG, "bitmap beauty pump stopped after ${framesPushed.get()} frames")
    }

    override fun changeCaptureFormat(width: Int, height: Int, framerate: Int) {
        if (!capturing) return
        this.width = (width.coerceIn(360, 720) and 1.inv()).coerceAtLeast(360)
        this.height = (height.coerceIn(640, 1280) and 1.inv()).coerceAtLeast(640)
        if (this.width > this.height) {
            this.width = 720 and 1.inv()
            this.height = 1280 and 1.inv()
        }
        val fps = framerate.coerceIn(18, 24)
        frameIntervalMs = (1000L / fps).coerceIn(42L, 56L)
    }

    override fun dispose() {
        stopCapture()
        surfaceTextureHelper = null
        capturerObserver = null
    }

    override fun isScreencast(): Boolean = false

    fun pushedFrameCount(): Int = framesPushed.get()

    fun setPausedForCameraSwitch(paused: Boolean) {
        pausedForCameraSwitch = paused
        if (paused) {
            warmupSkipRemaining.set(0)
            mainHandler.post {
                try {
                    ArCameraBridge.warpGlView?.clearLastCapturedFrame()
                } catch (_: Throwable) {
                }
            }
        } else {
            // Drop post-flip captures until the OES transform settles — too few
            // and viewers still see one corrupt frame; too many feels laggy.
            warmupSkipRemaining.set(6)
        }
        Log.i(TAG, "pausedForCameraSwitch=$paused")
    }

    private fun pushOneFrame() {
        if (pausedForCameraSwitch) return
        val observer = capturerObserver ?: return
        val gl = ArCameraBridge.warpGlView ?: return

        mainHandler.post {
            try {
                gl.requestCaptureNow()
            } catch (_: Throwable) {
            }
        }

        val raw = try {
            gl.copyLastFilteredFrame()
        } catch (t: Throwable) {
            Log.w(TAG, "copyLastFilteredFrame failed", t)
            null
        } ?: return

        if (raw.isRecycled || raw.width < 2 || raw.height < 2) {
            try {
                raw.recycle()
            } catch (_: Throwable) {
            }
            return
        }

        // Landscape / tiny buffers must never reach LiveKit — viewers decode
        // them as horizontal static when the track is negotiated as 720x1280.
        if (raw.height < raw.width) {
            val n = skippedBad.incrementAndGet()
            if (n == 1 || n % 20 == 0) {
                Log.w(TAG, "skip landscape beauty frame ${raw.width}x${raw.height} #$n")
            }
            try {
                raw.recycle()
            } catch (_: Throwable) {
            }
            return
        }

        val skip = warmupSkipRemaining.get()
        if (skip > 0) {
            warmupSkipRemaining.decrementAndGet()
            try {
                raw.recycle()
            } catch (_: Throwable) {
            }
            return
        }

        // Never publish a non-portrait / wrong-size buffer — that is what turns
        // into horizontal static on the viewer after a camera flip.
        val scaled = scaleToExact(raw, width, height)
        try {
            raw.recycle()
        } catch (_: Throwable) {
        }
        if (scaled == null) {
            val n = skippedBad.incrementAndGet()
            if (n == 1 || n % 30 == 0) {
                Log.w(TAG, "skipped bad beauty frame #$n (need ${width}x$height)")
            }
            return
        }

        val frame = bitmapToVideoFrame(scaled)
        try {
            scaled.recycle()
        } catch (_: Throwable) {
        }
        if (frame == null) return

        try {
            observer.onFrameCaptured(frame)
        } finally {
            frame.release()
        }
        val n = framesPushed.incrementAndGet()
        if (n == 1 || n % 60 == 0) {
            Log.i(TAG, "pushed beauty frames=$n out=${width}x$height")
        }
    }

    /** Returns a new ARGB_8888 bitmap of exactly [targetW]x[targetH], or null. */
    private fun scaleToExact(src: Bitmap, targetW: Int, targetH: Int): Bitmap? {
        val tw = targetW and 1.inv()
        val th = targetH and 1.inv()
        if (tw < 2 || th < 2) return null
        if (src.isRecycled || src.width < 2 || src.height < 2) return null

        return try {
            if (src.width == tw && src.height == th && src.config == Bitmap.Config.ARGB_8888) {
                return src.copy(Bitmap.Config.ARGB_8888, false)
            }

            val scale = maxOf(tw.toFloat() / src.width, th.toFloat() / src.height)
            val rw = ((src.width * scale).toInt() and 1.inv()).coerceAtLeast(tw)
            val rh = ((src.height * scale).toInt() and 1.inv()).coerceAtLeast(th)
            val enlarged = Bitmap.createScaledBitmap(src, rw, rh, true)
            val x = ((enlarged.width - tw) / 2).coerceAtLeast(0)
            val y = ((enlarged.height - th) / 2).coerceAtLeast(0)
            if (x + tw > enlarged.width || y + th > enlarged.height) {
                if (enlarged !== src) enlarged.recycle()
                return null
            }
            val cropped = Bitmap.createBitmap(enlarged, x, y, tw, th)
            if (enlarged !== cropped) {
                try {
                    enlarged.recycle()
                } catch (_: Throwable) {
                }
            }
            if (cropped.config != Bitmap.Config.ARGB_8888) {
                val argb = cropped.copy(Bitmap.Config.ARGB_8888, false)
                if (argb !== cropped) cropped.recycle()
                argb
            } else {
                cropped
            }
        } catch (t: Throwable) {
            Log.w(TAG, "scaleToExact failed ${src.width}x${src.height}→${tw}x$th", t)
            null
        }
    }

    private fun bitmapToVideoFrame(bitmap: Bitmap): VideoFrame? {
        return try {
            if (bitmap.isRecycled) return null
            val w = bitmap.width
            val h = bitmap.height
            // Must match the negotiated LiveKit track size exactly.
            if (w != width || h != height) {
                Log.w(TAG, "reject frame ${w}x$h (track is ${width}x$height)")
                return null
            }
            if ((w and 1) != 0 || (h and 1) != 0) return null

            val rgbaBytes = w * h * 4
            var rgba = rgbaScratch
            if (rgba == null || rgba.capacity() < rgbaBytes) {
                rgba = ByteBuffer.allocateDirect(rgbaBytes)
                rgbaScratch = rgba
            }
            rgba!!.clear()
            rgba.limit(rgbaBytes)
            bitmap.copyPixelsToBuffer(rgba)
            if (rgba.position() < rgbaBytes) {
                Log.w(TAG, "copyPixelsToBuffer short ${rgba.position()}<$rgbaBytes")
                return null
            }
            rgba.rewind()
            rgba.limit(rgbaBytes)

            val i420 = JavaI420Buffer.allocate(w, h)
            YuvHelper.ABGRToI420(
                rgba,
                w * 4,
                i420.dataY,
                i420.strideY,
                i420.dataU,
                i420.strideU,
                i420.dataV,
                i420.strideV,
                w,
                h,
            )
            VideoFrame(i420, /* rotation */ 0, SystemClock.elapsedRealtimeNanos())
        } catch (t: Throwable) {
            Log.w(TAG, "bitmapToVideoFrame failed", t)
            null
        }
    }

    companion object {
        private const val TAG = "ArBeautyCapturer"
    }
}
