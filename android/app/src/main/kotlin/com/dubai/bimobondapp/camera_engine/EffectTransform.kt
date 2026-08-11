package com.dubai.bimobondapp.camera_engine

/**
 * Phase 4: GPU sticker placement derived from face landmarks.
 * Coordinates are normalized image UVs [0,1] (same space as MediaPipe / landmark debug).
 */
data class EffectTransform(
    val centerX: Float,
    val centerY: Float,
    /** Normalized width in image space (fraction of frame width). */
    val width: Float,
    /** Normalized height in image space (fraction of frame height). */
    val height: Float,
    val rotationDeg: Float,
    val scaleX: Float = 1f,
    val mirrorX: Boolean = false,
    val opacity: Float = 1f,
    val pivotU: Float = 0.5f,
    val pivotV: Float = 0.5f,
)

enum class EffectPinX {
    REF_MIDPOINT,
    ANCHOR,
}

enum class EffectPinY {
    ANCHOR,
    REF_MIDLINE,
    ABOVE_REF,
}
