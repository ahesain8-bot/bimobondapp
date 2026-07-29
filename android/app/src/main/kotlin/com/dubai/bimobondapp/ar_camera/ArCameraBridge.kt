package com.dubai.bimobondapp.ar_camera

import android.app.Activity
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.Observer
import com.airbnb.lottie.LottieAnimationView
import com.airbnb.lottie.LottieDrawable

object ArCameraBridge {
    var faceOverlay: FaceOverlayView? = null
    var previewView: PreviewView? = null
    var warpGlView: FaceWarpGlView? = null
    var confettiOverlay: LottieAnimationView? = null

    /** Source currently loaded into [confettiOverlay] — see [applyRenderMode]. */
    private var loadedOverlayKey: String? = null

    /**
     * Animation the selected screen overlay should play, handed over by Dart
     * with the filter id. Null whenever the active filter isn't a screen
     * overlay.
     */
    @Volatile
    var currentOverlaySource: ScreenOverlaySource? = null
        private set
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

    @Volatile
    private var awaitFirstGlFrame: Boolean = false

    /** True once the first raw-preview → OES handoff has been scheduled. */
    @Volatile
    private var coldStartBindDone: Boolean = false

    private var coldStartPreviewObserver: Observer<PreviewView.StreamState>? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    private var freezeOverlay: ImageView? = null

    private var applyingOverlay: View? = null

    private var oesRevealFramesLeft = 0

    @Volatile
    private var oesTransitionPending = false

    /** True only after CameraX provided the OES Surface — ignore empty pre-bind GL frames. */
    @Volatile
    private var oesSurfaceLive = false

    /** ElapsedRealtime when first-filter OES transition started (0 = idle). For black/delay diag only. */
    @Volatile
    private var oesDiagStartMs: Long = 0L

    fun oesDiagElapsedMs(): Long {
        val start = oesDiagStartMs
        if (start == 0L) return -1L
        return SystemClock.elapsedRealtime() - start
    }

    /** Called from CameraX after Preview surface is provided to the OES SurfaceTexture. */
    fun onOesSurfaceProvided() {
        if (!awaitFirstGlFrame && !oesTransitionPending) return
        oesSurfaceLive = true
        oesRevealFramesLeft = 8
        android.util.Log.i(
            "ArFilterTap",
            "oesSurfaceLive armed frames=$oesRevealFramesLeft +${oesDiagElapsedMs()}ms",
        )
    }

    private fun diagVis(tag: String) {
        val freeze = freezeOverlay
        android.util.Log.i(
            "ArFilterTap",
            "VIS $tag +${oesDiagElapsedMs()}ms " +
                "gl=${warpGlView?.visibility} preview=${previewView?.visibility} " +
                "freeze=${if (freeze == null) "null" else "a=${freeze.alpha} vis=${freeze.visibility}"} " +
                "boundToOes=${ArCameraController.isBoundToOes()} oesLive=$oesSurfaceLive " +
                "await=$awaitFirstGlFrame revealLeft=$oesRevealFramesLeft pending=$oesTransitionPending",
        )
    }

    fun updateWarpViewSize(width: Int, height: Int) {
        if (width > 0 && height > 0) {
            warpViewWidth = width
            warpViewHeight = height
        }
    }

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

    fun setFilter(
        name: String,
        intensity: Float? = null,
        overlay: ScreenOverlaySource? = null,
    ) {
        if (intensity != null) {
            filterIntensity = intensity.coerceIn(0f, 1f)
        }
        // A screen overlay is identified by Dart sending an animation source
        // alongside the id, not by the id itself — overlay ids are defined by
        // the backend and mean nothing to [FilterType.fromId].
        val type = if (overlay != null && overlay.isValid) {
            FilterType.SCREEN_OVERLAY
        } else {
            FilterType.fromId(name)
        }
        val previousOverlayKey = currentOverlaySource?.cacheKey
        currentOverlaySource = if (type.isScreenOverlay()) overlay else null
        val previous = currentFilter
        currentFilter = type

        android.util.Log.i(
            "ArFilterTap",
            "setFilter name=$name type=$type prev=$previous " +
                "intensity=$filterIntensity " +
                "boundToOes=${ArCameraController.isBoundToOes()} " +
                "preferOes pending check " +
                "glVis=${warpGlView?.visibility} previewVis=${previewView?.visibility} " +
                "glSize=${warpGlView?.width}x${warpGlView?.height} " +
                "previewSize=${previewView?.width}x${previewView?.height} " +
                "letterbox=${letterboxTopPx}/${letterboxBottomPx}",
        )

        // Switching between two screen overlays keeps the same FilterType now
        // that they share one value, so the type comparison alone would miss it
        // — compare the animation too, or picking Snowfall after Confetti would
        // skip the reset onFilterChanged does.
        val overlaySwapped = type.isScreenOverlay() &&
            currentOverlaySource?.cacheKey != previousOverlayKey
        if (previous != type || overlaySwapped) {
            ArCameraController.onFilterChanged()
        }
        applyCurrentFilter()
    }

    fun updateFilterIntensity(intensity: Float) {
        filterIntensity = intensity.coerceIn(0f, 1f)
    }

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

    /**
     * Cold-open path: show CameraX's first raw frame immediately, then hand off
     * to the beauty OES pipeline under that frame. Binding OES before the first
     * PreviewView frame made the route sit black for the whole camera-session
     * startup; this keeps startup visible without changing the final renderer.
     */
    private fun beginOesDirectNoFreeze() {
        if (ArCameraController.isBoundToOes()) return
        if (!ArCameraController.canRebindCamera()) return
        val preview = previewView ?: return
        val owner = lifecycleOwner ?: return

        fun handOffToOes() {
            coldStartPreviewObserver?.let { observer ->
                try {
                    preview.previewStreamState.removeObserver(observer)
                } catch (_: Throwable) {
                }
            }
            coldStartPreviewObserver = null
            if (!ArCameraController.isBoundToOes() &&
                ArCameraController.canRebindCamera()
            ) {
                beginOesTransitionWithFreeze()
            }
        }

        if (preview.previewStreamState.value == PreviewView.StreamState.STREAMING) {
            handOffToOes()
            return
        }
        if (coldStartPreviewObserver != null) return

        val observer = Observer<PreviewView.StreamState> { state ->
            if (state == PreviewView.StreamState.STREAMING) {
                mainHandler.post { handOffToOes() }
            }
        }
        coldStartPreviewObserver = observer
        try {
            preview.previewStreamState.observe(owner, observer)
        } catch (_: Throwable) {
            coldStartPreviewObserver = null
        }
    }

    fun beginOesTransitionWithFreeze() {
        if (ArCameraController.isBoundToOes()) {
            android.util.Log.i("ArFilterTap", "beginOes: alreadyOnOes")
            return
        }
        if (oesTransitionPending) {
            android.util.Log.i("ArFilterTap", "beginOes: transitionPending")
            return
        }
        if (!ArCameraController.canRebindCamera()) {
            android.util.Log.w("ArFilterTap", "beginOes: canRebind=false — skip OES")
            return
        }
        val gl = warpGlView ?: run {
            android.util.Log.e("ArFilterTap", "beginOes: warpGlView null")
            return
        }
        oesDiagStartMs = SystemClock.elapsedRealtime()
        oesSurfaceLive = false
        android.util.Log.i(
            "ArFilterTap",
            "beginOes: START filter=$currentFilter " +
                "stReady=${gl.cameraSurfaceTexture() != null} " +
                "gl=${gl.width}x${gl.height}",
        )
        diagVis("beginOes.START")
        oesTransitionPending = true
        // No "Applying filter..." spinner here (or in finishAttach below). The
        // freeze frame already covers this transition with the last live frame,
        // so the camera reads as still running; layering a spinner and label on
        // top only made an otherwise invisible rebind look like a wait. The
        // showApplyingOverlay/clearApplyingOverlay machinery is left in place in
        // case a genuinely slow path needs it later.
        gl.ensureGlInitialized()
        gl.setOesEnabled(true)

        showFreezeFromPreview { hasFreezeFrame ->
            android.util.Log.i(
                "ArFilterTap",
                "beginOes: freezeReady=$hasFreezeFrame +${oesDiagElapsedMs()}ms",
            )
            diagVis("beginOes.freezeReady")
            awaitFirstGlFrame = true
            // Real countdown starts in onOesSurfaceProvided — ignore empty pre-bind frames.
            oesRevealFramesLeft = 8

            if (hasFreezeFrame) {
                // Freeze stays on top covering the rebind — never expose black GL/Preview.
                freezeOverlay?.alpha = 1f
                freezeOverlay?.bringToFront()
            } else {
                // No prior frame to protect behind a freeze — this is the common
                // cold-start case (no camera frame has ever been shown yet), so
                // there's nothing on screen to flicker. Bind OES directly; a brief
                // black frame here is the same one-time cost any camera app pays
                // before its first sensor frame arrives.
                android.util.Log.i(
                    "ArFilterTap",
                    "beginOes: NO freeze — binding OES directly (nothing to protect)",
                )
            }
            gl.visibility = View.VISIBLE
            previewView?.visibility = View.INVISIBLE
            diagVis("beginOes.afterHidePreview")
            ArCameraController.setPreferOesBinding(true)

            fun bindWhenSurfaceReady() {
                val ready = gl.cameraSurfaceTexture() != null
                android.util.Log.i(
                    "ArFilterTap",
                    "beginOes: bindWhenSurfaceReady stReady=$ready +${oesDiagElapsedMs()}ms",
                )
                if (ready) {
                    ArCameraController.ensureOesPreviewBound()
                } else {
                    gl.onCameraSurfaceReady = {
                        gl.onCameraSurfaceReady = null
                        android.util.Log.i(
                            "ArFilterTap",
                            "beginOes: onCameraSurfaceReady → ensureOes +${oesDiagElapsedMs()}ms",
                        )
                        ArCameraController.ensureOesPreviewBound()
                    }
                    gl.requestRender()
                }
            }
            mainHandler.post { bindWhenSurfaceReady() }
            mainHandler.postDelayed({
                if (!awaitFirstGlFrame) {
                    oesTransitionPending = false
                    android.util.Log.i("ArFilterTap", "beginOes: timeout skipped (already revealed)")
                    return@postDelayed
                }
                awaitFirstGlFrame = false
                oesRevealFramesLeft = 0
                oesTransitionPending = false
                val onOes = ArCameraController.isBoundToOes()
                android.util.Log.w(
                    "ArFilterTap",
                    "beginOes: TIMEOUT +${oesDiagElapsedMs()}ms boundToOes=$onOes — forcing reveal/fallback",
                )
                diagVis("beginOes.TIMEOUT")
                if (onOes) {
                    revealGlDropFreeze()
                } else {
                    ArCameraController.setPreferOesBinding(false)
                    gl.setOesEnabled(false)
                    gl.visibility = View.INVISIBLE
                    previewView?.visibility = View.VISIBLE
                    previewView?.bringToFront()
                    ArCameraController.forcePreviewViewRebind()
                    awaitFirstGlFrame = true
                    clearApplyingOverlay()
                    clearFreezeOverlay()
                    oesDiagStartMs = 0L
                    oesSurfaceLive = false
                }
            }, 2200L)
        }
    }

    /**
     * @param onReady true if a real preview still was placed as freeze overlay.
     */
    private fun showFreezeFromPreview(onReady: (hasFreezeFrame: Boolean) -> Unit) {
        val preview = previewView
        val root = platformRoot as? ViewGroup
        if (root == null) {
            android.util.Log.w("ArFilterTap", "freeze: root=null +${oesDiagElapsedMs()}ms")
            onReady(false)
            return
        }

        fun finishAttach(frame: Bitmap?, path: String) {
            val t0 = SystemClock.elapsedRealtime()
            clearFreezeOverlay()
            if (frame == null || frame.isRecycled) {
                android.util.Log.w(
                    "ArFilterTap",
                    "freeze: attach FAIL path=$path bmpNull +${oesDiagElapsedMs()}ms",
                )
                root.post { onReady(false) }
                return
            }
            val iv = ImageView(root.context).apply {
                layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                )
                scaleType = ImageView.ScaleType.CENTER_CROP
                setImageBitmap(frame)
                elevation = 10_000f
            }
            root.addView(iv)
            iv.bringToFront()
            freezeOverlay = iv
            android.util.Log.i(
                "ArFilterTap",
                "freeze: overlayAttached path=$path ${frame.width}x${frame.height} " +
                    "attachCost=${SystemClock.elapsedRealtime() - t0}ms +${oesDiagElapsedMs()}ms",
            )
            root.post { onReady(true) }
        }

        fun attachFreeze(bmp: Bitmap?, path: String) {
            if (bmp == null || bmp.isRecycled) {
                finishAttach(null, path)
                return
            }
            android.util.Log.i(
                "ArFilterTap",
                "freeze: attach IMMEDIATE (raw) path=$path bmp=${bmp.width}x${bmp.height} " +
                    "+${oesDiagElapsedMs()}ms",
            )
            finishAttach(bmp, path)
        }

        val bmp = capturePreviewBitmap(preview)
        if (bmp != null) {
            android.util.Log.i(
                "ArFilterTap",
                "freeze: capturePreviewBitmap OK ${bmp.width}x${bmp.height} +${oesDiagElapsedMs()}ms",
            )
            attachFreeze(bmp, "previewBitmap")
            return
        }
        android.util.Log.i(
            "ArFilterTap",
            "freeze: capturePreviewBitmap null — try PixelCopy +${oesDiagElapsedMs()}ms",
        )

        val surfaceView = preview?.let { findSurfaceView(it) }
        if (surfaceView != null && preview.width > 0 && preview.height > 0) {
            val copy = Bitmap.createBitmap(
                preview.width,
                preview.height,
                Bitmap.Config.ARGB_8888,
            )
            try {
                android.view.PixelCopy.request(
                    surfaceView,
                    copy,
                    { result ->
                        mainHandler.post {
                            android.util.Log.i(
                                "ArFilterTap",
                                "freeze: PixelCopy result=$result +${oesDiagElapsedMs()}ms",
                            )
                            if (result == android.view.PixelCopy.SUCCESS && !copy.isRecycled) {
                                attachFreeze(copy, "pixelCopy")
                            } else {
                                if (!copy.isRecycled) copy.recycle()
                                attachFreeze(null, "pixelCopyFail")
                            }
                        }
                    },
                    mainHandler,
                )
            } catch (t: Throwable) {
                android.util.Log.w("ArFilterTap", "freeze: PixelCopy throw ${t.message}")
                if (!copy.isRecycled) copy.recycle()
                attachFreeze(null, "pixelCopyThrow")
            }
            return
        }

        android.util.Log.w(
            "ArFilterTap",
            "freeze: no SurfaceView/size preview=${preview?.width}x${preview?.height}",
        )
        attachFreeze(null, "noSource")
    }

    private fun showApplyingOverlay(root: ViewGroup) {
        clearApplyingOverlay()
        val density = root.resources.displayMetrics.density
        val container = FrameLayout(root.context).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            elevation = 20_000f
            isClickable = false
            isFocusable = false
        }
        val column = LinearLayout(root.context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            )
        }
        val size = (52 * density).toInt()
        val spinner = ProgressBar(root.context).apply {
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                gravity = Gravity.CENTER_HORIZONTAL
            }
            indeterminateTintList = ColorStateList.valueOf(Color.WHITE)
        }
        val label = TextView(root.context).apply {
            text = "Applying filter..."
            setTextColor(Color.WHITE)
            textSize = 14f
            setShadowLayer(6f * density, 0f, 1f * density, Color.BLACK)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = (14 * density).toInt()
                gravity = Gravity.CENTER_HORIZONTAL
            }
        }
        column.addView(spinner)
        column.addView(label)
        container.addView(column)
        root.addView(container)
        container.bringToFront()
        applyingOverlay = container
        android.util.Log.i("ArFilterTap", "applyingOverlay shown +${oesDiagElapsedMs()}ms")
    }

    private fun clearApplyingOverlay() {
        val v = applyingOverlay ?: return
        applyingOverlay = null
        try {
            (v.parent as? ViewGroup)?.removeView(v)
        } catch (_: Throwable) {
        }
    }

    // ------------------------------------------------------ rebind cover
    //
    // Any camera rebind goes through `cameraProvider.unbindAll()`, which releases
    // the Preview surface and leaves the PreviewView showing black until the new
    // stream delivers its first frame — visible as a blink when the filter
    // category changes. Normal Mode's OES switch already had its own freeze-frame
    // for this; these two functions are the equivalent for every other rebind, and
    // are driven from the single funnel in ArCameraController.requestPreviewRebind.

    private var rebindCover: ImageView? = null
    private var rebindCoverObserver: Observer<PreviewView.StreamState>? = null

    /**
     * The stream state is already STREAMING when the cover goes up, so a bare
     * "wait for STREAMING" would fire immediately. Wait for it to drop to IDLE
     * (the unbind) first, and treat the following STREAMING as the real signal.
     */
    private var rebindCoverSawIdle = false

    private val clearRebindCoverRunnable = Runnable { clearRebindCover() }

    /** Freezes the last visible camera frame over the preview until it streams again. */
    fun coverPreviewForRebind() {
        if (freezeOverlay != null || rebindCover != null) return
        val root = platformRoot as? ViewGroup ?: return
        val preview = previewView ?: return
        val bmp = lastVisibleFrameBitmap() ?: return

        val iv = ImageView(root.context).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            scaleType = ImageView.ScaleType.CENTER_CROP
            setImageBitmap(bmp)
            // Under the freeze overlay's 10_000f so an OES transition still wins.
            elevation = 9_000f
        }
        applyVerticalMargins(iv, letterboxTopPx, letterboxBottomPx)
        root.addView(iv)
        iv.bringToFront()
        // The screen-overlay animation sits on top of the preview and keeps
        // running through the rebind, so it must stay above the cover.
        if (currentFilter.isScreenOverlay()) confettiOverlay?.bringToFront()
        if (currentFilter.isPngOverlay()) faceOverlay?.bringToFront()
        rebindCover = iv
        rebindCoverSawIdle = false

        val owner = lifecycleOwner
        if (owner != null) {
            val observer = Observer<PreviewView.StreamState> { state ->
                if (state == PreviewView.StreamState.IDLE) {
                    rebindCoverSawIdle = true
                } else if (state == PreviewView.StreamState.STREAMING && rebindCoverSawIdle) {
                    clearRebindCover()
                }
            }
            rebindCoverObserver = observer
            try {
                preview.previewStreamState.observe(owner, observer)
            } catch (_: Throwable) {
                rebindCoverObserver = null
            }
        }
        // Safety net: never leave a stale still on screen if the stream state
        // never reports back (bind failure, device quirk).
        mainHandler.removeCallbacks(clearRebindCoverRunnable)
        mainHandler.postDelayed(clearRebindCoverRunnable, REBIND_COVER_TIMEOUT_MS)
    }

    private fun clearRebindCover() {
        mainHandler.removeCallbacks(clearRebindCoverRunnable)
        rebindCoverObserver?.let { obs ->
            rebindCoverObserver = null
            try {
                previewView?.previewStreamState?.removeObserver(obs)
            } catch (_: Throwable) {
            }
        }
        val iv = rebindCover ?: return
        rebindCover = null
        rebindCoverSawIdle = false
        try {
            val bmp = (iv.drawable as? BitmapDrawable)?.bitmap
            (iv.parent as? ViewGroup)?.removeView(iv)
            iv.setImageDrawable(null)
            if (bmp != null && !bmp.isRecycled) bmp.recycle()
        } catch (_: Throwable) {
        }
    }

    private const val REBIND_COVER_TIMEOUT_MS = 1500L

    /**
     * Whichever surface the user is actually looking at right now.
     *
     * The GL branch matters for the most common blink of all: leaving Normal Mode
     * for an overlay filter. There the GL view is what's on screen and the
     * PreviewView is still unbound, so reading the PreviewView would hand back a
     * black frame — which is exactly what the cover exists to avoid showing.
     */
    private fun lastVisibleFrameBitmap(): Bitmap? {
        val preview = previewView
        if (preview != null && preview.visibility == View.VISIBLE) {
            capturePreviewBitmap(preview)?.let { return it }
        }
        val gl = warpGlView
        if (gl != null && gl.visibility == View.VISIBLE) {
            return try {
                gl.copyLastFilteredFrame()
            } catch (_: Throwable) {
                null
            }
        }
        return null
    }

    private fun capturePreviewBitmap(preview: PreviewView?): Bitmap? {
        if (preview == null || preview.width <= 0 || preview.height <= 0) return null
        try {
            preview.bitmap?.takeIf { !it.isRecycled }?.let { src ->
                return src.copy(Bitmap.Config.ARGB_8888, false) ?: src
            }
        } catch (_: Throwable) {
        }
        val tv = findTextureView(preview)
        if (tv != null && tv.isAvailable && tv.width > 0 && tv.height > 0) {
            try {
                val out = Bitmap.createBitmap(tv.width, tv.height, Bitmap.Config.ARGB_8888)
                val got = tv.getBitmap(out)
                if (got != null && !got.isRecycled) return got
                if (!out.isRecycled) out.recycle()
            } catch (_: Throwable) {
            }
        }
        return null
    }

    private fun findSurfaceView(root: View): android.view.SurfaceView? {
        if (root is android.view.SurfaceView) return root
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                val found = findSurfaceView(root.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }

    private fun findTextureView(root: View): android.view.TextureView? {
        if (root is android.view.TextureView) return root
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                val found = findTextureView(root.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }

    private fun clearFreezeOverlay() {
        val iv = freezeOverlay ?: return
        freezeOverlay = null
        android.util.Log.i("ArFilterTap", "freeze: clearOverlay +${oesDiagElapsedMs()}ms")
        try {
            val bmp = (iv.drawable as? BitmapDrawable)?.bitmap
            (iv.parent as? ViewGroup)?.removeView(iv)
            iv.setImageDrawable(null)
            if (bmp != null && !bmp.isRecycled) bmp.recycle()
        } catch (_: Throwable) {
        }
    }

    fun onGlFramePresented() {
        if (!awaitFirstGlFrame) return
        // OES path: ignore empty GL clears until CameraX surface is live.
        // Distortion (big eyes / lips / nose) uses CPU bitmaps into GL — no OES surface.
        if (ArCameraController.isBoundToOes() && !oesSurfaceLive) return

        if (oesRevealFramesLeft > 0) {
            oesRevealFramesLeft--
            android.util.Log.i(
                "ArFilterTap",
                "onGlFramePresented countdown left=$oesRevealFramesLeft +${oesDiagElapsedMs()}ms",
            )
            if (oesRevealFramesLeft > 0) {
                return
            }
        }
        val activity = hostActivity ?: return
        activity.runOnUiThread {
            if (!awaitFirstGlFrame) return@runOnUiThread
            awaitFirstGlFrame = false
            oesRevealFramesLeft = 0
            oesTransitionPending = false
            android.util.Log.i(
                "ArFilterTap",
                "onGlFramePresented REVEAL +${oesDiagElapsedMs()}ms " +
                    "boundToOes=${ArCameraController.isBoundToOes()} oesLive=$oesSurfaceLive",
            )
            diagVis("beforeReveal")
            revealGlDropFreeze()
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

    fun syncPreviewNaturalOrientation() {
        val preview = previewView ?: return
        preview.scaleX = 1f
    }

    /**
     * Forces the UI into the plainest possible state: GL view gone, overlays
     * hidden, PreviewView showing. Called when [ArCameraWatchdog] gives up on
     * the full pipeline — see ArCameraController.enterSimpleMode.
     */
    fun forceSimplePreview() {
        clearApplyingOverlay()
        clearFreezeOverlay()
        clearRebindCover()
        awaitFirstGlFrame = false
        oesTransitionPending = false
        oesSurfaceLive = false
        try {
            confettiOverlay?.cancelAnimation()
        } catch (_: Throwable) {
        }
        confettiOverlay?.visibility = View.GONE
        faceOverlay?.resetForNonPngFilter()
        faceOverlay?.visibility = View.GONE
        warpGlView?.setOesEnabled(false)
        warpGlView?.setCaptureEnabled(false)
        warpGlView?.visibility = View.GONE
        previewView?.visibility = View.VISIBLE
        previewView?.bringToFront()
    }

    private fun applyRenderMode(type: FilterType) {
        // Once the watchdog has degraded the pipeline, every filter renders as
        // plain preview — re-enabling GL or overlays here would walk straight
        // back into whatever stalled the camera in the first place.
        if (ArCameraWatchdog.degraded) {
            forceSimplePreview()
            return
        }
        val useShader = type.useShader()
        val usePngUnderlay = type.isPngOverlay()
        val useScreenOverlay = type.isScreenOverlay()
        val gl = warpGlView
        val preview = previewView

        syncPreviewNaturalOrientation()

        if (!usePngUnderlay) {
            faceOverlay?.resetForNonPngFilter()
        }
        faceOverlay?.visibility = if (usePngUnderlay) View.VISIBLE else View.GONE

        val confetti = confettiOverlay
        if (useScreenOverlay) {
            // Every overlay shares this one Lottie view — only one is ever
            // active at a time — so swap its animation whenever the selection
            // actually changes.
            val source = currentOverlaySource
            if (confetti != null && source != null && source.isValid &&
                source.cacheKey != loadedOverlayKey
            ) {
                try {
                    confetti.cancelAnimation()
                    confetti.repeatCount =
                        if (source.loop) LottieDrawable.INFINITE else 0
                    val url = source.url
                    if (!url.isNullOrBlank()) {
                        // Lottie caches downloaded compositions on disk itself,
                        // keyed by URL, so this is a network call only the first
                        // time a given overlay is ever used on the device — and
                        // usually not even then, because prefetchOverlays() has
                        // already warmed it. Async: onCompositionLoaded fires
                        // when it's ready.
                        confetti.setAnimationFromUrl(url)
                    } else {
                        confetti.setAnimation(source.assetName)
                    }
                    loadedOverlayKey = source.cacheKey
                } catch (t: Throwable) {
                    android.util.Log.e(
                        "ArCamera",
                        "screen overlay load failed: ${source.cacheKey}",
                        t,
                    )
                    loadedOverlayKey = null
                }
            }
            confetti?.visibility = View.VISIBLE
            confetti?.bringToFront()
            try {
                if (confetti != null && !confetti.isAnimating) confetti.playAnimation()
            } catch (_: Throwable) {
            }
        } else {
            try {
                confetti?.pauseAnimation()
            } catch (_: Throwable) {
            }
            confetti?.visibility = View.GONE
        }

        when {
            useShader -> {
                oesTransitionPending = false
                gl?.setOesEnabled(false)
                ArCameraController.setPreferOesBinding(false)

                ArCameraController.ensurePreviewViewBound()
                gl?.ensureGlInitialized()
                gl?.setRenderModeSafe(GLSurfaceView.RENDERMODE_WHEN_DIRTY)
                gl?.setCaptureEnabled(type.isDistortion())

                val alreadyOnGl =
                    gl != null &&
                        gl.visibility == View.VISIBLE &&
                        preview?.visibility == View.INVISIBLE

                if (alreadyOnGl) {
                    awaitFirstGlFrame = false
                    showGlHidePreview()
                } else {
                    awaitFirstGlFrame = true
                    gl?.visibility = View.INVISIBLE
                    preview?.visibility = View.VISIBLE
                    preview?.bringToFront()
                    faceOverlay?.bringToFront()
                }
            }

            usePngUnderlay -> {
                awaitFirstGlFrame = false
                oesTransitionPending = false
                gl?.setOesEnabled(false)
                ArCameraController.setPreferOesBinding(false)
                ArCameraController.ensurePreviewViewBound()
                gl?.setCaptureEnabled(false)
                gl?.visibility = View.GONE
                gl?.submitWarpParams(FaceWarpParams.INACTIVE)
                preview?.visibility = View.VISIBLE
                faceOverlay?.clearUnderlay()
                faceOverlay?.bringToFront()
            }

            useScreenOverlay -> {
                // Same full-res OES beauty pipeline as Normal Mode. The Lottie
                // view stays on top for live preview; recorded video composites
                // beautified GL frames + Lottie (see ArCameraController) so
                // overlay clips keep the same polish as Normal Mode video.
                // Hardware VideoCapture+OverlayEffect alone only sees the raw
                // sensor stream — beauty never reaches that path.
                gl?.submitWarpParams(FaceWarpParams.INACTIVE)
                gl?.setCaptureEnabled(true)
                if (!ArCameraController.isBoundToOes()) {
                    val canBindNow = gl != null && ArCameraController.canRebindCamera()
                    if (!coldStartBindDone && canBindNow) {
                        coldStartBindDone = true
                        beginOesDirectNoFreeze()
                    } else if (coldStartBindDone) {
                        beginOesTransitionWithFreeze()
                    }
                } else {
                    showGlHidePreview()
                }
            }

            else -> {
                // Normal Mode: live preview runs through the full-res OES/GPU
                // pipeline (same path used for photo/video capture) instead of a
                // raw CameraX PreviewView pass-through.
                gl?.submitWarpParams(FaceWarpParams.INACTIVE)
                gl?.setCaptureEnabled(true)
                if (!ArCameraController.isBoundToOes()) {
                    // Flutter can call setFilter() before the native camera view
                    // exists (initState fires before the PlatformView is created) —
                    // only consume the cold-start fast path once gl/rebind are
                    // actually ready, so that premature call doesn't "use up" the
                    // fast path and leave the real init stuck with the slow one.
                    val canBindNow = gl != null && ArCameraController.canRebindCamera()
                    if (!coldStartBindDone && canBindNow) {
                        // App just opened — nothing on screen yet, so skip the
                        // freeze/spinner ceremony and bind directly (fast, no
                        // "Applying filter..." overlay, no black-screen wait).
                        coldStartBindDone = true
                        beginOesDirectNoFreeze()
                    } else if (coldStartBindDone) {
                        // Real filter switch back to Normal Mode later in the
                        // session — freeze-frame transition still applies here.
                        beginOesTransitionWithFreeze()
                    }
                }
            }
        }
    }

    private fun bringDecorOverlaysToFront() {
        if (currentFilter.isScreenOverlay()) confettiOverlay?.bringToFront()
        if (currentFilter.isPngOverlay()) faceOverlay?.bringToFront()
    }

    private fun showGlHidePreview() {
        val gl = warpGlView
        val preview = previewView
        gl?.visibility = View.VISIBLE
        gl?.bringToFront()
        preview?.visibility = View.INVISIBLE
        bringDecorOverlaysToFront()
        clearApplyingOverlay()
        clearFreezeOverlay()
        // GL is now the visible surface; any PreviewView cover would only linger.
        clearRebindCover()
    }

    /** Swap to live GL under the freeze, then fade the still out (no hard blink). */
    private fun revealGlDropFreeze() {
        val gl = warpGlView
        val preview = previewView
        val freeze = freezeOverlay
        android.util.Log.i(
            "ArFilterTap",
            "revealGlDropFreeze start freeze=${freeze != null} +${oesDiagElapsedMs()}ms",
        )
        diagVis("reveal.start")
        clearApplyingOverlay()
        clearRebindCover()
        gl?.visibility = View.VISIBLE
        preview?.visibility = View.INVISIBLE
        if (freeze == null) {
            gl?.bringToFront()
            bringDecorOverlaysToFront()
            oesDiagStartMs = 0L
            oesSurfaceLive = false
            return
        }
        // Keep still on top while GL is already streaming underneath, then fade.
        freeze.bringToFront()
        freeze.animate().cancel()
        freeze.animate()
            .alpha(0f)
            .setDuration(120L)
            .withEndAction {
                android.util.Log.i(
                    "ArFilterTap",
                    "revealGlDropFreeze fadeDone +${oesDiagElapsedMs()}ms",
                )
                clearFreezeOverlay()
                gl?.bringToFront()
                bringDecorOverlaysToFront()
                diagVis("reveal.done")
                oesDiagStartMs = 0L
                oesSurfaceLive = false
            }
            .start()
    }

    fun clear() {
        ArCameraController.abortCapture()
        coldStartPreviewObserver?.let { observer ->
            try {
                previewView?.previewStreamState?.removeObserver(observer)
            } catch (_: Throwable) {
            }
        }
        coldStartPreviewObserver = null
        coldStartBindDone = false
        warpGlView?.releaseGl()
        clearApplyingOverlay()
        clearFreezeOverlay()
        clearRebindCover()
        try {
            confettiOverlay?.cancelAnimation()
        } catch (_: Throwable) {
        }
        faceOverlay = null
        previewView = null
        warpGlView = null
        confettiOverlay = null
        loadedOverlayKey = null
        currentOverlaySource = null
        platformRoot = null
        hostActivity = null
        lifecycleOwner = null
        currentFilter = FilterType.NONE
        filterIntensity = 1f
        awaitFirstGlFrame = false
        oesTransitionPending = false
        oesSurfaceLive = false
        oesDiagStartMs = 0L
        coldStartBindDone = false
        warpViewWidth = 0
        warpViewHeight = 0
        isFrontCamera = true
        letterboxTopPx = 0
        letterboxBottomPx = 0
    }
}
