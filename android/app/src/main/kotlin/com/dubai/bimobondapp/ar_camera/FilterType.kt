package com.dubai.bimobondapp.ar_camera

enum class FilterType {
    NONE,
    SUNGLASSES,
    SHADES,
    EMOJI,
    MOUSTACHE,
    MASK,
    BIG_EYES,
    BIG_LIPS,
    LONG_NOSE,

    /**
     * Any full-screen Lottie overlay — not face-anchored, needs no face
     * detection.
     *
     * Deliberately ONE value rather than one per animation. These used to be
     * hardcoded (CONFETTI/KEYWORDS/SNOWFALL/SNOW_OFF_WHITE, each mapped to a
     * bundled assets/ filename), which meant publishing a new overlay required
     * an app release. They now come from `/camera-studio/ar-overlays`, so the
     * animation's identity lives on the Dart side and native is simply told
     * which file to play — see [ArCameraBridge.setFilter]'s overlay arguments
     * and [ScreenOverlaySource].
     */
    SCREEN_OVERLAY;

    fun isDistortion(): Boolean =
        this == BIG_EYES || this == BIG_LIPS || this == LONG_NOSE

    fun isPngOverlay(): Boolean =
        this == SUNGLASSES || this == SHADES || this == EMOJI || this == MOUSTACHE ||
            this == MASK

    fun isScreenOverlay(): Boolean = this == SCREEN_OVERLAY

    fun useShader(): Boolean = isDistortion()

    companion object {
        /**
         * Maps a Dart filter id to a native type. Screen overlays are NOT
         * resolved here — their ids are backend-defined and unknown to this
         * layer; [ArCameraBridge.setFilter] classifies them by the presence of
         * an overlay source instead.
         */
        fun fromId(name: String): FilterType = when (name.lowercase()) {
            "glasses" -> SUNGLASSES
            "shades", "aviator" -> SHADES
            "emoji", "dog" -> EMOJI
            "moustache", "mustache" -> MOUSTACHE
            "mask", "skull_mask" -> MASK
            "big_eyes" -> BIG_EYES
            "big_lips" -> BIG_LIPS
            "long_nose" -> LONG_NOSE
            else -> NONE
        }
    }
}

/**
 * Where a screen overlay's animation comes from. Exactly one of [url] /
 * [assetName] is set: [url] for anything published from the dashboard,
 * [assetName] for the four animations bundled in the APK, which the Dart
 * catalog falls back to when the overlays endpoint is unreachable.
 */
data class ScreenOverlaySource(
    val id: String,
    val url: String? = null,
    val assetName: String? = null,
    val loop: Boolean = true,
) {
    /** Identity for "is the view already showing this animation?" checks. */
    val cacheKey: String get() = url ?: assetName ?: id

    val isValid: Boolean get() = !url.isNullOrBlank() || !assetName.isNullOrBlank()
}
