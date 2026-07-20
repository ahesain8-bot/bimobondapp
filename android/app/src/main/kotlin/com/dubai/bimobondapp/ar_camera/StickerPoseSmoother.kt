package com.dubai.bimobondapp.ar_camera

/**
 * EMA on resolved sticker pose (center / size / roll) so the PNG doesn't jitter.
 * Separate from landmark smoothing — operates on the final bind values.
 */
object StickerPoseSmoother {
    private const val ALPHA = 0.72f
    private const val FAST_ALPHA = 0.92f

    private val previous = HashMap<String, StickerPose>()

    fun reset() {
        previous.clear()
    }

    fun smooth(id: String, current: StickerPose): StickerPose {
        val prev = previous[id]
        if (prev == null) {
            previous[id] = current
            return current
        }
        val jump = kotlin.math.abs(current.centerX - prev.centerX) +
            kotlin.math.abs(current.centerY - prev.centerY)
        val a = if (jump > current.width * 0.08f) FAST_ALPHA else ALPHA
        val out = StickerPose(
            centerX = lerp(prev.centerX, current.centerX, a),
            centerY = lerp(prev.centerY, current.centerY, a),
            width = lerp(prev.width, current.width, a),
            height = lerp(prev.height, current.height, a),
            rollDeg = lerpAngle(prev.rollDeg, current.rollDeg, a),
            yawScaleX = lerp(prev.yawScaleX, current.yawScaleX, a),
            pivotU = current.pivotU,
            pivotV = current.pivotV,
        )
        previous[id] = out
        return out
    }

    private fun lerp(a: Float, b: Float, t: Float): Float = a + (b - a) * t

    private fun lerpAngle(a: Float, b: Float, t: Float): Float {
        var d = b - a
        while (d > 180f) d -= 360f
        while (d < -180f) d += 360f
        return a + d * t
    }
}
