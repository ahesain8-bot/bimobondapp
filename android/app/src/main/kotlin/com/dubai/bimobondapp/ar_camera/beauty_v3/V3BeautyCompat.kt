package com.dubai.bimobondapp.ar_camera.beauty_v3

import com.dubai.bimobondapp.ar_camera.LiveBeautyState
import com.dubai.bimobondapp.ar_camera.LiveRetouchState

/**
 * Compatibility adapter: legacy Flutter MethodChannel DTOs → [V3BeautyState].
 *
 * UI field names (mouth, shape, eyes, tooth, whiten, …) stay unchanged on the
 * Flutter side. This layer is the only place that interprets them for V3.
 *
 * Unsupported UI controls are still stored on the snapshot for future V3
 * ownership but do **not** drive a legacy renderer.
 */
object V3BeautyCompat {
    /**
     * UI controls accepted by Flutter that currently have **no** production V3
     * render implementation (values are stored, not painted).
     */
    val unsupportedUiControls: List<String> = listOf(
        "eyeliner",
        "eyeshadow",
        "tooth", // Face tooth slider; V3 has debug-only teeth whiten
        "blemish", // Magic-internal in legacy; no dedicated V3 pass
    )

    /** Pull latest legacy DTO values into the authoritative V3 snapshot. */
    @JvmStatic
    fun syncFromLegacy() {
        val b = LiveBeautyState.adjustments
        val r = LiveRetouchState.adjustments
        val lip = b.lipTintColor
        val blush = b.blushColor
        val foundation = b.foundationColor
        V3BeautyState.replace(
            V3BeautySnapshot(
                magicOn = LiveBeautyState.magicOn,
                magicStrength = LiveBeautyState.magicStrength,
                smooth = b.smooth,
                whiten = b.whiten,
                brighten = b.brighten,
                underEye = b.underEye,
                brightenEye = b.brightenEye,
                lipstick = b.lipStrength,
                lipTintR = lip.getOrElse(0) { 0.86f },
                lipTintG = lip.getOrElse(1) { 0.28f },
                lipTintB = lip.getOrElse(2) { 0.38f },
                foundation = b.foundation,
                foundationR = foundation.getOrElse(0) { 0.851f },
                foundationG = foundation.getOrElse(1) { 0.753f },
                foundationB = foundation.getOrElse(2) { 0.647f },
                contour = b.contour,
                blush = b.blush,
                blushR = blush.getOrElse(0) { 0.95f },
                blushG = blush.getOrElse(1) { 0.48f },
                blushB = blush.getOrElse(2) { 0.52f },
                eyeliner = b.eyeliner,
                eyeshadow = b.eyeshadow,
                saturation = r.saturation,
                brightness = r.brightness,
                contrast = r.contrast,
                exposure = r.exposure,
                whiteBalance = r.whiteBalance,
                highlights = r.highlights,
                shadows = r.shadows,
                eyes = r.eyes,
                nose = r.nose,
                shape = r.shape,
                mouth = r.mouth,
                upperLip = r.upperLip,
                lowerLip = r.lowerLip,
                tooth = r.tooth,
            ),
        )
    }
}
