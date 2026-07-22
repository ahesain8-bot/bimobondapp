package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.SurfaceTexture
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.Surface

class FaceWarpGlView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : GLSurfaceView(context, attrs) {

    private val renderer = FaceWarpRenderer()
    private var glInitialized = false
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var cameraSurfaceTexture: SurfaceTexture? = null

    @Volatile
    var onCameraSurfaceReady: ((SurfaceTexture) -> Unit)? = null

    fun ensureGlInitialized() {
        if (glInitialized) return
        glInitialized = true
        renderer.onCameraSurfaceReady = { st ->
            cameraSurfaceTexture = st

            st.setOnFrameAvailableListener { requestRender() }
            mainHandler.post { onCameraSurfaceReady?.invoke(st) }
        }
        setEGLContextClientVersion(2)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        setRenderer(renderer)
        renderMode = RENDERMODE_WHEN_DIRTY
    }

    fun cameraSurfaceTexture(): SurfaceTexture? = cameraSurfaceTexture

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

        ensureGlInitialized()
        renderer.captureEnabled = enabled
    }

    fun takeLastFilteredFrame(): Bitmap? {
        if (!glInitialized) return null
        return renderer.takeLastCapturedFrame()
    }

    fun setCaptureMaxEdge(maxEdge: Int) {
        renderer.captureMaxEdge = maxEdge.coerceAtLeast(2)
    }

    fun setEncoderSurface(surface: Surface?, width: Int, height: Int) {
        ensureGlInitialized()
        queueEvent {
            renderer.setEncoderTarget(surface, width, height)
        }
        requestRender()
    }

    fun clearEncoderSurface(onDone: (() -> Unit)? = null) {
        if (!glInitialized) {
            onDone?.invoke()
            return
        }
        queueEvent {
            renderer.setEncoderTarget(null, 0, 0)
            if (onDone != null) mainHandler.post(onDone)
        }
        requestRender()
    }

    fun requestCaptureNow() {
        ensureGlInitialized()
        queueEvent {
            renderer.captureEnabled = true
            renderer.forceCaptureNextFrame = true
        }
        requestRender()
    }

    fun copyLastFilteredFrame(): Bitmap? {
        if (!glInitialized) return null
        return renderer.copyLastCapturedFrame()
    }

    fun clearLastCapturedFrame() {
        if (!glInitialized) return
        renderer.clearLastCapturedFrame()
    }

    fun releaseGl() {
        if (!glInitialized) return
        queueEvent {
            renderer.release()
        }
        glInitialized = false
    }
}
