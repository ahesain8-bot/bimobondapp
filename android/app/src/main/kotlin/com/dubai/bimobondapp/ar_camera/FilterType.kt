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
    WHITENING,
    WARM,
    MONO,
    COOL,
    VINTAGE,
    ROSY,
    CLARENDON,
    VALENCIA,
    LUDWIG,
    CITY_FILM,
    GOING_FOR_A_WALK,
    GOOD_MORNING,
    NAH,
    ONCE_UPON_A_TIME,
    PASSING_BY,
    SERENITY,
    UNDENIABLE_2,
    UNDENIABLE,
    URBAN_COWBOY,
    YOU_CAN_DO_IT,
    SMOOTH_SAILING,
    WELL_SEE;

    fun isDistortion(): Boolean =
        this == BIG_EYES || this == BIG_LIPS || this == LONG_NOSE

    fun isPngOverlay(): Boolean =
        this == SUNGLASSES || this == SHADES || this == EMOJI || this == MOUSTACHE ||
            this == MASK

    fun isColorGrade(): Boolean =
        this == WHITENING || this == WARM || this == MONO ||
            this == COOL || this == VINTAGE || this == ROSY ||
            this == CLARENDON || this == VALENCIA || this == LUDWIG ||
            this == CITY_FILM || this == GOING_FOR_A_WALK || this == GOOD_MORNING ||
            this == NAH || this == ONCE_UPON_A_TIME || this == PASSING_BY ||
            this == SERENITY || this == UNDENIABLE_2 || this == UNDENIABLE ||
            this == URBAN_COWBOY || this == YOU_CAN_DO_IT || this == SMOOTH_SAILING ||
            this == WELL_SEE

    fun isBeauty(): Boolean =
        this == WHITENING || this == ROSY || this == LUDWIG

    fun useShader(): Boolean = isDistortion() || isColorGrade()

    fun usesGpuPreview(): Boolean = isColorGrade()

    fun lutAsset(): String? = when (this) {
        WHITENING -> "whitening.png"
        WARM -> "warm.png"
        MONO -> "mono.png"
        COOL -> "cool.png"
        VINTAGE -> "vintage.png"
        ROSY -> "rosy.png"
        CLARENDON -> "clarendon.png"
        VALENCIA -> "valencia.png"
        LUDWIG -> "ludwig.png"
        CITY_FILM -> "cityfilm.png"
        GOING_FOR_A_WALK -> "going_for_a_walk.png"
        GOOD_MORNING -> "good_morning.png"
        NAH -> "nah.png"
        ONCE_UPON_A_TIME -> "once_upon_a_time.png"
        PASSING_BY -> "passing_by.png"
        SERENITY -> "serenity.png"
        UNDENIABLE_2 -> "undeniable_2.png"
        UNDENIABLE -> "undeniable.png"
        URBAN_COWBOY -> "urban_cowboy.png"
        YOU_CAN_DO_IT -> "you_can_do_it.png"
        SMOOTH_SAILING -> "smooth_sailing.png"
        WELL_SEE -> "well_see.png"
        else -> null
    }

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
            "whitening" -> WHITENING
            "warm" -> WARM
            "mono" -> MONO
            "cool" -> COOL
            "vintage" -> VINTAGE
            "rosy" -> ROSY
            "clarendon" -> CLARENDON
            "valencia" -> VALENCIA
            "ludwig" -> LUDWIG
            "cityfilm", "city_film" -> CITY_FILM
            "going_for_a_walk" -> GOING_FOR_A_WALK
            "good_morning" -> GOOD_MORNING
            "nah" -> NAH
            "once_upon_a_time" -> ONCE_UPON_A_TIME
            "passing_by" -> PASSING_BY
            "serenity" -> SERENITY
            "undeniable_2" -> UNDENIABLE_2
            "undeniable" -> UNDENIABLE
            "urban_cowboy" -> URBAN_COWBOY
            "you_can_do_it" -> YOU_CAN_DO_IT
            "smooth_sailing" -> SMOOTH_SAILING
            "well_see" -> WELL_SEE
            else -> NONE
        }
    }
}
