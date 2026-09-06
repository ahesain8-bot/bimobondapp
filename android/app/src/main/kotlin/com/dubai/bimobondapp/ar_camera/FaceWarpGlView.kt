package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.SurfaceTexture
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.util.Log
import android.view.Surface

/**
 * Picks an EGL config the GL context can share with the video encoder's surface.
 *
 * The previous `setEGLConfigChooser(8, 8, 8, 8, 16, 0)` gave the context an
 * RGBA8888 + 16-bit-depth config, while the encoder surface was created from a
 * separately chosen RGBA8888 + EGL_RECORDABLE_ANDROID config with no depth
 * buffer. EGL requires a surface and the context it is made current with to have
 * compatible configs; some GPUs tolerate the mismatch, others reject it outright
 * with EGL_BAD_MATCH on every single frame — which stalls the GL thread and
 * shows up as the camera freezing or going black while recording. Asking for a
 * recordable, depth-less config here means one config serves both surfaces.
 *
 * Depth is not requested because this renderer is entirely 2D.
 */
private class RecordableConfigChooser : GLSurfaceView.EGLConfigChooser {

    override fun chooseConfig(
        egl: javax.microedition.khronos.egl.EGL10,
        display: javax.microedition.khronos.egl.EGLDisplay,
    ): javax.microedition.khronos.egl.EGLConfig {
        pick(egl, display, recordable = true)?.let { return it }
        // Not every device advertises a recordable config; fall back rather than
        // fail to create the view at all. The renderer's encoder path queries the
        // context's actual config, so the two still match either way.
        pick(egl, display, recordable = false)?.let { return it }
        throw IllegalArgumentException("no suitable EGL config")
    }

    private fun pick(
        egl: javax.microedition.khronos.egl.EGL10,
        display: javax.microedition.khronos.egl.EGLDisplay,
        recordable: Boolean,
    ): javax.microedition.khronos.egl.EGLConfig? {
        val attribs = mutableListOf(
            javax.microedition.khronos.egl.EGL10.EGL_RED_SIZE, 8,
            javax.microedition.khronos.egl.EGL10.EGL_GREEN_SIZE, 8,
            javax.microedition.khronos.egl.EGL10.EGL_BLUE_SIZE, 8,
            javax.microedition.khronos.egl.EGL10.EGL_ALPHA_SIZE, 8,
            javax.microedition.khronos.egl.EGL10.EGL_DEPTH_SIZE, 0,
            javax.microedition.khronos.egl.EGL10.EGL_STENCIL_SIZE, 0,
            javax.microedition.khronos.egl.EGL10.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        )
        if (recordable) {
            attribs += listOf(EGL_RECORDABLE_ANDROID, 1)
        }
        attribs += javax.microedition.khronos.egl.EGL10.EGL_NONE

        val counts = IntArray(1)
        if (!egl.eglChooseConfig(display, attribs.toIntArray(), null, 0, counts) ||
            counts[0] <= 0
        ) {
            return null
        }
        val configs = arrayOfNulls<javax.microedition.khronos.egl.EGLConfig>(counts[0])
        if (!egl.eglChooseConfig(display, attribs.toIntArray(), configs, counts[0], counts)) {
            return null
        }
        return configs.firstOrNull()
    }

    private companion object {
        const val EGL_OPENGL_ES2_BIT = 4
        const val EGL_RECORDABLE_ANDROID = 0x3142
    }
}

class FaceWarpGlView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : GLSurfaceView(context, attrs) {

    private val renderer = FaceWarpRenderer()
    private var glInitialized = false
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Production POST camera always shades at the full useful view size (former
     * B / RAW_OES). The old ~1.2MP cap belonged to CURRENT_OES and is gone —
     * neutral frames use the cheap RAW_OES pass-through; active filters only
     * pay for their own work on top of that full-resolution surface.
     */
    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        renderer.setAndroidViewSize(w, h)
        applyFullRenderResolution(w, h)
    }

    /** Always match the view — never downscale then upscale the live preview. */
    private fun applyFullRenderResolution(viewW: Int, viewH: Int) {
        if (viewW <= 0 || viewH <= 0) return
        holder.setSizeFromLayout()
        Log.i(TAG, "render res: PRODUCTION_RAW_OES — cap bypassed, view ${viewW}x$viewH")
    }

    @Volatile
    private var cameraSurfaceTexture: SurfaceTexture? = null

    /**
     * One-shot callbacks waiting for the NEXT camera SurfaceTexture.
     *
     * A list, not a single slot: three independent paths wait for a new surface
     * — the host-resume rebuild ([ArCameraController.onHostResume]), the OES
     * bind ([ArCameraController.ensureOesPreviewBound]) and the filter
     * transition ([ArCameraBridge.beginOesTransitionWithFreeze]). With one slot
     * they overwrote each other: on resume the rebuild installs its waiter and
     * immediately nulls the surface via [recreateCameraSurfaceTexture], and any
     * applyCurrentFilter landing in that window sees no surface and installs its
     * own waiter on top, discarding the rebuild's. Whichever lost never ran, and
     * if the survivor's own guard then rejected it (the resume waiter drops out
     * when its generation is stale) nothing rebound at all — the intermittent
     * black camera after returning from another app.
     */
    private val cameraSurfaceWaiters = mutableListOf<(SurfaceTexture) -> Unit>()

    /**
     * Runs [block] once, when the next camera SurfaceTexture is published.
     *
     * Deliberately does not fire immediately for an already-present surface:
     * callers check that themselves first, and the resume path installs its
     * waiter while the OLD surface is still set, precisely because it is about
     * to replace it — firing early there would bind to the stale texture.
     */
    fun awaitCameraSurface(block: (SurfaceTexture) -> Unit) {
        synchronized(cameraSurfaceWaiters) { cameraSurfaceWaiters.add(block) }
    }

    fun ensureGlInitialized() {
        if (glInitialized) return
        glInitialized = true
        renderer.onCameraSurfaceReady = { st ->
            cameraSurfaceTexture = st

            st.setOnFrameAvailableListener {
                ArCameraDiagnostics.onOesCallback()
                requestRender()
            }
            mainHandler.post {
                val waiters = synchronized(cameraSurfaceWaiters) {
                    val pending = cameraSurfaceWaiters.toList()
                    cameraSurfaceWaiters.clear()
                    pending
                }
                waiters.forEach { waiter ->
                    try {
                        waiter(st)
                    } catch (t: Throwable) {
                        Log.w(TAG, "camera-surface waiter failed", t)
                    }
                }
            }
        }
        setEGLContextClientVersion(2)
        setEGLConfigChooser(RecordableConfigChooser())
        // Keep beauty under Flutter Hybrid Composition chrome (LIVE UI).
        setZOrderOnTop(false)
        setZOrderMediaOverlay(true)
        // The editor is a Flutter route over this still-mounted platform view.
        // suspendPreview() pauses this GLSurfaceView without pausing the Activity;
        // preserving EGL keeps the camera SurfaceTexture and shader resources
        // intact, avoiding corrupted/striped frames while a new context starts.
        preserveEGLContextOnPause = true
        setRenderer(renderer)
        renderMode = RENDERMODE_WHEN_DIRTY
    }

    /**
     * Runs [src] through the still beauty shader and returns the result, or null
     * if GL is unavailable or too slow to answer.
     *
     * Blocks the caller until the GL thread has rendered it, so this must be
     * called off the main thread. Used by the photo path, which already runs on a
     * background executor.
     */
    fun renderStillBlocking(src: android.graphics.Bitmap, timeoutMs: Long = 6_000L): Bitmap? {
        if (!glInitialized) return null
        val latch = java.util.concurrent.CountDownLatch(1)
        val holder = arrayOfNulls<Bitmap>(1)
        queueEvent {
            try {
                holder[0] = renderer.renderStill(src)
            } catch (_: Throwable) {
                holder[0] = null
            } finally {
                latch.countDown()
            }
        }
        requestRender()
        return try {
            if (latch.await(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)) {
                holder[0]
            } else {
                null
            }
        } catch (_: InterruptedException) {
            null
        }
    }

    fun cameraSurfaceTexture(): SurfaceTexture? = cameraSurfaceTexture

    fun recreateCameraSurfaceTexture() {
        if (!glInitialized) return
        cameraSurfaceTexture = null
        queueEvent {
            renderer.recreateCameraSurfaceTexture()
        }
        requestRender()
    }

    fun setOesEnabled(enabled: Boolean) {
        ensureGlInitialized()
        queueEvent { renderer.oesEnabled = enabled }
        requestRender()
    }

    fun isOesEnabled(): Boolean = renderer.oesEnabled

    fun setCameraTransform(rotationDegrees: Int, frontMirror: Boolean, bufW: Int, bufH: Int) {
        renderer.setCameraTransform(rotationDegrees, frontMirror, bufW, bufH)
    }

    fun cameraRotationDegrees(): Int = renderer.cameraRotationDegrees()

    /** Oriented camera buffer size for letterbox-free GL recording. */
    fun orientedCameraSize(): Pair<Int, Int> = renderer.orientedCameraSize()

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

    /** Average frame brightness, so the beauty pass can follow the light. */
    fun updateSceneLuma(luma: Float) {
        if (!glInitialized) return
        renderer.updateSceneLuma(luma)
    }

    fun updateSkinTone(luma: Float) {
        if (!glInitialized) return
        renderer.updateSkinTone(luma)
    }

    /**
     * Face area as a fraction of the analysis frame (0..1). Close selfies raise
     * this and the renderer boosts grain cleanup so magnified noise stays down.
     */
    fun updateFaceFill(fill: Float) {
        if (!glInitialized) return
        renderer.updateFaceFill(fill)
    }

    /** Skin-confidence mask (ALPHA_8, 255=skin) from ArCameraController's landmark rasterizer. */
    fun updateSkinMask(bitmap: Bitmap) {
        ensureGlInitialized()
        queueEvent {
            renderer.updateSkinMask(bitmap)
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

    /** Drops only frame-to-frame caches; beauty values and GL resources stay intact. */
    fun resetAfterRouteResume() {
        if (!glInitialized) return
        queueEvent {
            renderer.resetTransientFrameState()
        }
        requestRender()
    }

    fun releaseGl() {
        if (!glInitialized) return
        queueEvent {
            renderer.release()
        }
        glInitialized = false
        // No surface is coming now — drop waiters rather than leave them holding
        // callbacks (and the objects they capture) for a publish that cannot happen.
        synchronized(cameraSurfaceWaiters) { cameraSurfaceWaiters.clear() }
    }

    private companion object {
        const val TAG = "ArGlRenderRes"
    }
}
