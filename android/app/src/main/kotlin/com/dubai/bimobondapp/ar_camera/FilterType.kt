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
    LONG_NOSE;

    fun isDistortion(): Boolean =
        this == BIG_EYES || this == BIG_LIPS || this == LONG_NOSE

    fun isPngOverlay(): Boolean =
        this == SUNGLASSES || this == SHADES || this == EMOJI || this == MOUSTACHE ||
            this == MASK

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
            else -> NONE
        }
    }
}
