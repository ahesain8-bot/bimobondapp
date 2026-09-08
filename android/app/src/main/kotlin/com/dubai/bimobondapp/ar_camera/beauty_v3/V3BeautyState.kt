package com.dubai.bimobondapp.ar_camera.beauty_v3

/**
 * Authoritative production beauty values for the V3 pipeline.
 *
 * Flutter UI / MethodChannel still write legacy [com.dubai.bimobondapp.ar_camera.LiveBeautyState]
 * / [com.dubai.bimobondapp.ar_camera.LiveRetouchState] DTOs; [V3BeautyCompat] syncs them here.
 * Only this state (via [V3BeautyConfig]) drives live GL beauty rendering.
 */
data class V3BeautySnapshot(
    // Magic / skin
    val magicOn: Boolean = false,
    val magicStrength: Float = 0.5f,
    val smooth: Float = 0f,
    val whiten: Float = 0f,
    val brighten: Float = 0f,
    // Local
    val underEye: Float = 0f,
    val brightenEye: Float = 0f,
    // Makeup (supported)
    val lipstick: Float = 0f,
    val lipTintR: Float = 0.86f,
    val lipTintG: Float = 0.28f,
    val lipTintB: Float = 0.38f,
    val foundation: Float = 0f,
    /** Selected foundation shade RGB (0…1). Stable UI preset — not sampled per frame. */
    val foundationR: Float = 0.851f,
    val foundationG: Float = 0.753f,
    val foundationB: Float = 0.647f,
    val contour: Float = 0f,
    val blush: Float = 0f,
    val blushR: Float = 0.95f,
    val blushG: Float = 0.48f,
    val blushB: Float = 0.52f,
    // Makeup (UI-exposed, V3 render not yet owned)
    val eyeliner: Float = 0f,
    val eyeshadow: Float = 0f,
    // Global grade (−1.5…1.5)
    val saturation: Float = 0f,
    val brightness: Float = 0f,
    val contrast: Float = 0f,
    val exposure: Float = 0f,
    val whiteBalance: Float = 0f,
    val highlights: Float = 0f,
    val shadows: Float = 0f,
    // Reshape (−1.5…1.5)
    val eyes: Float = 0f,
    val nose: Float = 0f,
    val shape: Float = 0f,
    val mouth: Float = 0f,
    val upperLip: Float = 0f,
    val lowerLip: Float = 0f,
    // Teeth (UI-exposed; production V3 whitening not owned yet)
    val tooth: Float = 0f,
)

object V3BeautyState {
    @Volatile
    var snapshot: V3BeautySnapshot = V3BeautySnapshot()
        private set

    fun replace(next: V3BeautySnapshot) {
        snapshot = next
    }

    fun clear() {
        snapshot = V3BeautySnapshot()
    }
}
