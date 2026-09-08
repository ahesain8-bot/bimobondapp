package com.dubai.bimobondapp.ar_camera.beauty_v3

/**
 * Single V3 path from MediaPipe landmarks → canonical UV → screen.
 *
 * Landmark XY must go through [V3AnalysisToCanonicalTransform] when
 * `sensorMappingReady`. Never fabricates identity coordinates.
 */
object V3FaceCoordinateContract {

    /**
     * MediaPipe normalized → canonical UV.
     * @return false if sensor mapping is not ready (caller must not draw fabricated points)
     */
    fun mediaPipeNormToCanonical(
        x: Float,
        y: Float,
        mirrorX: Boolean,
        out: FloatArray,
        outOffset: Int = 0,
    ): Boolean {
        return V3AnalysisToCanonicalTransform.mapNormToCanonical(x, y, out, outOffset)
    }

    fun mediaPipeNormToCanonical(x: Float, y: Float, mirrorX: Boolean): FloatArray? {
        val out = FloatArray(2)
        if (!mediaPipeNormToCanonical(x, y, mirrorX, out, 0)) return null
        return out
    }

    fun analysisPixelToCanonical(
        x: Float,
        y: Float,
        analysisWidth: Int,
        analysisHeight: Int,
        mirrorX: Boolean,
    ): FloatArray? {
        val w = analysisWidth.coerceAtLeast(1).toFloat()
        val h = analysisHeight.coerceAtLeast(1).toFloat()
        return mediaPipeNormToCanonical(x / w, y / h, mirrorX)
    }

    fun canonicalToScreenUv(
        canonicalU: Float,
        canonicalV: Float,
        viewWidth: Int,
        viewHeight: Int,
        canonicalWidth: Int,
        canonicalHeight: Int,
        wideZoom: Float,
    ): FloatArray {
        val viewAspect = viewWidth.toFloat() / viewHeight.coerceAtLeast(1).toFloat()
        val texAspect = canonicalWidth.toFloat() / canonicalHeight.coerceAtLeast(1).toFloat()
        val t = (wideZoom - 1f).coerceIn(0f, 1f)

        fun invFill(fu: Float, fv: Float): FloatArray {
            return if (texAspect > viewAspect) {
                val s = viewAspect / texAspect
                floatArrayOf((fu - (1f - s) * 0.5f) / s, fv)
            } else {
                val s = texAspect / viewAspect
                floatArrayOf(fu, (fv - (1f - s) * 0.5f) / s)
            }
        }

        fun invFit(fu: Float, fv: Float): FloatArray {
            return if (texAspect > viewAspect) {
                val s = texAspect / viewAspect
                floatArrayOf(fu, (fv - (1f - s) * 0.5f) / s)
            } else {
                val s = viewAspect / texAspect
                floatArrayOf((fu - (1f - s) * 0.5f) / s, fv)
            }
        }

        val fill = invFill(canonicalU, canonicalV)
        val fit = invFit(canonicalU, canonicalV)
        return floatArrayOf(
            fill[0] + (fit[0] - fill[0]) * t,
            fill[1] + (fit[1] - fill[1]) * t,
        )
    }

    fun canonicalToNdc(
        canonicalU: Float,
        canonicalV: Float,
        contract: V3FrameContract,
        outNdc: FloatArray,
        outOffset: Int = 0,
        requireOnScreen: Boolean = true,
    ): Boolean {
        val screen = canonicalToScreenUv(
            canonicalU,
            canonicalV,
            contract.viewWidth,
            contract.viewHeight,
            contract.canonicalWidth,
            contract.canonicalHeight,
            contract.wideZoom,
        )
        val su = screen[0]
        val sv = screen[1]
        if (requireOnScreen && (su !in 0f..1f || sv !in 0f..1f)) return false
        if (!su.isFinite() || !sv.isFinite()) return false
        outNdc[outOffset] = su * 2f - 1f
        outNdc[outOffset + 1] = 1f - sv * 2f
        return true
    }
}
