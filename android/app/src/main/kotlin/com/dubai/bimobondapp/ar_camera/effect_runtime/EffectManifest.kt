package com.dubai.bimobondapp.ar_camera.effect_runtime

/**
 * Root document stored as effect.json inside an effect package.
 *
 * The graph structure is deliberate: future operators such as beauty,
 * face_reshape, lip_makeup, LUT, 3D and particles can be added without changing
 * the package lifecycle or creating one FilterType per filter.
 */
data class EffectManifest(
    val schemaVersion: String,
    val effectId: String,
    val effectVersion: String,
    val minimumEngineVersion: String,
    val displayName: String?,
    val maxFaces: Int,
    val graph: EffectGraphDefinition,
)

data class EffectGraphDefinition(
    val nodes: List<EffectNodeDefinition>,
)

sealed interface EffectNodeDefinition {
    val id: String
    val type: String
    val enabled: Boolean
    val faceTarget: EffectFaceTarget
}

data class Sticker2DNodeDefinition(
    override val id: String,
    override val enabled: Boolean,
    override val faceTarget: EffectFaceTarget,
    val asset: String,
    val opacity: Float,
    val zIndex: Int,
    val blendMode: EffectBlendMode,
    val anchor: StickerAnchorDefinition,
    val transform: StickerTransformDefinition,
) : EffectNodeDefinition {
    override val type: String = EffectContract.NODE_STICKER_2D
}

data class StickerAnchorDefinition(
    val leftLandmark: Int,
    val rightLandmark: Int,
    val anchorLandmark: Int,
    val secondaryAnchorLandmark: Int,
    val secondaryBlendY: Float,
    val pinX: EffectStickerPinX,
    val pinY: EffectStickerPinY,
    val useAveragedEyes: Boolean,
)

data class StickerTransformDefinition(
    val offsetXFaceFrac: Float,
    val offsetYFaceFrac: Float,
    val widthScreenMult: Float,
    val widthFaceFrac: Float,
    val widthMinFaceFrac: Float,
    val maxFaceWidthFrac: Float,
    val pivotU: Float,
    val pivotV: Float,
    val rotationOffsetDeg: Float,
    val yawSqueeze: Float,
    val scaleFromFaceBox: Boolean,
    val heightSpanFrac: Float,
    val heightAnchorTopLandmark: Int,
    val heightAnchorBottomLandmark: Int,
)
