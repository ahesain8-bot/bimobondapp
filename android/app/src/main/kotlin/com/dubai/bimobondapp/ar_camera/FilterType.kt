package com.dubai.bimobondapp.ar_camera

enum class FilterType {
    NONE,
    SUNGLASSES,
    EMOJI,
    MOUSTACHE,
    BIG_EYES,
    BIG_LIPS,
    LONG_NOSE,
    WHITENING,
    WARM,
    MONO,
    COOL,
    VINTAGE,
    ROSY,
    CLARENDON,
    VALENCIA,
    LUDWIG;

    fun isDistortion(): Boolean =
        this == BIG_EYES || this == BIG_LIPS || this == LONG_NOSE

    fun isPngOverlay(): Boolean =
        this == SUNGLASSES || this == EMOJI || this == MOUSTACHE

    fun isColorGrade(): Boolean =
        this == WHITENING || this == WARM || this == MONO ||
            this == COOL || this == VINTAGE || this == ROSY ||
            this == CLARENDON || this == VALENCIA || this == LUDWIG

    /** Beauty grades that benefit from face-aware skin smoothing / lip tint. */
    fun isBeauty(): Boolean =
        this == WHITENING || this == ROSY || this == LUDWIG

    fun useShader(): Boolean = isDistortion() || isColorGrade()

    companion object {
        fun fromId(name: String): FilterType = when (name.lowercase()) {
            "glasses" -> SUNGLASSES
            "emoji", "dog" -> EMOJI
            "moustache", "mustache" -> MOUSTACHE
            "big_eyes" -> BIG_EYES
            "big_lips" -> BIG_LIPS
            "long_nose" -> LONG_NOSE
            "whitening" -> WHITENING
            "warm" -> WARM
            "mono" -> MONO
            "cool" -> COOL
            "vintage" -> VINTAGE
            "rosy" -> ROSY
            "clarendon" -> CLARENDON
            "valencia" -> VALENCIA
            "ludwig" -> LUDWIG
            else -> NONE
        }
    }
}
