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
    /** Mirrored analysis frame drawn under stickers so placement matches the camera content. */
    private var underlayFrame: Bitmap? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        ensureAssetsLoaded()
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
        // Ignore stale analysis callbacks after leaving glasses/dog.
        if (!currentFilter.isPngOverlay()) return
        this.snapshots = snapshots
        this.imageWidth = imageWidth
        this.imageHeight = imageHeight
        this.isFrontCamera = isFrontCamera
        postInvalidate()
    }

    /**
     * Draws the same mirrored analysis frame stickers are computed from (pixel-perfect align).
     * Pass null to clear and show CameraX PreviewView again.
     */
    fun setUnderlayFrame(frame: Bitmap?) {
        // Ignore stale analysis callbacks after leaving glasses/dog.
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

    /** Clear underlay + landmarks when switching away from PNG overlays (e.g. back to Original). */
    fun resetForNonPngFilter() {
        snapshots = emptyList()
        imageWidth = 0
        imageHeight = 0
        clearUnderlay()
    }

    fun setFilter(filter: FilterType) {
        if (currentFilter != filter) {
            StickerPoseSmoother.reset()
        }
        currentFilter = filter
        if (!filter.isPngOverlay()) {
            resetForNonPngFilter()
        }
        postInvalidate()
    }

    /**
     * Bakes glasses/dog overlays onto a mirrored camera frame for photo/video capture.
     * Uses 1:1 image→bitmap mapping (not live-view FILL_CENTER) so stickers stay on the face.
     */
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
                drawConfiguredStickers(canvas, snapshot)
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
        // Warm common stickers so filter switches don't hitch.
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
            // Same FILL_CENTER used by mapPoint — stickers lock to this bitmap.
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
                FilterType.WHITENING -> drawLipstick(canvas, snapshot, "#E91E63", 45)
                FilterType.WARM -> drawLipstick(canvas, snapshot, "#E64A19", 40)
                else -> if (currentFilter.isPngOverlay()) {
                    drawConfiguredStickers(canvas, snapshot)
                }
            }
        }
    }

    private fun drawLipstick(canvas: Canvas, snapshot: FaceLandmarkSnapshot, colorHex: String, alphaValue: Int) {
        if (snapshot.landmarks.size < 300) return
        
        val path = android.graphics.Path()
        val startPt = mapPoint(snapshot.landmarks[61].x, snapshot.landmarks[61].y)
        path.moveTo(startPt[0], startPt[1])
        
        for (idx in MediaPipeLandmarkIndices.UPPER_LIP) {
            val pt = mapPoint(snapshot.landmarks[idx].x, snapshot.landmarks[idx].y)
            path.lineTo(pt[0], pt[1])
        }
        
        for (i in MediaPipeLandmarkIndices.LOWER_LIP.indices.reversed()) {
            val idx = MediaPipeLandmarkIndices.LOWER_LIP[i]
            val pt = mapPoint(snapshot.landmarks[idx].x, snapshot.landmarks[idx].y)
            path.lineTo(pt[0], pt[1])
        }
        path.close()
        
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.parseColor(colorHex)
            alpha = alphaValue
        }
        canvas.drawPath(path, paint)
    }

    private fun mapPoint(x: Float, y: Float): FloatArray {
        val viewW = (if (drawWidth > 0) drawWidth else width).toFloat()
        val viewH = (if (drawHeight > 0) drawHeight else height).toFloat()
        if (viewW <= 0f || viewH <= 0f || imageWidth <= 0 || imageHeight <= 0) {
            return floatArrayOf(0f, 0f)
        }

        return when (mappingMode) {
            // Capture bake: bitmaps are selfie-mirrored for front camera, so flip
            // landmark X to land on the mirrored pixels.
            MappingMode.MIRRORED_BITMAP -> {
                val sx = viewW / imageWidth
                val sy = viewH / imageHeight
                val mx = if (isFrontCamera) (imageWidth - x) * sx else x * sx
                floatArrayOf(mx, y * sy)
            }
            // Live view: CameraX PreviewView selfie-mirrors the front camera.
            // Landmarks stay in natural (un-mirrored) analysis space, so flip X
            // for front so stickers sit on the eyes/nose instead of the opposite side.
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

    /**
     * Draws every sticker listed for [currentFilter] as an **intact** PNG quad.
     * Placement is resolved in screen space from live landmarks (see
     * [StickerScreenPoseResolver]).
     */
    private fun drawConfiguredStickers(canvas: Canvas, snapshot: FaceLandmarkSnapshot) {
        ensureAssetsLoaded()
        for (config in StickerCatalog.configsFor(currentFilter)) {
            val bitmap = bitmapFor(config.drawableRes) ?: continue
            val raw = StickerScreenPoseResolver.resolve(config, snapshot, ::mapPoint) ?: continue
            val pose = StickerPoseSmoother.smooth(config.id, raw)
            drawIntactSticker(canvas, bitmap, pose)
        }
    }

    /** Intact textured quad — never mesh-slice the PNG. */
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
