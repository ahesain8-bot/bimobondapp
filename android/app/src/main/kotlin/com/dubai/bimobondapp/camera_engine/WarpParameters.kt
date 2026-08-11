package com.dubai.bimobondapp.camera_engine

/**
 * Phase 6 face deformation controls — all intensities are 0.0–1.0.
 *
 * Positive values apply the named effect (slim / bigger eyes / smaller nose / etc.).
 */
data class WarpParameters(
    val faceSlim: Float = 0f,
    val bigEyes: Float = 0f,
    val smallNose: Float = 0f,
    val bigLips: Float = 0f,
    val jaw: Float = 0f,
    val chin: Float = 0f,
    val enabled: Boolean = true,
) {
    fun clamped(): WarpParameters = copy(
        faceSlim = faceSlim.coerceIn(0f, 1f),
        bigEyes = bigEyes.coerceIn(0f, 1f),
        smallNose = smallNose.coerceIn(0f, 1f),
        bigLips = bigLips.coerceIn(0f, 1f),
        jaw = jaw.coerceIn(0f, 1f),
        chin = chin.coerceIn(0f, 1f),
    )

    fun isVisuallyActive(): Boolean {
        if (!enabled) return false
        return faceSlim > 0.01f ||
            bigEyes > 0.01f ||
            smallNose > 0.01f ||
            bigLips > 0.01f ||
            jaw > 0.01f ||
            chin > 0.01f
    }

    fun needsFaceTracking(): Boolean = isVisuallyActive()
}
