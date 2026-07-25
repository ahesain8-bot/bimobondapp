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
    CONFETTI,
    KEYWORDS,
    SNOWFALL,
    SNOW_OFF_WHITE;

    fun isDistortion(): Boolean =
        this == BIG_EYES || this == BIG_LIPS || this == LONG_NOSE

    fun isPngOverlay(): Boolean =
        this == SUNGLASSES || this == SHADES || this == EMOJI || this == MOUSTACHE ||
            this == MASK

    /** Full-screen Lottie-style overlay — not face-anchored, needs no face detection. */
    fun isScreenOverlay(): Boolean =
        this == CONFETTI || this == KEYWORDS || this == SNOWFALL || this == SNOW_OFF_WHITE

    /** assets/ filename for this screen-overlay filter's Lottie animation, or null. */
    fun screenOverlayAsset(): String? = when (this) {
        CONFETTI -> "Confetti.json"
        KEYWORDS -> "Keywords.json"
        SNOWFALL -> "snowfall.json"
        SNOW_OFF_WHITE -> "Snow Off white.json"
        else -> null
    }

    fun useShader(): Boolean = isDistortion()

    companion object {
        fun fromId(name: String): FilterType = when (name.lowercase()) {
            "glasses" -> SUNGLASSES
            "shades", "aviator" -> SHADES
            "emoji", "dog" -> EMOJI
            "moustache", "mustache" -> MOUSTACHE
            "mask", "skull_mask" -> MASK
            "big_eyes" -> BIG_EYES
            "big_lips" -> BIG_LIPS
            "long_nose" -> LONG_NOSE
            "confetti" -> CONFETTI
            "keywords" -> KEYWORDS
            "snowfall" -> SNOWFALL
            "snow_off_white" -> SNOW_OFF_WHITE
            else -> NONE
        }
    }
}
