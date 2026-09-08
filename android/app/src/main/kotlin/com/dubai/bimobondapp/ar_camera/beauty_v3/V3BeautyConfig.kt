package com.dubai.bimobondapp.ar_camera.beauty_v3

import com.dubai.bimobondapp.ar_camera.LiveBeautyAdjustments
import kotlin.math.abs

/**
 * Resolves V3 pass strengths from authoritative [V3BeautyState].
 *
 * Call [V3BeautyCompat.syncFromLegacy] before reading when DTOs may have changed.
 */
object V3BeautyConfig {
    /** Mild TikTok-like reshape when Magic is On and morph sliders are at 0. */
    private const val MAGIC_DEFAULT_EYES = 0.30f
    private const val MAGIC_DEFAULT_NOSE = 0.22f
    private const val MAGIC_DEFAULT_SHAPE = 0.28f

    private fun s(): V3BeautySnapshot = V3BeautyState.snapshot

    fun skinSmooth(): Float {
        val snap = s()
        if (snap.magicOn) {
            return LiveBeautyAdjustments.smoothFromStrength(snap.magicStrength)
        }
        return snap.smooth.coerceIn(0f, 1f)
    }

    fun skinTone(): Float {
        val snap = s()
        val base = if (snap.magicOn) {
            LiveBeautyAdjustments.MAGIC_DEFAULT_WHITEN + snap.magicStrength * 0.22f
        } else {
            snap.whiten * 0.85f + snap.brighten * 0.35f
        }
        return base.coerceIn(0f, 1f)
    }

    fun brighten(): Float {
        val snap = s()
        return if (snap.magicOn) {
            (0.18f + snap.magicStrength * 0.28f).coerceIn(0f, 1f)
        } else {
            snap.brighten.coerceIn(0f, 1f)
        }
    }

    fun underEye(): Float {
        val snap = s()
        return if (snap.underEye > 0.01f) {
            snap.underEye.coerceIn(0f, 1f)
        } else if (snap.magicOn) {
            (0.35f + snap.magicStrength * 0.25f).coerceIn(0f, 1f)
        } else {
            0f
        }
    }

    fun sharpen(): Float =
        if (s().magicOn) LiveBeautyAdjustments.MAGIC_DEFAULT_SHARPEN else 0f

    fun eyes(): Float {
        val v = s().eyes
        if (abs(v) > 0.01f) return v.coerceIn(-1.5f, 1.5f)
        return if (s().magicOn) MAGIC_DEFAULT_EYES else 0f
    }

    fun nose(): Float {
        val v = s().nose
        if (abs(v) > 0.01f) return v.coerceIn(-1.5f, 1.5f)
        return if (s().magicOn) MAGIC_DEFAULT_NOSE else 0f
    }

    fun shape(): Float {
        val v = s().shape
        if (abs(v) > 0.01f) return v.coerceIn(-1.5f, 1.5f)
        return if (s().magicOn) MAGIC_DEFAULT_SHAPE else 0f
    }

    fun lipOverallFullness(): Float = s().mouth.coerceIn(-1.5f, 1.5f)
    fun lipUpperFullness(): Float = s().upperLip.coerceIn(-1.5f, 1.5f)
    fun lipLowerFullness(): Float = s().lowerLip.coerceIn(-1.5f, 1.5f)

    fun lipFullnessActive(): Boolean =
        abs(lipOverallFullness()) > 0.01f ||
            abs(lipUpperFullness()) > 0.01f ||
            abs(lipLowerFullness()) > 0.01f

    fun contrast(): Float = s().contrast.coerceIn(-1.5f, 1.5f)
    fun saturation(): Float = s().saturation.coerceIn(-1.5f, 1.5f)
    fun brightnessGrade(): Float = s().brightness.coerceIn(-1.5f, 1.5f)
    fun exposure(): Float = s().exposure.coerceIn(-1.5f, 1.5f)
    fun warmth(): Float = s().whiteBalance.coerceIn(-1.5f, 1.5f)
    fun highlights(): Float = s().highlights.coerceIn(-1.5f, 1.5f)
    fun shadows(): Float = s().shadows.coerceIn(-1.5f, 1.5f)

    fun gradeActive(): Boolean {
        val a = s()
        return abs(a.contrast) > 0.01f ||
            abs(a.saturation) > 0.01f ||
            abs(a.brightness) > 0.01f ||
            abs(a.exposure) > 0.01f ||
            abs(a.whiteBalance) > 0.01f ||
            abs(a.highlights) > 0.01f ||
            abs(a.shadows) > 0.01f
    }

    fun brightenEye(): Float = s().brightenEye.coerceIn(0f, 1f)
    fun makeupUnderEye(): Float = s().underEye.coerceIn(0f, 1f)

    fun eyeLocalActive(): Boolean =
        brightenEye() > 0.01f || makeupUnderEye() > 0.01f

    fun lipstick(): Float = s().lipstick.coerceIn(0f, 1f)
    fun foundation(): Float = s().foundation.coerceIn(0f, 1f)
    fun contour(): Float = s().contour.coerceIn(0f, 1f)
    fun blush(): Float = s().blush.coerceIn(0f, 1f)

    fun lipTintColor(): FloatArray {
        val a = s()
        return floatArrayOf(a.lipTintR, a.lipTintG, a.lipTintB)
    }

    fun blushColor(): FloatArray {
        val a = s()
        return floatArrayOf(a.blushR, a.blushG, a.blushB)
    }

    /** Selected foundation shade (UI preset RGB). */
    fun foundationColor(): FloatArray {
        val a = s()
        return floatArrayOf(a.foundationR, a.foundationG, a.foundationB)
    }

    fun makeupActive(): Boolean =
        lipstick() > 0.01f ||
            foundation() > 0.01f ||
            contour() > 0.01f ||
            blush() > 0.01f

    fun colorMakeupActive(): Boolean =
        gradeActive() || eyeLocalActive() || makeupActive()

    fun beautyActive(): Boolean =
        skinSmooth() > 0.01f ||
            skinTone() > 0.01f ||
            brighten() > 0.01f ||
            underEye() > 0.01f

    fun reshapeActive(): Boolean =
        abs(eyes()) > 0.01f ||
            abs(nose()) > 0.01f ||
            abs(shape()) > 0.01f ||
            lipFullnessActive()

    fun anyActive(): Boolean =
        beautyActive() || reshapeActive() || colorMakeupActive()
}
