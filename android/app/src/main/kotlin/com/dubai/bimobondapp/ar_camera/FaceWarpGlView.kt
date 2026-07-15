package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.opengl.GLSurfaceView
import android.util.AttributeSet

class FaceWarpGlView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : GLSurfaceView(context, attrs) {

    private val renderer = FaceWarpRenderer()
    private var glInitialized = false

    fun ensureGlInitialized() {
        if (glInitialized) return
        glInitialized = true
        setEGLContextClientVersion(2)
        setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        setRenderer(renderer)
        renderMode = RENDERMODE_WHEN_DIRTY
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
        queueEvent {
            renderer.captureEnabled = enabled
        }
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
