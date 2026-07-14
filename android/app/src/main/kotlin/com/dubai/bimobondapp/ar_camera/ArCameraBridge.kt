package com.dubai.bimobondapp.ar_camera

import android.app.Activity
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner

object ArCameraBridge {
    var faceOverlay: FaceOverlayView? = null
    var previewView: PreviewView? = null
    var warpGlView: FaceWarpGlView? = null
    var platformRoot: View? = null
    var hostActivity: Activity? = null
    var lifecycleOwner: LifecycleOwner? = null

    @Volatile
    var currentFilter: FilterType = FilterType.NONE

    /** 0..1 strength for color / beauty grades (TikTok intensity slider). */
    @Volatile
    var filterIntensity: Float = 1f

    @Volatile
    var warpViewWidth: Int = 0

    @Volatile
    var warpViewHeight: Int = 0

    /**
     * True while we wait for the first GL filtered frame before covering the live Preview.
     * Avoids black flash — GLSurfaceView alpha tricks are unreliable on many OEM devices.
     */
    @Volatile
    private var awaitFirstGlFrame: Boolean = false

    private val mainHandler = Handler(Looper.getMainLooper())

    fun updateWarpViewSize(width: Int, height: Int) {
        if (width > 0 && height > 0) {
            warpViewWidth = width
            warpViewHeight = height
        }
    }

    fun setFilter(name: String, intensity: Float? = null) {
        if (intensity != null) {
            filterIntensity = intensity.coerceIn(0f, 1f)
        }
        val type = FilterType.fromId(name)
        val previous = currentFilter
        currentFilter = type
        // Only reset detection/cache when the filter *type* actually changes.
        if (previous != type) {
            ArCameraController.onFilterChanged()
        }
        applyCurrentFilter()
    }

    fun updateFilterIntensity(intensity: Float) {
        filterIntensity = intensity.coerceIn(0f, 1f)
    }

    /**
     * Pre-create the GL surface without covering PreviewView.
     * Uses INVISIBLE (not VISIBLE) — VISIBLE+alpha=0 still paints black on many phones.
     */
    fun prepareShaderPipeline() {
        val gl = warpGlView ?: return
        mainHandler.post {
            gl.ensureGlInitialized()
            if (gl.visibility == View.GONE && !currentFilter.useShader()) {
                gl.visibility = View.INVISIBLE
                gl.setRenderModeSafe(GLSurfaceView.RENDERMODE_WHEN_DIRTY)
            }
        }
    }

    /** Called after a GPU filtered frame is queued — swap Preview → GL safely. */
    fun onGlFramePresented() {
        if (!awaitFirstGlFrame) return
        val activity = hostActivity ?: return
        activity.runOnUiThread {
            if (!awaitFirstGlFrame) return@runOnUiThread
            if (!currentFilter.useShader()) {
                awaitFirstGlFrame = false
                return@runOnUiThread
            }
            awaitFirstGlFrame = false
            showGlHidePreview()
        }
    }

    fun applyCurrentFilter() {
        val activity = hostActivity
        if (activity != null) {
            activity.runOnUiThread { applyRenderMode(currentFilter) }
        } else {
            applyRenderMode(currentFilter)
        }
        faceOverlay?.setFilter(
            if (currentFilter.isPngOverlay()) currentFilter else FilterType.NONE,
        )
    }

    private fun applyRenderMode(type: FilterType) {
        val useShader = type.useShader()
        val usePngUnderlay = type.isPngOverlay()
        val gl = warpGlView
        val preview = previewView

        if (!usePngUnderlay) {
            faceOverlay?.resetForNonPngFilter()
        }
        faceOverlay?.visibility = if (usePngUnderlay) View.VISIBLE else View.GONE

        when {
            useShader -> {
                gl?.ensureGlInitialized()
                gl?.setRenderModeSafe(GLSurfaceView.RENDERMODE_WHEN_DIRTY)
                // Keep GPU readback on for face-warp so photo/video can bake the effect.
                gl?.setCaptureEnabled(type.isDistortion())

                val alreadyOnGl =
                    gl != null &&
                        gl.visibility == View.VISIBLE &&
                        preview?.visibility == View.INVISIBLE

                if (alreadyOnGl) {
                    // Color → color (or re-select): stay on GL, no swap.
                    awaitFirstGlFrame = false
                    showGlHidePreview()
                } else {
                    // Coming from Preview / Original: keep Preview on top until first GL frame.
                    awaitFirstGlFrame = true
                    // Keep GL mounted but behind/invisible to the user.
                    gl?.visibility = View.INVISIBLE
                    preview?.visibility = View.VISIBLE
                    preview?.bringToFront()
                    faceOverlay?.bringToFront()
                    // Safety: if a GL frame never arrives, restore a visible preview.
                    mainHandler.postDelayed({
                        if (awaitFirstGlFrame && currentFilter.useShader()) {
                            awaitFirstGlFrame = false
                            showGlHidePreview()
                        }
                    }, 600L)
                }
            }

            usePngUnderlay -> {
                awaitFirstGlFrame = false
                gl?.setCaptureEnabled(false)
                gl?.visibility = View.GONE
                gl?.submitWarpParams(FaceWarpParams.INACTIVE)
                preview?.visibility = View.INVISIBLE
                faceOverlay?.bringToFront()
            }

            else -> {
                // Original — Preview only.
                awaitFirstGlFrame = false
                gl?.setCaptureEnabled(false)
                gl?.visibility = View.GONE
                gl?.submitWarpParams(FaceWarpParams.INACTIVE)
                preview?.visibility = View.VISIBLE
                preview?.bringToFront()
                preview?.invalidate()
                preview?.requestLayout()
            }
        }
    }

    private fun showGlHidePreview() {
        val gl = warpGlView
        val preview = previewView
        gl?.visibility = View.VISIBLE
        gl?.bringToFront()
        preview?.visibility = View.INVISIBLE
        // Keep overlay above GL if a PNG filter is somehow active (shouldn't for color).
        if (currentFilter.isPngOverlay()) {
            faceOverlay?.bringToFront()
        }
    }

    fun clear() {
        ArCameraController.abortCapture()
        warpGlView?.releaseGl()
        faceOverlay = null
        previewView = null
        warpGlView = null
        platformRoot = null
        hostActivity = null
        lifecycleOwner = null
        currentFilter = FilterType.NONE
        filterIntensity = 1f
        awaitFirstGlFrame = false
        warpViewWidth = 0
        warpViewHeight = 0
    }
}
