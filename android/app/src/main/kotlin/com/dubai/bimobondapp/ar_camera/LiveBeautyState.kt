package com.dubai.bimobondapp.ar_camera

import android.graphics.Color
import kotlin.math.max

/**
 * Named beauty filter applied on top of the live camera baseline. Defaults stay
 * light so Normal Mode follows the room lighting instead of a bright overlay.
 */
data class LiveBeautyAdjustments(
    val smooth: Float = DEFAULT_SMOOTH,
    val whiten: Float = DEFAULT_WHITEN,
    val brighten: Float = DEFAULT_BRIGHTEN,
    val blush: Float = 0f,
    val lipTintColor: FloatArray = DEFAULT_LIP_COLOR,
    val lipStrength: Float = 0f,
) {
    companion object {
        /** Light cleanup only — pores/texture stay; higher values read as plastic. */
        const val DEFAULT_SMOOTH = 0.20f

        /** Near-off — room brightness comes from camera EV, with a light face open. */
        const val DEFAULT_WHITEN = 0.04f
        const val DEFAULT_BRIGHTEN = 0.14f

        /**
         * Smooth response curve midpoint. The camera UI supplies its own
         * default slider position (currently 30%); 50 remains the curve anchor.
         */
        const val MAGIC_AUTO_STRENGTH = 0.50f

        /** Internal effect strength that slider=50 produces. */
        const val MAGIC_ANCHOR_EFFECT = 0.90f

        /** Shader smooth at slider 0 / 0.5 / 1 while Magic is On. */
        const val MAGIC_SMOOTH_MIN = 0.48f
        const val MAGIC_SMOOTH_ANCHOR = 0.73f
        const val MAGIC_SMOOTH_MAX = 0.99f

        /** Camera Magic-On defaults without dedicated Flutter sliders. */
        const val MAGIC_DEFAULT_WHITEN = 0.10f
        const val MAGIC_DEFAULT_SHARPEN = 0.08f

        /** Wide blemish pull stops growing above default to avoid blurry patches. */
        const val MAGIC_BLEMISH_MIN = 0.48f
        const val MAGIC_BLEMISH_ANCHOR = 0.93f

        val DEFAULT_LIP_COLOR = floatArrayOf(0.75f, 0.28f, 0.32f)

        /**
         * Smooth slider (0..1) → shader effect strength.
         * 0 → 0, 0.5 → [MAGIC_ANCHOR_EFFECT], 1 → 1.
         */
        fun effectFromSlider(slider: Float): Float {
            val s = slider.coerceIn(0f, 1f)
            return if (s <= 0.5f) {
                s / 0.5f * MAGIC_ANCHOR_EFFECT
            } else {
                MAGIC_ANCHOR_EFFECT +
                    (s - 0.5f) / 0.5f * (1f - MAGIC_ANCHOR_EFFECT)
            }
        }

        fun smoothFromStrength(slider: Float): Float {
            val s = slider.coerceIn(0f, 1f)
            return if (s <= MAGIC_AUTO_STRENGTH) {
                MAGIC_SMOOTH_MIN +
                    (s / MAGIC_AUTO_STRENGTH) *
                    (MAGIC_SMOOTH_ANCHOR - MAGIC_SMOOTH_MIN)
            } else {
                MAGIC_SMOOTH_ANCHOR +
                    ((s - MAGIC_AUTO_STRENGTH) / (1f - MAGIC_AUTO_STRENGTH)) *
                    (MAGIC_SMOOTH_MAX - MAGIC_SMOOTH_ANCHOR)
            }
        }

        fun blemishFromStrength(slider: Float): Float {
            val s = slider.coerceIn(0f, 1f)
            if (s >= MAGIC_AUTO_STRENGTH) return MAGIC_BLEMISH_ANCHOR
            return MAGIC_BLEMISH_MIN +
                (s / MAGIC_AUTO_STRENGTH) *
                (MAGIC_BLEMISH_ANCHOR - MAGIC_BLEMISH_MIN)
        }
    }
}

object LiveBeautyState {
    @Volatile
    var adjustments: LiveBeautyAdjustments = LiveBeautyAdjustments()

    /** Retouch panel Off/On — face smooth boost, independent of color filters. */
    @Volatile
    var magicOn: Boolean = false

    /** 0..1 Smooth slider while Magic is On. */
    @Volatile
    var magicStrength: Float = LiveBeautyAdjustments.MAGIC_AUTO_STRENGTH

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
        val appliedSmooth = (smooth * i).coerceIn(0f, 1f)
        adjustments = LiveBeautyAdjustments(
            smooth = if (magicOn) {
                max(appliedSmooth, LiveBeautyAdjustments.smoothFromStrength(magicStrength))
            } else {
                appliedSmooth
            },
            whiten = (whiten * i).coerceIn(0f, 1f),
            brighten = (brighten * i).coerceIn(0f, 1f),
            blush = (blush * i).coerceIn(0f, 1f),
            lipTintColor = parseHexColor(lipTintHex),
            lipStrength = (lipStrength * i).coerceIn(0f, 1f),
        )
    }

    fun setMagic(enabled: Boolean, strength: Float? = null) {
        magicOn = enabled
        if (strength != null) {
            magicStrength = strength.coerceIn(0f, 1f)
        } else if (enabled) {
            magicStrength = LiveBeautyAdjustments.MAGIC_AUTO_STRENGTH
        }
        val cur = adjustments
        adjustments = if (enabled) {
            cur.copy(smooth = LiveBeautyAdjustments.smoothFromStrength(magicStrength))
        } else {
            cur.copy(smooth = LiveBeautyAdjustments.DEFAULT_SMOOTH)
        }
    }

    fun applyMagicStrength(strength: Float) {
        magicStrength = strength.coerceIn(0f, 1f)
        if (!magicOn) return
        adjustments = adjustments.copy(
            smooth = LiveBeautyAdjustments.smoothFromStrength(magicStrength),
        )
    }

    fun effectiveWhiten(): Float =
        if (magicOn) {
            max(adjustments.whiten, LiveBeautyAdjustments.MAGIC_DEFAULT_WHITEN)
        } else {
            adjustments.whiten
        }

    /** Back to the baseline (smooth only, no lip tint) — "Original" filter. */
    fun clear() {
        adjustments = LiveBeautyAdjustments(
            smooth = if (magicOn) {
                LiveBeautyAdjustments.smoothFromStrength(magicStrength)
            } else {
                LiveBeautyAdjustments.DEFAULT_SMOOTH
            },
        )
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
