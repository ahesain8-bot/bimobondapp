package com.dubai.bimobondapp.ar_camera.effect_runtime

/**
 * Stable wire-level constants shared by the Android engine and the future studio.
 *
 * New filters must be expressible with these contracts without adding a new
 * Kotlin enum value for every filter. New Kotlin code is only required when a
 * completely new operator type is introduced to the engine.
 */
object EffectContract {
    const val ENGINE_VERSION = "0.1.0"
    const val SCHEMA_VERSION = "0.1.0"

    const val NODE_STICKER_2D = "sticker_2d"
}

enum class EffectFaceTarget(val wireValue: String) {
    ALL("all"),
    FIRST("first"),
    SECOND("second");

    companion object {
        fun fromWire(value: String): EffectFaceTarget? =
            entries.firstOrNull { it.wireValue == value.lowercase() }
    }
}

enum class EffectBlendMode(val wireValue: String) {
    NORMAL("normal");

    companion object {
        fun fromWire(value: String): EffectBlendMode? =
            entries.firstOrNull { it.wireValue == value.lowercase() }
    }
}

enum class EffectStickerPinX(val wireValue: String) {
    REF_MIDPOINT("ref_midpoint"),
    ANCHOR("anchor"),
    NOSE_BRIDGE("nose_bridge"),
    MOUTH_MIDPOINT("mouth_midpoint"),
    EYE_MIDPOINT("eye_midpoint");

    companion object {
        fun fromWire(value: String): EffectStickerPinX? =
            entries.firstOrNull { it.wireValue == value.lowercase() }
    }
}

enum class EffectStickerPinY(val wireValue: String) {
    ANCHOR("anchor"),
    REF_MIDLINE("ref_midline"),
    EYE_LINE("eye_line"),
    NOSE_MOUTH_BLEND("nose_mouth_blend"),
    TOP_HEAD_OFFSET("top_head_offset");

    companion object {
        fun fromWire(value: String): EffectStickerPinY? =
            entries.firstOrNull { it.wireValue == value.lowercase() }
    }
}
