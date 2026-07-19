package com.dubai.bimobondapp.ar_camera

import android.app.Activity
import android.graphics.Color
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
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

    @Volatile
    var filterIntensity: Float = 1f

    @Volatile
    var warpViewWidth: Int = 0

    @Volatile
    var warpViewHeight: Int = 0

    @Volatile
    var isFrontCamera: Boolean = true

    @Volatile
    private var letterboxTopPx: Int = 0

    @Volatile
    private var letterboxBottomPx: Int = 0

    fun isPreviewLetterboxed(): Boolean = letterboxTopPx > 0 || letterboxBottomPx > 0

    fun letterboxTopPx(): Int = letterboxTopPx

    fun letterboxBottomPx(): Int = letterboxBottomPx

    fun platformRootSize(): Pair<Int, Int>? {
        val root = platformRoot ?: return null
        if (root.width <= 0 || root.height <= 0) return null
        return root.width to root.height
    }

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

    /**
     * TikTok-style vertical letterbox inside the PlatformView (no Flutter resize flash).
     * Shrinking PreviewView/GL with FILL_CENTER zooms out while keeping full width.
     */
    fun setPreviewLetterbox(topPx: Int, bottomPx: Int) {
        letterboxTopPx = topPx.coerceAtLeast(0)
        letterboxBottomPx = bottomPx.coerceAtLeast(0)
        mainHandler.post { applyPreviewLetterbox() }
    }

    fun reapplyPreviewLetterbox() {
        mainHandler.post { applyPreviewLetterbox() }
    }

    private fun applyPreviewLetterbox() {
        val root = platformRoot
        root?.setBackgroundColor(Color.BLACK)
        applyVerticalMargins(previewView, letterboxTopPx, letterboxBottomPx)
        applyVerticalMargins(warpGlView, letterboxTopPx, letterboxBottomPx)
        applyVerticalMargins(faceOverlay, letterboxTopPx, letterboxBottomPx)
        warpGlView?.post {
            updateWarpViewSize(warpGlView?.width ?: 0, warpGlView?.height ?: 0)
        }
    }

    private fun applyVerticalMargins(view: View?, topPx: Int, bottomPx: Int) {
        if (view == null) return
        val lp = view.layoutParams as? FrameLayout.LayoutParams
            ?: FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        lp.width = ViewGroup.LayoutParams.MATCH_PARENT
        lp.height = ViewGroup.LayoutParams.MATCH_PARENT
        lp.topMargin = topPx
        lp.bottomMargin = bottomPx
        lp.leftMargin = 0
        lp.rightMargin = 0
        lp.gravity = android.view.Gravity.CENTER_HORIZONTAL or android.view.Gravity.TOP
        view.layoutParams = lp
        view.requestLayout()
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
                    awaitFirstGlFrame = false
                    showGlHidePreview()
                } else {
                    // Keep Preview visible until the first GL frame arrives (avoids black flash).
                    awaitFirstGlFrame = true
                    gl?.visibility = View.INVISIBLE
                    preview?.visibility = View.VISIBLE
                    preview?.bringToFront()
                    faceOverlay?.bringToFront()
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
                // PreviewView shows the live camera; faceOverlay draws only the sticker
                // on top (transparent). Keeping PreviewView VISIBLE also guarantees a
                // Surface on a flip (an INVISIBLE TextureView never produces one, which
                // otherwise times out the capture session → frozen preview). Clear any
                // stale underlay so it doesn't cover the live PreviewView.
                preview?.visibility = View.VISIBLE
                faceOverlay?.clearUnderlay()
                faceOverlay?.bringToFront()
            }

            else -> {
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
        isFrontCamera = true
        letterboxTopPx = 0
        letterboxBottomPx = 0
    }
}
