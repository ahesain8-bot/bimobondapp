package com.dubai.bimobondapp.ar_camera

import android.graphics.Color

/**
 * Named beauty filter (Soft Glow, Pure, Rosy, Clean, ...) applied on top of the
 * live camera's baseline. Defaults match the always-on baseline that shipped
 * before named filters existed, so "Original" (no filter) keeps looking the
 * same as it always did — only smooth + lip tint are consumed by the shader so
 * far; whiten/brighten/blush are carried for later steps.
 */
data class LiveBeautyAdjustments(
    val smooth: Float = DEFAULT_SMOOTH,
    val whiten: Float = 0f,
    val brighten: Float = 0f,
    val blush: Float = 0f,
    val lipTintColor: FloatArray = DEFAULT_LIP_COLOR,
    val lipStrength: Float = 0f,
) {
    companion object {
        const val DEFAULT_SMOOTH = 0.55f
        val DEFAULT_LIP_COLOR = floatArrayOf(0.75f, 0.28f, 0.32f)
    }
}

object LiveBeautyState {
    @Volatile
    var adjustments: LiveBeautyAdjustments = LiveBeautyAdjustments()

    /**
     * Applies a named filter's raw 0..1 params scaled by [intensity] (overall
     * preset strength, e.g. from a slider). [lipTintHex] like "#E8527A".
     */
    fun apply(
        smooth: Float,
        whiten: Float,
        brighten: Float,
        blush: Float,
        lipTintHex: String,
        lipStrength: Float,
        intensity: Float,
    ) {
        val i = intensity.coerceIn(0f, 1f)
        adjustments = LiveBeautyAdjustments(
            smooth = (smooth * i).coerceIn(0f, 1f),
            whiten = (whiten * i).coerceIn(0f, 1f),
            brighten = (brighten * i).coerceIn(0f, 1f),
            blush = (blush * i).coerceIn(0f, 1f),
            lipTintColor = parseHexColor(lipTintHex),
            lipStrength = (lipStrength * i).coerceIn(0f, 1f),
        )
    }

    /** Back to the baseline (smooth only, no lip tint) — "Original" filter. */
    fun clear() {
        adjustments = LiveBeautyAdjustments()
    }

    private fun parseHexColor(hex: String): FloatArray {
        return try {
            val c = Color.parseColor(hex)
            floatArrayOf(Color.red(c) / 255f, Color.green(c) / 255f, Color.blue(c) / 255f)
        } catch (_: Exception) {
            LiveBeautyAdjustments.DEFAULT_LIP_COLOR
        }
    }
}
