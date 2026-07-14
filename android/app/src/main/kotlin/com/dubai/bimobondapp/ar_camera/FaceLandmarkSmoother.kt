package com.dubai.bimobondapp.ar_camera

import android.graphics.PointF
import android.graphics.RectF

/**
 * Adaptive exponential smoothing to reduce landmark jitter between frames.
 *
 * Uses a high base alpha (responsive) that jumps even higher when the face
 * moves quickly — mimicking TikTok's near-instant tracking feel while still
 * eliminating micro-jitter when the face is mostly still.
 */
object FaceLandmarkSmoother {

    /** Base interpolation weight toward the new frame (0 = frozen, 1 = raw). */
    private const val BASE_ALPHA = 0.75f

    /** Alpha used when a fast movement is detected. */
    private const val FAST_ALPHA = 0.95f

    /**
     * Movement threshold (fraction of face width). If the bounding-box centre
     * shifts more than this between two frames, we treat it as a fast motion.
     */
    private const val FAST_THRESHOLD_FRACTION = 0.06f

    @Volatile
    private var previous: FaceLandmarkSnapshot? = null

    fun reset() {
        previous = null
    }

    fun smooth(current: FaceLandmarkSnapshot): FaceLandmarkSnapshot {
        val prev = previous
        if (prev == null ||
            prev.imageWidth != current.imageWidth ||
            prev.imageHeight != current.imageHeight
        ) {
            previous = current
            return current
        }

        val alpha = computeAlpha(prev, current)

        val smoothed = FaceLandmarkSnapshot(
            imageWidth = current.imageWidth,
            imageHeight = current.imageHeight,
            boundingBox = lerpRect(prev.boundingBox, current.boundingBox, alpha),
            leftEye = lerpPoint(prev.leftEye, current.leftEye, alpha),
            rightEye = lerpPoint(prev.rightEye, current.rightEye, alpha),
            leftEyeBulge = lerpPoint(prev.leftEyeBulge, current.leftEyeBulge, alpha),
            rightEyeBulge = lerpPoint(prev.rightEyeBulge, current.rightEyeBulge, alpha),
            noseTip = lerpPoint(prev.noseTip, current.noseTip, alpha),
            noseBridge = lerpPoint(prev.noseBridge, current.noseBridge, alpha),
            mouthLeft = lerpPoint(prev.mouthLeft, current.mouthLeft, alpha),
            mouthRight = lerpPoint(prev.mouthRight, current.mouthRight, alpha),
            mouthBottom = lerpPoint(prev.mouthBottom, current.mouthBottom, alpha),
            topHead = lerpPoint(prev.topHead, current.topHead, alpha),
            landmarks = smoothLandmarks(prev.landmarks, current.landmarks, alpha),
        )
        previous = smoothed
        return smoothed
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    /** Choose alpha dynamically based on how much the face moved. */
    private fun computeAlpha(prev: FaceLandmarkSnapshot, cur: FaceLandmarkSnapshot): Float {
        val faceW = cur.boundingBox.width().coerceAtLeast(1f)
        val prevCx = prev.boundingBox.centerX()
        val prevCy = prev.boundingBox.centerY()
        val curCx = cur.boundingBox.centerX()
        val curCy = cur.boundingBox.centerY()
        val dx = (curCx - prevCx) / faceW
        val dy = (curCy - prevCy) / faceW
        val motion = kotlin.math.sqrt(dx * dx + dy * dy)
        return if (motion > FAST_THRESHOLD_FRACTION) FAST_ALPHA else BASE_ALPHA
    }

    private fun smoothLandmarks(
        prev: List<PointF>,
        cur: List<PointF>,
        alpha: Float,
    ): List<PointF> {
        if (prev.size != cur.size) return cur
        return List(cur.size) { i -> lerpPoint(prev[i], cur[i], alpha) }
    }

    private fun lerpPoint(from: PointF, to: PointF, alpha: Float): PointF {
        return PointF(
            from.x + (to.x - from.x) * alpha,
            from.y + (to.y - from.y) * alpha,
        )
    }

    private fun lerpRect(from: RectF, to: RectF, alpha: Float): RectF {
        return RectF(
            from.left + (to.left - from.left) * alpha,
            from.top + (to.top - from.top) * alpha,
            from.right + (to.right - from.right) * alpha,
            from.bottom + (to.bottom - from.bottom) * alpha,
        )
    }
}
