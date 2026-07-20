package com.dubai.bimobondapp.ar_camera

import android.graphics.PointF
import kotlin.math.sqrt

/**
 * Resolved sticker placement. When produced by [StickerScreenPoseResolver], all
 * geometry is in **view / screen pixels** (already mapped through mapPoint).
 */
data class StickerPose(
    val centerX: Float,
    val centerY: Float,
    val width: Float,
    /** Explicit quad height in the same units as [width]. <=0 = bitmap aspect. */
    val height: Float,
    val rollDeg: Float,
    /** Horizontal squeeze from yaw (1 = face-on, &lt;1 = turned). */
    val yawScaleX: Float,
    val pivotU: Float,
    val pivotV: Float,
)

/** Face size in screen pixels — used for width floors and vertical offsets. */
private data class ScreenFaceMetrics(
    val faceWidth: Float,
    val faceHeight: Float,
)

/**
 * Maps landmarks → exact screen placement using the same recipes as the old
 * per-filter draw functions (nose-bridge X + eye-line Y for glasses, etc.).
 */
object StickerScreenPoseResolver {

    fun resolve(
        config: StickerAnchorConfig,
        snapshot: FaceLandmarkSnapshot,
        mapPoint: (Float, Float) -> FloatArray,
    ): StickerPose? {
        val points = snapshot.landmarks
        if (points.size <= maxOf(
                config.leftLandmark,
                config.rightLandmark,
                config.anchorLandmark,
            )
        ) {
            return null
        }

        val faceMetrics = computeFaceMetrics(snapshot, mapPoint) ?: return null
        val anchor = points[config.anchorLandmark]

        val (refLeft, refRight) = refLandmarks(config, snapshot, forWidth = false)
        val (widthLeft, widthRight) = if (config.useAveragedEyes) {
            refLandmarks(config, snapshot, forWidth = true)
        } else {
            refLeft to refRight
        }

        val left = mapPoint(refLeft.x, refLeft.y)
        val right = mapPoint(refRight.x, refRight.y)
        val (screenL, screenR) = orderLeftRight(left, right)

        val wLeft = mapPoint(widthLeft.x, widthLeft.y)
        val wRight = mapPoint(widthRight.x, widthRight.y)
        val (widthScreenL, widthScreenR) = orderLeftRight(wLeft, wRight)
        val refSpan = distance(widthScreenL, widthScreenR)

        val roll = screenRoll(screenL, screenR) + config.rotationOffsetDeg
        val yawScale = yawScaleX(snapshot.yawDeg, config.yawSqueeze)

        val anchorScreen = mapPoint(anchor.x, anchor.y)
        val bridge = mapPoint(snapshot.noseBridge.x, snapshot.noseBridge.y)
        val noseTip = mapPoint(snapshot.noseTip.x, snapshot.noseTip.y)
        val mouthL = mapPoint(snapshot.mouthLeft.x, snapshot.mouthLeft.y)
        val mouthR = mapPoint(snapshot.mouthRight.x, snapshot.mouthRight.y)
        val mouthMidX = (mouthL[0] + mouthR[0]) * 0.5f
        val mouthMidY = (mouthL[1] + mouthR[1]) * 0.5f
        val eyeMidY = (screenL[1] + screenR[1]) * 0.5f

        val centerX = when (config.pinX) {
            StickerPinX.REF_MIDPOINT -> (screenL[0] + screenR[0]) * 0.5f
            StickerPinX.ANCHOR -> anchorScreen[0]
            StickerPinX.NOSE_BRIDGE -> bridge[0]
            StickerPinX.MOUTH_MIDPOINT -> mouthMidX
            StickerPinX.EYE_MIDPOINT -> (screenL[0] + screenR[0]) * 0.5f
        } + faceMetrics.faceWidth * config.offsetXFaceFrac

        val centerY = when (config.pinY) {
            StickerPinY.ANCHOR ->
                anchorScreen[1] + faceMetrics.faceHeight * config.offsetYFaceFrac
            StickerPinY.REF_MIDLINE ->
                (screenL[1] + screenR[1]) * 0.5f + faceMetrics.faceHeight * config.offsetYFaceFrac
            StickerPinY.EYE_LINE -> eyeMidY
            StickerPinY.NOSE_MOUTH_BLEND ->
                noseTip[1] * 0.4f + mouthMidY * 0.6f
            StickerPinY.TOP_HEAD_OFFSET -> {
                val top = mapPoint(snapshot.topHead.x, snapshot.topHead.y)
                top[1] + faceMetrics.faceHeight * config.offsetYFaceFrac
            }
        }

        var width = when {
            config.widthFaceFrac > 0f -> faceMetrics.faceWidth * config.widthFaceFrac
            config.widthScreenMult > 0f -> refSpan * config.widthScreenMult
            else -> refSpan * config.widthOverRef
        }
        if (config.widthMinFaceFrac > 0f) {
            width = maxOf(width, faceMetrics.faceWidth * config.widthMinFaceFrac)
        }
        if (config.maxFaceWidthFrac > 0f) {
            width = minOf(width, faceMetrics.faceWidth * config.maxFaceWidthFrac)
        }
        if (config.minFaceWidthFrac > 0f) {
            width = maxOf(width, faceMetrics.faceWidth * config.minFaceWidthFrac)
        }

        var height = 0f
        if (config.heightSpanFrac > 0f &&
            config.heightAnchorTopLandmark in points.indices &&
            config.heightAnchorBottomLandmark in points.indices
        ) {
            val topPt = mapPoint(
                points[config.heightAnchorTopLandmark].x,
                points[config.heightAnchorTopLandmark].y,
            )
            val bottomPt = mapPoint(
                points[config.heightAnchorBottomLandmark].x,
                points[config.heightAnchorBottomLandmark].y,
            )
            val vSpan = kotlin.math.abs(bottomPt[1] - topPt[1]).coerceAtLeast(1f)
            height = vSpan / config.heightSpanFrac
        }

        return StickerPose(
            centerX = centerX,
            centerY = centerY,
            width = width,
            height = height,
            rollDeg = roll,
            yawScaleX = yawScale,
            pivotU = config.pivotU,
            pivotV = config.pivotV,
        )
    }

    private fun refLandmarks(
        config: StickerAnchorConfig,
        snapshot: FaceLandmarkSnapshot,
        forWidth: Boolean,
    ): Pair<PointF, PointF> {
        if (config.useAveragedEyes && (!forWidth || config.widthScreenMult > 0f)) {
            return snapshot.leftEye to snapshot.rightEye
        }
        val pts = snapshot.landmarks
        return pts[config.leftLandmark] to pts[config.rightLandmark]
    }

    private fun computeFaceMetrics(
        snapshot: FaceLandmarkSnapshot,
        mapPoint: (Float, Float) -> FloatArray,
    ): ScreenFaceMetrics? {
        val box = snapshot.boundingBox
        val topLeft = mapPoint(box.left, box.top)
        val topRight = mapPoint(box.right, box.top)
        val bottomLeft = mapPoint(box.left, box.bottom)

        val faceWidth = sqrt(
            (topRight[0] - topLeft[0]) * (topRight[0] - topLeft[0]) +
                (topRight[1] - topLeft[1]) * (topRight[1] - topLeft[1]),
        )
        val faceHeight = sqrt(
            (bottomLeft[0] - topLeft[0]) * (bottomLeft[0] - topLeft[0]) +
                (bottomLeft[1] - topLeft[1]) * (bottomLeft[1] - topLeft[1]),
        )
        if (faceWidth <= 0f || faceHeight <= 0f) return null
        return ScreenFaceMetrics(faceWidth, faceHeight)
    }

    private fun orderLeftRight(a: FloatArray, b: FloatArray): Pair<FloatArray, FloatArray> =
        if (a[0] <= b[0]) a to b else b to a

    private fun distance(a: FloatArray, b: FloatArray): Float = sqrt(
        (b[0] - a[0]) * (b[0] - a[0]) + (b[1] - a[1]) * (b[1] - a[1]),
    )

    private fun screenRoll(screenL: FloatArray, screenR: FloatArray): Float =
        Math.toDegrees(
            kotlin.math.atan2(
                (screenR[1] - screenL[1]).toDouble(),
                (screenR[0] - screenL[0]).toDouble(),
            ),
        ).toFloat()

    private fun yawScaleX(yawDeg: Float, strength: Float): Float {
        if (strength <= 0f) return 1f
        val y = kotlin.math.abs(yawDeg).coerceIn(0f, 60f) / 60f
        return (1f - y * strength).coerceIn(0.55f, 1f)
    }
}
