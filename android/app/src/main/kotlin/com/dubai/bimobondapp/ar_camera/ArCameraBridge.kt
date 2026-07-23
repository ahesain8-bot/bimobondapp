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

    @Volatile
    private var awaitFirstGlFrame: Boolean = false

    private val mainHandler = Handler(Looper.getMainLooper())

    private val lutExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()

    @Volatile
    private var lutSubmitGen = 0

    private var freezeOverlay: ImageView? = null

    private var applyingOverlay: View? = null

    private var oesRevealFramesLeft = 0

    @Volatile
    private var oesTransitionPending = false

    /** True only after CameraX provided the OES Surface — ignore empty pre-bind GL frames. */
    @Volatile
    private var oesSurfaceLive = false

    @Volatile
    private var freezeBakeGen = 0

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

    private fun submitLutForCurrentFilter() {
        val gl = warpGlView ?: return
        val ctx = hostActivity?.applicationContext ?: return
        val gen = ++lutSubmitGen
        val asset = currentFilter.lutAsset()
        if (asset == null) {
            gl.submitLut(null)
            return
        }

        lutExecutor.execute {
            val bmp = LutStore.bitmap(ctx, asset)
            if (gen != lutSubmitGen) return@execute

            if (bmp != null) gl.submitLut(bmp)
        }
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

    fun setFilter(name: String, intensity: Float? = null) {
        if (intensity != null) {
            filterIntensity = intensity.coerceIn(0f, 1f)
        }
        val type = FilterType.fromId(name)
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

        if (previous != type) {
            ArCameraController.onFilterChanged()
        }
        applyCurrentFilter()
    }

    fun updateFilterIntensity(intensity: Float) {
        filterIntensity = intensity.coerceIn(0f, 1f)

        val gl = warpGlView ?: return
        if (currentFilter.isColorGrade()) {
            gl.setLutIntensity(filterIntensity)
            gl.requestRender()
        }
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

    fun beginOesTransitionWithFreeze() {
        if (ArCameraController.isBoundToOes()) {
            android.util.Log.i("ArFilterTap", "beginOes: alreadyOnOes — LUT only")
            return
        }
        if (oesTransitionPending) {
            android.util.Log.i("ArFilterTap", "beginOes: transitionPending — LUT refresh only")
            submitLutForCurrentFilter()
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
        // Spinner immediately so tap feels responsive while we capture the still.
        (platformRoot as? ViewGroup)?.let { showApplyingOverlay(it) }
        gl.ensureGlInitialized()
        gl.setOesEnabled(true)
        submitLutForCurrentFilter()

        showFreezeFromPreview { hasFreezeFrame ->
            android.util.Log.i(
                "ArFilterTap",
                "beginOes: freezeReady=$hasFreezeFrame +${oesDiagElapsedMs()}ms",
            )
            diagVis("beginOes.freezeReady")
            awaitFirstGlFrame = true
            // Real countdown starts in onOesSurfaceProvided — ignore empty pre-bind frames.
            oesRevealFramesLeft = 8

            if (!hasFreezeFrame) {
                android.util.Log.w("ArFilterTap", "beginOes: NO freeze — bitmap fallback (no OES rebind)")
                oesTransitionPending = false
                oesDiagStartMs = 0L
                oesSurfaceLive = false
                clearApplyingOverlay()
                ArCameraController.setPreferOesBinding(false)
                gl.setOesEnabled(false)
                gl.visibility = View.INVISIBLE
                previewView?.visibility = View.VISIBLE
                previewView?.bringToFront()
                return@showFreezeFromPreview
            }

            // Freeze stays on top covering the rebind — never expose black GL/Preview.
            freezeOverlay?.alpha = 1f
            freezeOverlay?.bringToFront()
            applyingOverlay?.bringToFront()
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
            showApplyingOverlay(root)
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
            // Critical path: raw still only — never bake on UI thread (was 400ms+ jank/black).
            finishAttach(bmp, path)

            if (!currentFilter.isColorGrade()) return
            val filter = currentFilter
            val intensity = filterIntensity
            val gen = ++freezeBakeGen
            val srcCopy = try {
                bmp.copy(Bitmap.Config.ARGB_8888, false)
            } catch (_: Throwable) {
                null
            } ?: return
            lutExecutor.execute {
                var baked: Bitmap? = null
                try {
                    val bakeStart = SystemClock.elapsedRealtime()
                    val small = ImageProxyBitmapUtils.scaleToMaxDimension(srcCopy, 720, filter = true)
                    if (small !== srcCopy && !srcCopy.isRecycled) srcCopy.recycle()
                    baked = ArColorGradeBaker.apply(small, filter, intensity)
                    if (small !== baked && !small.isRecycled) small.recycle()
                    android.util.Log.i(
                        "ArFilterTap",
                        "freeze: bakeBg ${SystemClock.elapsedRealtime() - bakeStart}ms " +
                            "filter=$filter thread=${Thread.currentThread().name} " +
                            "+${oesDiagElapsedMs()}ms",
                    )
                } catch (t: Throwable) {
                    android.util.Log.w("ArFilterTap", "freeze: bakeBg failed ${t.message}")
                    if (!srcCopy.isRecycled) srcCopy.recycle()
                    baked?.let { if (!it.isRecycled) it.recycle() }
                    return@execute
                }
                val frame = baked ?: return@execute
                mainHandler.post {
                    if (gen != freezeBakeGen || freezeOverlay == null || !awaitFirstGlFrame) {
                        if (!frame.isRecycled) frame.recycle()
                        return@post
                    }
                    val iv = freezeOverlay ?: run {
                        if (!frame.isRecycled) frame.recycle()
                        return@post
                    }
                    val old = (iv.drawable as? BitmapDrawable)?.bitmap
                    iv.setImageBitmap(frame)
                    if (old != null && old !== frame && !old.isRecycled) old.recycle()
                    applyingOverlay?.bringToFront()
                }
            }
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
        freezeBakeGen++
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
        // Color LUT / OES path: ignore empty GL clears until CameraX surface is live.
        // Distortion (big eyes / lips / nose) uses CPU bitmaps into GL — no OES surface.
        if (currentFilter.usesGpuPreview() && !oesSurfaceLive) return

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
        submitLutForCurrentFilter()
    }

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

                gl?.ensureGlInitialized()
                gl?.setRenderModeSafe(GLSurfaceView.RENDERMODE_WHEN_DIRTY)
                gl?.setLutIntensity(filterIntensity)
                // Throttled shutter buffer (see FaceWarpRenderer.captureMinIntervalMs).
                gl?.setCaptureMaxEdge(1080)
                gl?.setCaptureEnabled(true)

                val alreadyOnOes = ArCameraController.isBoundToOes()
                android.util.Log.i(
                    "ArFilterTap",
                    "applyRenderMode gpuPreview type=$type alreadyOnOes=$alreadyOnOes " +
                        "canRebind=${ArCameraController.canRebindCamera()}",
                )
                if (alreadyOnOes) {
                    gl?.setOesEnabled(true)
                    awaitFirstGlFrame = false
                    oesRevealFramesLeft = 0
                    oesTransitionPending = false
                    showGlHidePreview()
                } else if (ArCameraController.canRebindCamera()) {
                    beginOesTransitionWithFreeze()
                } else {

                    gl?.setOesEnabled(false)
                    ArCameraController.setPreferOesBinding(false)
                    val alreadyShowingGl =
                        gl != null &&
                            gl.visibility == View.VISIBLE &&
                            preview?.visibility == View.INVISIBLE
                    if (alreadyShowingGl) {
                        awaitFirstGlFrame = false
                    } else {
                        awaitFirstGlFrame = true
                        gl?.visibility = View.INVISIBLE
                        preview?.visibility = View.VISIBLE
                        preview?.bringToFront()
                    }
                }
            }

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

            else -> {
                // Original: if already on OES, stay there (no LUT) so the next color
                // filter is an instant LUT swap with zero blink/rebind.
                awaitFirstGlFrame = false
                oesTransitionPending = false
                gl?.submitWarpParams(FaceWarpParams.INACTIVE)
                if (ArCameraController.isBoundToOes()) {
                    ArCameraController.setPreferOesBinding(true)
                    gl?.setOesEnabled(true)
                    gl?.setRenderModeSafe(GLSurfaceView.RENDERMODE_WHEN_DIRTY)
                    // Warm one shutter buffer while staying on OES without a filter.
                    gl?.setCaptureMaxEdge(1080)
                    gl?.setCaptureEnabled(true)
                    showGlHidePreview()
                } else {
                    gl?.setCaptureEnabled(false)
                    ArCameraController.setPreferOesBinding(false)
                    gl?.setOesEnabled(false)
                    ArCameraController.ensurePreviewViewBound()
                    gl?.visibility = View.GONE
                    preview?.visibility = View.VISIBLE
                    preview?.bringToFront()
                    preview?.invalidate()
                    preview?.requestLayout()
                }
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
        clearApplyingOverlay()
        clearFreezeOverlay()
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
        gl?.visibility = View.VISIBLE
        preview?.visibility = View.INVISIBLE
        if (freeze == null) {
            gl?.bringToFront()
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
                diagVis("reveal.done")
                oesDiagStartMs = 0L
                oesSurfaceLive = false
            }
            .start()
    }

    fun clear() {
        ArCameraController.abortCapture()
        warpGlView?.releaseGl()
        clearApplyingOverlay()
        clearFreezeOverlay()
        faceOverlay = null
        previewView = null
        warpGlView = null
        platformRoot = null
        hostActivity = null
        lifecycleOwner = null
        currentFilter = FilterType.NONE
        filterIntensity = 1f
        awaitFirstGlFrame = false
        oesTransitionPending = false
        oesSurfaceLive = false
        oesDiagStartMs = 0L
        warpViewWidth = 0
        warpViewHeight = 0
        isFrontCamera = true
        letterboxTopPx = 0
        letterboxBottomPx = 0
    }
}
