package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import com.dubai.bimobondapp.R
import kotlin.math.atan2
import kotlin.math.max
import kotlin.math.sqrt

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

    private var glassesBitmap: Bitmap? = null
    private var moustacheBitmap: Bitmap? = null
    private var earsPart: FilterPart? = null
    private var nosePart: FilterPart? = null
    private var tonguePart: FilterPart? = null

    private var snapshots: List<FaceLandmarkSnapshot> = emptyList()
    private var imageWidth = 0
    private var imageHeight = 0
    private var isFrontCamera = true
    private var currentFilter = FilterType.NONE
    /** Mirrored analysis frame drawn under stickers so placement matches the camera content. */
    private var underlayFrame: Bitmap? = null

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }

        if (glassesBitmap == null) {
            glassesBitmap = BitmapFactory.decodeResource(resources, R.drawable.glasses_round, options)
        }
        if (moustacheBitmap == null) {
            moustacheBitmap =
                BitmapFactory.decodeResource(resources, R.drawable.filter_moustache, options)
        }

        if (earsPart == null) {
            earsPart = loadFilterPart(R.drawable.filter_ears, options)
            nosePart = loadFilterPart(R.drawable.filter_nose, options)
            tonguePart = loadFilterPart(R.drawable.filter_tongue, options)
        }
    }

    private data class FilterPart(
        val bitmap: Bitmap,
        val anchorX: Float,
        val anchorY: Float
    )

    private fun loadFilterPart(resId: Int, options: BitmapFactory.Options): FilterPart? {
        val bitmap = BitmapFactory.decodeResource(resources, resId, options) ?: return null
        val center = computeVisualCenter(bitmap)
        return FilterPart(bitmap, center[0], center[1])
    }

    private fun computeVisualCenter(bitmap: Bitmap): FloatArray {
        val w = bitmap.width
        val h = bitmap.height
        var minX = w
        var maxX = 0
        var minY = h
        var maxY = 0
        var found = false

        for (y in 0 until h) {
            for (x in 0 until w) {
                if (Color.alpha(bitmap.getPixel(x, y)) > 30) {
                    found = true
                    minX = minOf(minX, x)
                    maxX = maxOf(maxX, x)
                    minY = minOf(minY, y)
                    maxY = maxOf(maxY, y)
                }
            }
        }

        if (!found) {
            return floatArrayOf(w / 2f, h / 2f)
        }

        return floatArrayOf((minX + maxX) / 2f, (minY + maxY) / 2f)
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
                when (currentFilter) {
                    FilterType.SUNGLASSES -> drawGlasses(canvas, snapshot)
                    FilterType.EMOJI -> drawFaceFilter(canvas, snapshot)
                    FilterType.MOUSTACHE -> drawMoustache(canvas, snapshot)
                    else -> Unit
                }
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
        if (glassesBitmap != null && moustacheBitmap != null && earsPart != null) return
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        if (glassesBitmap == null) {
            glassesBitmap = BitmapFactory.decodeResource(resources, R.drawable.glasses_round, options)
        }
        if (moustacheBitmap == null) {
            moustacheBitmap =
                BitmapFactory.decodeResource(resources, R.drawable.filter_moustache, options)
        }
        if (earsPart == null) {
            earsPart = loadFilterPart(R.drawable.filter_ears, options)
            nosePart = loadFilterPart(R.drawable.filter_nose, options)
            tonguePart = loadFilterPart(R.drawable.filter_tongue, options)
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
                FilterType.SUNGLASSES -> drawGlasses(canvas, snapshot)
                FilterType.EMOJI -> drawFaceFilter(canvas, snapshot)
                FilterType.MOUSTACHE -> drawMoustache(canvas, snapshot)
                FilterType.WHITENING -> drawLipstick(canvas, snapshot, "#E91E63", 45)
                FilterType.WARM -> drawLipstick(canvas, snapshot, "#E64A19", 40)
                FilterType.BIG_EYES, FilterType.BIG_LIPS, FilterType.LONG_NOSE,
                FilterType.MONO, FilterType.COOL, FilterType.VINTAGE, FilterType.ROSY,
                FilterType.CLARENDON, FilterType.VALENCIA, FilterType.LUDWIG -> Unit
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
            // Photo/video frame is already mirrored and matches image aspect — map 1:1.
            MappingMode.MIRRORED_BITMAP -> {
                val sx = viewW / imageWidth
                val sy = viewH / imageHeight
                floatArrayOf((imageWidth - x) * sx, y * sy)
            }
            // Live view: FILL_CENTER. With underlay (mirrored analysis frame), map in mirrored space.
            // Without underlay, PreviewView front-camera path mirrors X.
            MappingMode.LIVE_VIEW -> {
                val scale = max(viewW / imageWidth, viewH / imageHeight)
                val offsetX = (viewW - imageWidth * scale) / 2f
                val offsetY = (viewH - imageHeight * scale) / 2f
                val mappedX = if (underlayFrame != null || isFrontCamera) {
                    // Equivalent: flip for mirrored underlay / front PreviewView.
                    (imageWidth - x) * scale + offsetX
                } else {
                    x * scale + offsetX
                }
                val mappedY = y * scale + offsetY
                floatArrayOf(mappedX, mappedY)
            }
        }
    }

    private fun faceMetrics(snapshot: FaceLandmarkSnapshot): FaceMetrics? {
        val box = snapshot.boundingBox
        val topLeft = mapPoint(box.left, box.top)
        val topRight = mapPoint(box.right, box.top)
        val bottomLeft = mapPoint(box.left, box.bottom)
        val bottomRight = mapPoint(box.right, box.bottom)

        val faceWidth = sqrt(
            (topRight[0] - topLeft[0]) * (topRight[0] - topLeft[0]) +
                (topRight[1] - topLeft[1]) * (topRight[1] - topLeft[1])
        )
        val faceHeight = sqrt(
            (bottomLeft[0] - topLeft[0]) * (bottomLeft[0] - topLeft[0]) +
                (bottomLeft[1] - topLeft[1]) * (bottomLeft[1] - topLeft[1])
        )

        if (faceWidth <= 0f || faceHeight <= 0f) return null

        return FaceMetrics(
            faceWidth = faceWidth,
            faceHeight = faceHeight,
            centerX = (topLeft[0] + topRight[0] + bottomLeft[0] + bottomRight[0]) / 4f,
            topCenterY = (topLeft[1] + topRight[1]) / 2f
        )
    }

    private fun distance(a: FloatArray, b: FloatArray): Float {
        return sqrt(
            (b[0] - a[0]) * (b[0] - a[0]) +
                (b[1] - a[1]) * (b[1] - a[1])
        )
    }

    private fun screenOrderedEyes(
        leftEye: FloatArray,
        rightEye: FloatArray
    ): Pair<FloatArray, FloatArray> {
        return if (leftEye[0] <= rightEye[0]) {
            leftEye to rightEye
        } else {
            rightEye to leftEye
        }
    }

    private fun eyeTiltAngle(screenLeft: FloatArray, screenRight: FloatArray): Float {
        return Math.toDegrees(
            atan2(
                (screenRight[1] - screenLeft[1]).toDouble(),
                (screenRight[0] - screenLeft[0]).toDouble()
            )
        ).toFloat()
    }

    private fun drawBitmapAt(
        canvas: Canvas,
        bitmap: Bitmap,
        centerX: Float,
        centerY: Float,
        targetWidth: Float,
        angle: Float
    ) {
        val aspect = bitmap.height.toFloat() / bitmap.width.toFloat()
        val targetHeight = targetWidth * aspect

        val destRect = RectF(
            -targetWidth / 2f,
            -targetHeight / 2f,
            targetWidth / 2f,
            targetHeight / 2f
        )

        canvas.save()
        canvas.translate(centerX, centerY)
        canvas.rotate(angle)
        canvas.drawBitmap(bitmap, null, destRect, bitmapPaint)
        canvas.restore()
    }

    private fun drawBitmapAnchored(
        canvas: Canvas,
        part: FilterPart,
        targetX: Float,
        targetY: Float,
        targetWidth: Float,
        angle: Float
    ) {
        val scale = targetWidth / part.bitmap.width
        canvas.save()
        canvas.translate(targetX, targetY)
        canvas.rotate(angle)
        canvas.scale(scale, scale)
        canvas.translate(-part.anchorX, -part.anchorY)
        canvas.drawBitmap(part.bitmap, 0f, 0f, bitmapPaint)
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

    private fun drawGlasses(canvas: Canvas, snapshot: FaceLandmarkSnapshot) {
        val bitmap = glassesBitmap ?: return
        val metrics = faceMetrics(snapshot) ?: return

        val left = mapPoint(snapshot.leftEye.x, snapshot.leftEye.y)
        val right = mapPoint(snapshot.rightEye.x, snapshot.rightEye.y)
        val (screenLeft, screenRight) = screenOrderedEyes(left, right)
        val bridge = mapPoint(snapshot.noseBridge.x, snapshot.noseBridge.y)

        val eyeDistance = distance(screenLeft, screenRight)
        val angle = eyeTiltAngle(screenLeft, screenRight)
        // Anchor on nose bridge (X) + eye line (Y) so glasses sit centered on the face.
        val centerX = bridge[0]
        val centerY = (screenLeft[1] + screenRight[1]) * 0.5f

        drawBitmapAt(
            canvas,
            bitmap,
            centerX,
            centerY,
            max(eyeDistance * 3.5f, metrics.faceWidth * 0.7f),
            angle,
        )
    }

    private fun drawMoustache(canvas: Canvas, snapshot: FaceLandmarkSnapshot) {
        val bitmap = moustacheBitmap ?: return
        val metrics = faceMetrics(snapshot) ?: return

        val ml = mapPoint(snapshot.mouthLeft.x, snapshot.mouthLeft.y)
        val mr = mapPoint(snapshot.mouthRight.x, snapshot.mouthRight.y)
        val (screenLeft, screenRight) = screenOrderedEyes(ml, mr)
        val nose = mapPoint(snapshot.noseTip.x, snapshot.noseTip.y)

        val mouthWidth = distance(screenLeft, screenRight)
        val angle = eyeTiltAngle(screenLeft, screenRight)
        val centerX = (screenLeft[0] + screenRight[0]) * 0.5f
        val mouthY = (screenLeft[1] + screenRight[1]) * 0.5f
        // Sit between nose tip and upper lip.
        val centerY = nose[1] * 0.4f + mouthY * 0.6f

        drawBitmapAt(
            canvas,
            bitmap,
            centerX,
            centerY,
            max(mouthWidth * 1.9f, metrics.faceWidth * 0.48f),
            angle,
        )
    }

    private fun drawFaceFilter(canvas: Canvas, snapshot: FaceLandmarkSnapshot) {
        val ears = earsPart ?: return
        val nose = nosePart ?: return
        val tongue = tonguePart ?: return
        val metrics = faceMetrics(snapshot) ?: return

        val left = mapPoint(snapshot.leftEye.x, snapshot.leftEye.y)
        val right = mapPoint(snapshot.rightEye.x, snapshot.rightEye.y)
        val (screenLeft, screenRight) = screenOrderedEyes(left, right)
        val faceNose = mapPoint(snapshot.noseTip.x, snapshot.noseTip.y)
        val faceMouth = mapPoint(snapshot.mouthBottom.x, snapshot.mouthBottom.y)

        val eyeDistance = distance(screenLeft, screenRight)
        val angle = eyeTiltAngle(screenLeft, screenRight)

        val ml = mapPoint(snapshot.mouthLeft.x, snapshot.mouthLeft.y)
        val mr = mapPoint(snapshot.mouthRight.x, snapshot.mouthRight.y)
        val faceCenterX = (ml[0] + mr[0]) / 2f

        val eyeCenterX = (snapshot.leftEye.x + snapshot.rightEye.x) / 2f
        val earImageY = snapshot.topHead.y - snapshot.boundingBox.height() * 0.18f
        val earAnchor = mapPoint(eyeCenterX, earImageY)

        val noseY = faceNose[1] + metrics.faceHeight * 0.01f
        val tongueY = faceMouth[1] + metrics.faceHeight * 0.04f

        drawBitmapAnchored(canvas, ears, earAnchor[0], earAnchor[1], metrics.faceWidth * 1.05f, angle)
        drawBitmapAnchored(canvas, nose, faceCenterX, noseY, eyeDistance * 1.1f, angle)
        drawBitmapAnchored(canvas, tongue, faceCenterX, tongueY, eyeDistance * 1.25f, angle)
    }

    private data class FaceMetrics(
        val faceWidth: Float,
        val faceHeight: Float,
        val centerX: Float,
        val topCenterY: Float
    )
}
