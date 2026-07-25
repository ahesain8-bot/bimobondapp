package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.util.SparseArray
import android.view.Choreographer
import android.view.View
import kotlin.math.max

class FaceOverlayView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : View(context, attrs) {

    private val boxPaint = Paint().apply {
        color = Color.GREEN
        style = Paint.Style.STROKE
        strokeWidth = 6f
    }

    private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val stickerBitmaps = SparseArray<Bitmap>()

    private var snapshots: List<FaceLandmarkSnapshot> = emptyList()
    private var imageWidth = 0
    private var imageHeight = 0
    private var isFrontCamera = true
    private var currentFilter = FilterType.NONE

    private var underlayFrame: Bitmap? = null

    /** Bumps only when MediaPipe landmarks change — drives pose prediction correctly. */
    private var landmarkSampleGen = 0L

    private var predictLoopActive = false
    private var predictFrameParity = 0
    private val predictFrameCallback: Choreographer.FrameCallback =
        object : Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                if (!predictLoopActive) return
                if (!currentFilter.isPngOverlay() || snapshots.isEmpty()) {
                    stopPredictLoop()
                    return
                }
                // Keep overlay prediction while recording — hardware encode no longer
                // fights the UI thread (software sticker bake path is gone).
                predictFrameParity++
                if (predictFrameParity % 2 == 0) {
                    invalidate()
                }
                Choreographer.getInstance().postFrameCallback(this)
            }
        }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        ensureAssetsLoaded()
        if (currentFilter.isPngOverlay() && snapshots.isNotEmpty()) {
            startPredictLoop()
        }
    }

    override fun onDetachedFromWindow() {
        stopPredictLoop()
        super.onDetachedFromWindow()
    }

    private fun startPredictLoop() {
        if (predictLoopActive) return
        predictLoopActive = true
        Choreographer.getInstance().postFrameCallback(predictFrameCallback)
    }

    private fun stopPredictLoop() {
        if (!predictLoopActive) return
        predictLoopActive = false
        Choreographer.getInstance().removeFrameCallback(predictFrameCallback)
    }

    private fun bitmapFor(resId: Int): Bitmap? {
        stickerBitmaps.get(resId)?.let { return it }
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val loaded = BitmapFactory.decodeResource(resources, resId, options) ?: return null
        stickerBitmaps.put(resId, loaded)
        return loaded
    }

    fun setLandmarks(
        snapshots: List<FaceLandmarkSnapshot>,
        imageWidth: Int,
        imageHeight: Int,
        isFrontCamera: Boolean,
    ) {

        if (!currentFilter.isPngOverlay()) return
        this.snapshots = snapshots
        this.imageWidth = imageWidth
        this.imageHeight = imageHeight
        this.isFrontCamera = isFrontCamera
        landmarkSampleGen++
        invalidate()
        if (snapshots.isNotEmpty()) startPredictLoop() else stopPredictLoop()
    }

    fun setUnderlayFrame(frame: Bitmap?) {

        if (frame != null && !currentFilter.isPngOverlay()) {
            if (!frame.isRecycled) frame.recycle()
            return
        }
        val previous = underlayFrame
        underlayFrame = frame
        if (previous != null && previous !== frame && !previous.isRecycled) {
            previous.recycle()
        }
        postInvalidate()
    }

    fun clearUnderlay() {
        val previous = underlayFrame
        underlayFrame = null
        if (previous != null && !previous.isRecycled) {
            previous.recycle()
        }
        postInvalidate()
    }

    fun resetForNonPngFilter() {
        stopPredictLoop()
        snapshots = emptyList()
        imageWidth = 0
        imageHeight = 0
        clearUnderlay()
    }

    fun setFilter(filter: FilterType) {
        if (currentFilter != filter) {
            StickerPoseSmoother.reset()
            landmarkSampleGen++
        }
        currentFilter = filter
        if (!filter.isPngOverlay()) {
            resetForNonPngFilter()
        } else if (snapshots.isNotEmpty()) {
            startPredictLoop()
        }
        postInvalidate()
    }

    fun composeOnto(cameraFrame: Bitmap): Bitmap {
        if (!currentFilter.isPngOverlay() || snapshots.isEmpty() || imageWidth == 0 || imageHeight == 0) {
            return cameraFrame
        }
        ensureAssetsLoaded()
        val out = if (cameraFrame.isMutable && cameraFrame.config == Bitmap.Config.ARGB_8888) {
            cameraFrame
        } else {
            cameraFrame.copy(Bitmap.Config.ARGB_8888, true) ?: return cameraFrame
        }
        val canvas = Canvas(out)
        val prevMode = mappingMode
        mappingMode = MappingMode.MIRRORED_BITMAP
        drawWidth = out.width
        drawHeight = out.height
        try {
            for (snapshot in snapshots) {
                drawConfiguredStickers(canvas, snapshot, extrapolate = false)
            }
        } finally {
            mappingMode = prevMode
            drawWidth = width
            drawHeight = height
        }
        return out
    }

    private enum class MappingMode { LIVE_VIEW, MIRRORED_BITMAP }

    private var mappingMode = MappingMode.LIVE_VIEW
    private var drawWidth: Int = 0
    private var drawHeight: Int = 0

    private fun ensureAssetsLoaded() {
        for (config in StickerCatalog.configsFor(currentFilter)) {
            bitmapFor(config.drawableRes)
        }

        for (config in listOf(
            StickerCatalog.glasses,
            StickerCatalog.shades,
            StickerCatalog.moustache,
            StickerCatalog.mask,
            StickerCatalog.dogEars,
            StickerCatalog.dogNose,
            StickerCatalog.dogTongue,
        )) {
            bitmapFor(config.drawableRes)
        }
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        drawWidth = w
        drawHeight = h
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width == 0 || height == 0) return
        mappingMode = MappingMode.LIVE_VIEW
        drawWidth = width
        drawHeight = height

        val frame = underlayFrame
        if (frame != null && !frame.isRecycled && imageWidth > 0 && imageHeight > 0) {

            val scale = max(width.toFloat() / imageWidth, height.toFloat() / imageHeight)
            val drawW = imageWidth * scale
            val drawH = imageHeight * scale
            val left = (width - drawW) / 2f
            val top = (height - drawH) / 2f
            canvas.drawBitmap(
                frame,
                null,
                RectF(left, top, left + drawW, top + drawH),
                bitmapPaint,
            )
        }

        if (imageWidth == 0 || imageHeight == 0) return

        for (snapshot in snapshots) {
            when (currentFilter) {
                FilterType.NONE -> drawBox(canvas, snapshot)
                else -> if (currentFilter.isPngOverlay()) {
                    drawConfiguredStickers(canvas, snapshot, extrapolate = true)
                }
            }
        }
    }

    private fun mapPoint(x: Float, y: Float): FloatArray {
        val viewW = (if (drawWidth > 0) drawWidth else width).toFloat()
        val viewH = (if (drawHeight > 0) drawHeight else height).toFloat()
        if (viewW <= 0f || viewH <= 0f || imageWidth <= 0 || imageHeight <= 0) {
            return floatArrayOf(0f, 0f)
        }

        return when (mappingMode) {

            MappingMode.MIRRORED_BITMAP -> {
                val sx = viewW / imageWidth
                val sy = viewH / imageHeight
                val mx = if (isFrontCamera) (imageWidth - x) * sx else x * sx
                floatArrayOf(mx, y * sy)
            }

            MappingMode.LIVE_VIEW -> {
                val scale = max(viewW / imageWidth, viewH / imageHeight)
                val offsetX = (viewW - imageWidth * scale) / 2f
                val offsetY = (viewH - imageHeight * scale) / 2f
                val mappedX = if (isFrontCamera) {
                    (imageWidth - x) * scale + offsetX
                } else {
                    x * scale + offsetX
                }
                floatArrayOf(mappedX, y * scale + offsetY)
            }
        }
    }

    private fun drawConfiguredStickers(
        canvas: Canvas,
        snapshot: FaceLandmarkSnapshot,
        extrapolate: Boolean,
    ) {
        ensureAssetsLoaded()
        for (config in StickerCatalog.configsFor(currentFilter)) {
            val bitmap = bitmapFor(config.drawableRes) ?: continue
            val raw = StickerScreenPoseResolver.resolve(config, snapshot, ::mapPoint) ?: continue
            val pose = if (extrapolate) {
                StickerPoseSmoother.smooth(config.id, raw, landmarkSampleGen)
            } else {
                raw
            }
            drawIntactSticker(canvas, bitmap, pose)
        }
    }

    private fun drawIntactSticker(canvas: Canvas, bitmap: Bitmap, pose: StickerPose) {
        if (pose.width <= 0f) return

        val targetWidth = pose.width
        val targetHeight = if (pose.height > 0f) {
            pose.height
        } else {
            val aspect = bitmap.height.toFloat() / bitmap.width.toFloat().coerceAtLeast(1f)
            targetWidth * aspect
        }

        val dest = RectF(0f, 0f, targetWidth, targetHeight)
        canvas.save()
        canvas.translate(pose.centerX, pose.centerY)
        canvas.rotate(pose.rollDeg)
        canvas.scale(pose.yawScaleX, 1f)
        canvas.translate(-targetWidth * pose.pivotU, -targetHeight * pose.pivotV)
        canvas.drawBitmap(bitmap, null, dest, bitmapPaint)
        canvas.restore()
    }

    private fun drawBox(canvas: Canvas, snapshot: FaceLandmarkSnapshot) {
        val box = snapshot.boundingBox
        val topLeft = mapPoint(box.left, box.top)
        val bottomRight = mapPoint(box.right, box.bottom)
        canvas.drawRect(
            minOf(topLeft[0], bottomRight[0]),
            minOf(topLeft[1], bottomRight[1]),
            maxOf(topLeft[0], bottomRight[0]),
            maxOf(topLeft[1], bottomRight[1]),
            boxPaint
        )
    }
}
