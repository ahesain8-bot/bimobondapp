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
    val eyeliner: Float = 0f,
    val eyeshadow: Float = 0f,
    val foundation: Float = 0f,
    val contour: Float = 0f,
    val underEye: Float = 0f,
    val brightenEye: Float = 0f,
    val eyelinerColor: FloatArray = DEFAULT_LINER_COLOR,
    val eyeshadowColor: FloatArray = DEFAULT_SHADOW_COLOR,
    val blushColor: FloatArray = DEFAULT_BLUSH_COLOR,
) {
    companion object {
        /** Light cleanup only — pores/texture stay; higher values read as plastic. */
        const val DEFAULT_SMOOTH = 0.20f

        /** Near-off — room brightness comes from camera EV, with a light face open. */
        const val DEFAULT_WHITEN = 0.04f
        const val DEFAULT_BRIGHTEN = 0.14f

        /**
         * Smooth response curve midpoint. The camera UI supplies its own
         * default slider position (currently 50%); 50 remains the curve anchor.
         */
        const val MAGIC_AUTO_STRENGTH = 0.50f

        /** Internal effect strength that slider=50 produces. */
        const val MAGIC_ANCHOR_EFFECT = 0.90f

        /** Shader smooth at slider 0 / 0.5 / 1 while Magic is On. */
        const val MAGIC_SMOOTH_MIN = 0.48f
        const val MAGIC_SMOOTH_ANCHOR = 0.73f
        const val MAGIC_SMOOTH_MAX = 0.99f

        /** Camera Magic-On defaults without dedicated Flutter sliders. */
        /** ≈ TikTok Whiten 10 — keep low; lift comes from exposure/brightness. */
        const val MAGIC_DEFAULT_WHITEN = 0.10f
        /** Slightly soft (TikTok sharpness ~-2); avoid crunchy skin. */
        const val MAGIC_DEFAULT_SHARPEN = 0.03f

        /** Wide blemish pull stops growing above default to avoid blurry patches. */
        const val MAGIC_BLEMISH_MIN = 0.48f
        const val MAGIC_BLEMISH_ANCHOR = 0.93f

        val DEFAULT_LIP_COLOR = floatArrayOf(0.86f, 0.28f, 0.38f)
        val DEFAULT_BLUSH_COLOR = floatArrayOf(0.95f, 0.48f, 0.52f)
        val DEFAULT_LINER_COLOR = floatArrayOf(0.06f, 0.05f, 0.08f)
        val DEFAULT_SHADOW_COLOR = floatArrayOf(0.55f, 0.32f, 0.42f)

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
    var adjustments: LiveBeautyAdjustments = LiveBeautyAdjustments(
        // Neutral until Flutter / Magic enables beauty — stored defaults must not
        // touch pixels while the feature is Off.
        smooth = 0f,
        whiten = 0f,
        brighten = 0f,
    )

    /** Retouch panel Off/On — face smooth boost, independent of color filters. */
    @Volatile
    var magicOn: Boolean = false

    /** 0..1 Smooth slider while Magic is On (preserved while Off). */
    @Volatile
    var magicStrength: Float = LiveBeautyAdjustments.MAGIC_AUTO_STRENGTH

    fun needsLipMakeup(): Boolean = adjustments.lipStrength > 0.01f

    fun needsMouthAnchors(): Boolean =
        needsLipMakeup() || adjustments.foundation > 0.01f

    fun needsBlushMakeup(): Boolean =
        adjustments.blush > 0.01f ||
            adjustments.foundation > 0.01f ||
            adjustments.contour > 0.01f

    fun needsEyeMakeup(): Boolean =
        adjustments.eyeliner > 0.01f ||
            adjustments.eyeshadow > 0.01f ||
            adjustments.underEye > 0.01f ||
            adjustments.brightenEye > 0.01f ||
            adjustments.foundation > 0.01f ||
            adjustments.contour > 0.01f

    fun needsContourNose(): Boolean = adjustments.contour > 0.01f

    fun needsAnyMakeup(): Boolean =
        needsLipMakeup() || needsBlushMakeup() || needsEyeMakeup()

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
        eyeliner: Float = 0f,
        eyeshadow: Float = 0f,
        foundation: Float = 0f,
        contour: Float = 0f,
        underEye: Float = 0f,
        brightenEye: Float = 0f,
        blushHex: String? = null,
        eyelinerHex: String? = null,
        eyeshadowHex: String? = null,
    ) {
        val i = intensity.coerceIn(0f, 1f)
        val appliedSmooth = (smooth * i).coerceIn(0f, 1f)
        val cur = adjustments
        adjustments = LiveBeautyAdjustments(
            // Named filters may request smooth, but Magic Off must not invent
            // residual DEFAULT_SMOOTH / whiten / brighten under the hood.
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
            eyeliner = (eyeliner * i).coerceIn(0f, 1f),
            eyeshadow = (eyeshadow * i).coerceIn(0f, 1f),
            foundation = (foundation * i).coerceIn(0f, 1f),
            contour = (contour * i).coerceIn(0f, 1f),
            underEye = (underEye * i).coerceIn(0f, 1f),
            brightenEye = (brightenEye * i).coerceIn(0f, 1f),
            blushColor = blushHex?.let(::parseHexColor) ?: cur.blushColor,
            eyelinerColor = eyelinerHex?.let(::parseHexColor) ?: cur.eyelinerColor,
            eyeshadowColor = eyeshadowHex?.let(::parseHexColor) ?: cur.eyeshadowColor,
        )
    }

    /** TikTok-style makeup intensities (0…1) on the live AR beauty pipeline. */
    fun applyMakeup(
        lipstick: Float = adjustments.lipStrength,
        blush: Float = adjustments.blush,
        eyeliner: Float = adjustments.eyeliner,
        eyeshadow: Float = adjustments.eyeshadow,
        foundation: Float = adjustments.foundation,
        contour: Float = adjustments.contour,
        underEye: Float = adjustments.underEye,
        brightenEye: Float = adjustments.brightenEye,
        lipTintHex: String? = null,
        blushHex: String? = null,
        eyelinerHex: String? = null,
        eyeshadowHex: String? = null,
    ) {
        val cur = adjustments
        adjustments = cur.copy(
            lipStrength = lipstick.coerceIn(0f, 1f),
            blush = blush.coerceIn(0f, 1f),
            eyeliner = eyeliner.coerceIn(0f, 1f),
            eyeshadow = eyeshadow.coerceIn(0f, 1f),
            foundation = foundation.coerceIn(0f, 1f),
            contour = contour.coerceIn(0f, 1f),
            underEye = underEye.coerceIn(0f, 1f),
            brightenEye = brightenEye.coerceIn(0f, 1f),
            lipTintColor = lipTintHex?.let(::parseHexColor) ?: cur.lipTintColor,
            blushColor = blushHex?.let(::parseHexColor) ?: cur.blushColor,
            eyelinerColor = eyelinerHex?.let(::parseHexColor) ?: cur.eyelinerColor,
            eyeshadowColor = eyeshadowHex?.let(::parseHexColor) ?: cur.eyeshadowColor,
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
            // Keep magicStrength for the next On, but zero live smooth so Off
            // cannot leave DEFAULT_SMOOTH (0.20) modifying pixels.
            cur.copy(smooth = 0f)
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

    /**
     * True when any beauty / makeup value would change pixels. Magic Off with
     * residual stored slider values must return false for those Magic-owned
     * channels (smooth/whiten boost/sharpen) — callers pass explicit zeros.
     */
    fun needsPixelProcessing(): Boolean {
        if (magicOn) return true
        if (needsAnyMakeup()) return true
        val a = adjustments
        return a.smooth > 0.01f ||
            a.whiten > 0.01f ||
            a.brighten > 0.01f ||
            a.blush > 0.01f ||
            a.lipStrength > 0.01f ||
            a.foundation > 0.01f ||
            a.contour > 0.01f ||
            a.eyeliner > 0.01f ||
            a.eyeshadow > 0.01f ||
            a.underEye > 0.01f ||
            a.brightenEye > 0.01f
    }

    /** Back to the baseline — Magic On keeps slider smooth; Off stays pixel-neutral. */
    fun clear() {
        adjustments = LiveBeautyAdjustments(
            smooth = if (magicOn) {
                LiveBeautyAdjustments.smoothFromStrength(magicStrength)
            } else {
                0f
            },
            whiten = 0f,
            brighten = 0f,
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
