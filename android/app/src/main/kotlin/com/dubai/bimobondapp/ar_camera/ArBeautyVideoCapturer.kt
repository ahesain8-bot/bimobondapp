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
    /**
     * When true, live-camera frames are candidates only. The pump keeps
     * running and publishes [heldBitmap] (last good 720x1280) until the new
     * lens is confirmed. Never starves VideoSource.
     */
    @Volatile
    private var switchPending = false
    private var expectedFront = true
    private var consecutiveGood = 0
    private var switchStartedElapsed = 0L
    private var timeoutLogged = false
    private var firstCandidateLogged = false
    private var lastCountedCaptureGen = -1
    private var lastGoodBitmap: Bitmap? = null
    private var heldBitmap: Bitmap? = null
    private var width = 720
    private var height = 1280
    private var frameIntervalMs = 66L
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pumping = AtomicBoolean(false)
    private var rgbaScratch: ByteBuffer? = null
    private var rgbaScratchW = 0
    private var rgbaScratchH = 0
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
        switchPending = false
        consecutiveGood = 0
        lastCountedCaptureGen = -1
        rgbaScratch = null
        rgbaScratchW = 0
        rgbaScratchH = 0

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
        rgbaScratchW = 0
        rgbaScratchH = 0
        recycleHeld()
        lastGoodBitmap?.recycle()
        lastGoodBitmap = null
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

    fun trackWidth(): Int = width

    fun trackHeight(): Int = height

    fun isPumpRunning(): Boolean = capturing && pumping.get()

    /**
     * CameraX is about to rebind. Keep pumping the last valid 720x1280 frame
     * with fresh timestamps. New GL frames are candidates only.
     */
    fun beginHoldLastGoodForSwitch(expectedFront: Boolean) {
        this.expectedFront = expectedFront
        switchPending = true
        consecutiveGood = 0
        lastCountedCaptureGen = try {
            ArCameraBridge.warpGlView?.captureGeneration() ?: -1
        } catch (_: Throwable) {
            -1
        }
        switchStartedElapsed = SystemClock.elapsedRealtime()
        timeoutLogged = false
        firstCandidateLogged = false
        val src = lastGoodBitmap
        if (src != null && !src.isRecycled) {
            try {
                val copy = src.copy(Bitmap.Config.ARGB_8888, false)
                if (copy != null) {
                    heldBitmap?.recycle()
                    heldBitmap = copy
                }
            } catch (_: Throwable) {
            }
        }
        mainHandler.post {
            try {
                val gl = ArCameraBridge.warpGlView ?: return@post
                gl.setCaptureEnabled(true)
                gl.setCaptureMaxEdge(1280)
                gl.requestCaptureNow()
            } catch (_: Throwable) {
            }
        }
        Log.i(
            TAG,
            "SWITCH_PAUSE expectedLens=${lensName(expectedFront)} " +
                "held=${heldBitmap?.width ?: 0}x${heldBitmap?.height ?: 0} " +
                "capturerRunning=$capturing captureLoopRunning=${isPumpRunning()}",
        )
    }

    private fun recycleHeld() {
        try {
            heldBitmap?.recycle()
        } catch (_: Throwable) {
        }
        heldBitmap = null
    }

    private fun rememberLastGood(src: Bitmap) {
        if (src.isRecycled || src.width != width || src.height != height) return
        val copy = try {
            src.copy(Bitmap.Config.ARGB_8888, false)
        } catch (_: Throwable) {
            null
        } ?: return
        val previous = lastGoodBitmap
        lastGoodBitmap = copy
        if (previous != null && previous !== copy && !previous.isRecycled) {
            try {
                previous.recycle()
            } catch (_: Throwable) {
            }
        }
    }

    private fun lensName(front: Boolean): String = if (front) "front" else "back"

    private fun pushOneFrame() {
        val observer = capturerObserver ?: return
        val gl = ArCameraBridge.warpGlView
        if (gl == null) {
            if (switchPending) publishHeld(observer)
            return
        }

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
        }

        if (switchPending) {
            handleSwitchCandidate(observer, gl, raw)
            return
        }

        if (raw == null) return
        publishLiveOrDrop(observer, raw)
    }

    private fun handleSwitchCandidate(
        observer: CapturerObserver,
        gl: FaceWarpGlView,
        raw: Bitmap?,
    ) {
        val currentFront = ArCameraBridge.isFrontCamera
        val transformReady = gl.isCameraTransformationInfoReady()
        val rot = gl.cameraRotationDegrees()
        val srcW = if (raw != null && !raw.isRecycled) raw.width else 0
        val srcH = if (raw != null && !raw.isRecycled) raw.height else 0
        val landscape = srcW >= 2 && srcH >= 2 && srcH < srcW
        val scaled = if (raw != null && !raw.isRecycled && !landscape) {
            scaleToExact(raw, width, height)
        } else {
            null
        }
        try {
            raw?.recycle()
        } catch (_: Throwable) {
        }

        val sizeValid = scaled != null &&
            !scaled.isRecycled &&
            scaled.width == width &&
            scaled.height == height
        val elapsed = SystemClock.elapsedRealtime() - switchStartedElapsed
        val timedOut = elapsed >= SWITCH_TIMEOUT_MS
        // Rotation 90/270 is NOT required. Xiaomi can report 0 after a flip
        // while the GL output is already a normalized 720x1280 portrait.
        val rotationValid = sizeValid && !landscape
        // Prefer TransformationInfo for the new lens. After timeout, portrait
        // 720x1280 alone is enough — missing metadata must not deadlock.
        val transformOk = transformReady || timedOut
        val gen = try {
            gl.captureGeneration()
        } catch (_: Throwable) {
            0
        }
        val freshCapture = gen > lastCountedCaptureGen
        val valid = transformOk && sizeValid && !landscape && freshCapture

        if (!firstCandidateLogged) {
            firstCandidateLogged = true
            Log.i(TAG, "SWITCH_FIRST_CANDIDATE src=${srcW}x$srcH rotation=$rot")
        }

        if (valid) {
            lastCountedCaptureGen = gen
            consecutiveGood++
        } else if (!sizeValid || landscape || !transformOk) {
            consecutiveGood = 0
        }

        Log.i(
            TAG,
            "SWITCH_CANDIDATE " +
                "lens=${lensName(currentFront)} " +
                "expectedLens=${lensName(expectedFront)} " +
                "src=${srcW}x$srcH " +
                "bitmap=${scaled?.width ?: srcW}x${scaled?.height ?: srcH} " +
                "rotation=$rot " +
                "transformReady=$transformReady " +
                "sizeValid=$sizeValid " +
                "rotationValid=$rotationValid " +
                "consecutiveGood=$consecutiveGood " +
                "publisherPaused=false " +
                "captureLoopRunning=${isPumpRunning()} " +
                "capturerRunning=$capturing",
        )

        val resumeBitmap = if (valid && consecutiveGood >= REQUIRED_GOOD_FRAMES) {
            scaled
        } else {
            null
        }
        if (resumeBitmap != null) {
            switchPending = false
            recycleHeld()
            Log.i(
                TAG,
                "SWITCH_RESUME consecutiveGood=$consecutiveGood " +
                    "lens=${lensName(currentFront)} rotation=$rot " +
                    "transformReady=$transformReady timedOut=$timedOut " +
                    "out=${width}x$height",
            )
            publishScaled(observer, resumeBitmap, remember = true)
            return
        }

        if (scaled != null && scaled !== heldBitmap) {
            try {
                scaled.recycle()
            } catch (_: Throwable) {
            }
        }

        if (timedOut && !timeoutLogged) {
            timeoutLogged = true
            Log.w(
                TAG,
                "SWITCH_TIMEOUT after ${elapsed}ms " +
                    "failedPredicate=" +
                    "transformReady=$transformReady " +
                    "sizeValid=$sizeValid " +
                    "landscape=$landscape " +
                    "rotationValid=$rotationValid " +
                    "rotation=$rot " +
                    "src=${srcW}x$srcH " +
                    "captureGen=$gen " +
                    "consecutiveGood=$consecutiveGood " +
                    "— keep sending held last-good frame, still evaluating candidates",
            )
        }
        publishHeld(observer)
    }

    private fun publishLiveOrDrop(observer: CapturerObserver, raw: Bitmap) {
        if (raw.isRecycled || raw.width < 2 || raw.height < 2) {
            try {
                raw.recycle()
            } catch (_: Throwable) {
            }
            return
        }

        val srcW = raw.width
        val srcH = raw.height
        if (srcH < srcW) {
            skippedBad.incrementAndGet()
            try {
                raw.recycle()
            } catch (_: Throwable) {
            }
            return
        }

        val scaled = scaleToExact(raw, width, height)
        try {
            raw.recycle()
        } catch (_: Throwable) {
        }
        if (scaled == null) {
            skippedBad.incrementAndGet()
            return
        }
        publishScaled(observer, scaled, remember = true)
    }

    private fun publishHeld(observer: CapturerObserver) {
        val held = heldBitmap
        if (held == null || held.isRecycled) return
        publishScaled(observer, held, remember = false, recycleAfter = false)
    }

    private fun publishScaled(
        observer: CapturerObserver,
        scaled: Bitmap,
        remember: Boolean,
        recycleAfter: Boolean = true,
    ) {
        val frame = bitmapToVideoFrame(scaled)
        if (remember && frame != null) {
            rememberLastGood(scaled)
        }
        if (recycleAfter && scaled !== heldBitmap && scaled !== lastGoodBitmap) {
            try {
                scaled.recycle()
            } catch (_: Throwable) {
            }
        }
        if (frame == null) return
        try {
            observer.onFrameCaptured(frame)
        } finally {
            frame.release()
        }
        val n = framesPushed.incrementAndGet()
        if (!switchPending && (n == 1 || n % 60 == 0)) {
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
                Log.w(TAG, "DROP reason=track_size bitmap ${w}x$h track=${width}x$height")
                return null
            }
            if ((w and 1) != 0 || (h and 1) != 0) return null

            val stride = bitmap.rowBytes
            if (stride < w * 4) {
                Log.w(TAG, "DROP reason=rowBytes stride=$stride widthBytes=${w * 4}")
                return null
            }
            val rgbaBytes = stride * h
            var rgba = rgbaScratch
            if (rgba == null ||
                rgbaScratchW != w ||
                rgbaScratchH != h ||
                rgba.capacity() < rgbaBytes
            ) {
                rgba = ByteBuffer.allocateDirect(rgbaBytes)
                rgbaScratch = rgba
                rgbaScratchW = w
                rgbaScratchH = h
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
                stride,
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
        private const val REQUIRED_GOOD_FRAMES = 3
        private const val SWITCH_TIMEOUT_MS = 5000L
    }
}
