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

    private val lutExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()

    @Volatile
    private var lutSubmitGen = 0

    /**
     * Loads the current color grade's LUT off the main thread and hands it to
     * the GL renderer (or clears it for non-grade filters). Called on every
     * filter change and again after a camera rebind so the LUT survives GL
     * context recreation. Falls back silently (renderer keeps its math path)
     * when the asset can't be loaded.
     */
    private fun submitLutForCurrentFilter() {
        val gl = warpGlView ?: return
        val ctx = hostActivity?.applicationContext ?: return
        val gen = ++lutSubmitGen
        val asset = currentFilter.lutAsset()
        if (asset == null) {
            gl.submitLut(null)
            return
        }
        // Keep the previous LUT on screen while the next one loads — never blank
        // the grade mid-swipe (that looked like a black/empty flash on some filters).
        lutExecutor.execute {
            val bmp = LutStore.bitmap(ctx, asset)
            if (gen != lutSubmitGen) return@execute
            // null load → leave the previous LUT; don't wipe the preview black.
            if (bmp != null) gl.submitLut(bmp)
        }
    }

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
        // Live-update the OES color grade without a rebuild (smooth slider).
        val gl = warpGlView ?: return
        if (currentFilter.isColorGrade()) {
            gl.setLutIntensity(filterIntensity)
            gl.requestRender()
        }
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
            // OES path (NONE + color grades) OR classic shader (distortion).
            if (!currentFilter.usesGpuPreview() && !currentFilter.useShader()) {
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
        submitLutForCurrentFilter()
    }

    /**
     * Keep PreviewView in the same left/right orientation as the OES path
     * (`frontMirror = false`). Do NOT apply scaleX=-1 for the front camera —
     * that flipped the preview whenever stickers switched from OES → PreviewView.
     */
    fun syncPreviewNaturalOrientation() {
        val preview = previewView ?: return
        preview.scaleX = 1f
    }

    private fun applyRenderMode(type: FilterType) {
        val useShader = type.useShader()
        val usePngUnderlay = type.isPngOverlay()
        val gl = warpGlView
        val preview = previewView

        syncPreviewNaturalOrientation()

        if (!usePngUnderlay) {
            faceOverlay?.resetForNonPngFilter()
        }
        faceOverlay?.visibility = if (usePngUnderlay) View.VISIBLE else View.GONE

        when {
            type.usesGpuPreview() -> {
                // Direct camera → OES → grade GPU path (stock-camera-smooth).
                // ALL color grades stay here so filter switches only swap the LUT —
                // no camera rebind (rebind was causing the black screen).
                gl?.ensureGlInitialized()
                gl?.setOesEnabled(true)
                gl?.setRenderModeSafe(GLSurfaceView.RENDERMODE_WHEN_DIRTY)
                gl?.setLutIntensity(filterIntensity)
                gl?.setCaptureEnabled(false)

                val alreadyOnOes = ArCameraController.isBoundToOes()
                if (alreadyOnOes) {
                    // Same GPU stream — just keep GL up. LUT swap is async & seamless.
                    awaitFirstGlFrame = false
                    showGlHidePreview()
                } else {
                    // Keep live PreviewView visible until the first OES frame arrives,
                    // otherwise the screen goes black during the one-time rebind.
                    awaitFirstGlFrame = true
                    gl?.visibility = View.INVISIBLE
                    preview?.visibility = View.VISIBLE
                    preview?.bringToFront()
                    mainHandler.postDelayed({
                        if (awaitFirstGlFrame && currentFilter.usesGpuPreview()) {
                            awaitFirstGlFrame = false
                            showGlHidePreview()
                        }
                    }, 800L)
                    ArCameraController.ensureOesPreviewBound()
                }
            }

            useShader -> {
                gl?.setOesEnabled(false)
                // Distortion (bitmap-warp) path uses the classic PreviewView binding.
                ArCameraController.ensurePreviewViewBound()
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
                gl?.setOesEnabled(false)
                ArCameraController.ensurePreviewViewBound()
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
                gl?.setOesEnabled(false)
                ArCameraController.ensurePreviewViewBound()
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
