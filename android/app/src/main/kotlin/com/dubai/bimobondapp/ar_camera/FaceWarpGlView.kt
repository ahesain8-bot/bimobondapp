package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.SurfaceTexture
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet

class FaceWarpGlView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : GLSurfaceView(context, attrs) {

    private val renderer = FaceWarpRenderer()
    private var glInitialized = false
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var cameraSurfaceTexture: SurfaceTexture? = null

    /** Notified (main thread) when the camera SurfaceTexture exists — bind camera. */
    @Volatile
    var onCameraSurfaceReady: ((SurfaceTexture) -> Unit)? = null

    fun ensureGlInitialized() {
        if (glInitialized) return
        glInitialized = true
        renderer.onCameraSurfaceReady = { st ->
            cameraSurfaceTexture = st
            // requestRender() is thread-safe — do NOT hop every camera frame onto the
            // main Handler (that was adding UI-thread jank / lag on every frame).
            st.setOnFrameAvailableListener { requestRender() }
            mainHandler.post { onCameraSurfaceReady?.invoke(st) }
        }
        setEGLContextClientVersion(2)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        setRenderer(renderer)
        renderMode = RENDERMODE_WHEN_DIRTY
    }

    fun cameraSurfaceTexture(): SurfaceTexture? = cameraSurfaceTexture

    /** Turns the direct camera→OES→grade GPU path on/off (color grades / none). */
    fun setOesEnabled(enabled: Boolean) {
        ensureGlInitialized()
        queueEvent { renderer.oesEnabled = enabled }
        requestRender()
    }

    fun isOesEnabled(): Boolean = renderer.oesEnabled

    fun setCameraTransform(rotationDegrees: Int, frontMirror: Boolean, bufW: Int, bufH: Int) {
        renderer.setCameraTransform(rotationDegrees, frontMirror, bufW, bufH)
    }

    fun setLutIntensity(intensity: Float) {
        renderer.lutIntensity = intensity
    }

    /** Invoked on the GL thread after each presented frame (preview swap + record). */
    fun setOnFramePresented(callback: (() -> Unit)?) {
        renderer.onFramePresented = callback
    }

    fun submitFrame(bitmap: Bitmap) {
        ensureGlInitialized()
        queueEvent {
            renderer.updateTexture(bitmap)
        }
        requestRender()
    }

    fun submitWarpParams(params: FaceWarpParams) {
        if (!glInitialized) return
        queueEvent {
            renderer.setWarpParams(params)
        }
    }

    /** Sets (or clears, when null) the active color-grade LUT on the GL thread. */
    fun submitLut(bitmap: Bitmap?) {
        ensureGlInitialized()
        queueEvent {
            renderer.setLut(bitmap)
        }
        requestRender()
    }

    fun setRenderModeSafe(mode: Int) {
        if (glInitialized) {
            renderMode = mode
        }
    }

    fun isGlInitialized(): Boolean = glInitialized

    fun submitFrameWithParams(bitmap: Bitmap, params: FaceWarpParams) {
        ensureGlInitialized()
        queueEvent {
            renderer.setWarpParams(params)
            renderer.updateTexture(bitmap)
        }
        requestRender()
    }

    fun setCaptureEnabled(enabled: Boolean) {
        // Volatile flag — no queueEvent needed (avoids per-frame GL-thread spam).
        ensureGlInitialized()
        renderer.captureEnabled = enabled
    }

    /**
     * Takes ownership of the last GPU capture (no extra Bitmap.copy). Caller must
     * recycle. Used by the recording path to avoid a full-frame copy every tick.
     */
    fun takeLastFilteredFrame(): Bitmap? {
        if (!glInitialized) return null
        return renderer.takeLastCapturedFrame()
    }

    fun setCaptureMaxEdge(maxEdge: Int) {
        renderer.captureMaxEdge = maxEdge.coerceAtLeast(2)
    }

    /** Force one GPU readback on the next draw (photo / keyframe). */
    fun requestCaptureNow() {
        ensureGlInitialized()
        queueEvent {
            renderer.captureEnabled = true
            renderer.forceCaptureNextFrame = true
        }
        requestRender()
    }

    /** Thread-safe copy of the last GPU-filtered frame (null if none yet). */
    fun copyLastFilteredFrame(): Bitmap? {
        if (!glInitialized) return null
        return renderer.copyLastCapturedFrame()
    }

    fun releaseGl() {
        if (!glInitialized) return
        queueEvent {
            renderer.release()
        }
        glInitialized = false
    }
}
