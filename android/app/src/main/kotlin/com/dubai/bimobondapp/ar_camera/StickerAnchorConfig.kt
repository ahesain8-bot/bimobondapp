package com.dubai.bimobondapp.ar_camera

import com.dubai.bimobondapp.R

enum class StickerPinX {

    REF_MIDPOINT,

    ANCHOR,

    NOSE_BRIDGE,

    MOUTH_MIDPOINT,

    EYE_MIDPOINT,
}

enum class StickerPinY {

    ANCHOR,

    REF_MIDLINE,

    EYE_LINE,

    NOSE_MOUTH_BLEND,

    TOP_HEAD_OFFSET,
}

data class StickerAnchorConfig(
    val id: String,
    val drawableRes: Int,

    val leftLandmark: Int,

    val rightLandmark: Int,

    val anchorLandmark: Int,

    val secondaryAnchorLandmark: Int = -1,

    val secondaryBlendY: Float = 0f,

    val offsetYFaceFrac: Float = 0f,

    val offsetXFaceFrac: Float = 0f,

    val widthOverRef: Float = 2.4f,

    val maxFaceWidthFrac: Float = 0f,

    val minFaceWidthFrac: Float = 0f,

    val pivotU: Float = 0.5f,
    val pivotV: Float = 0.5f,

    val rotationOffsetDeg: Float = 0f,

    val yawSqueeze: Float = 0.25f,

    val scaleFromFaceBox: Boolean = false,

    val heightSpanFrac: Float = 0f,
    val heightAnchorTopLandmark: Int = -1,
    val heightAnchorBottomLandmark: Int = -1,

    val pinX: StickerPinX = StickerPinX.REF_MIDPOINT,

    val pinY: StickerPinY = StickerPinY.ANCHOR,

    val useAveragedEyes: Boolean = false,

    val widthScreenMult: Float = 0f,

    val widthFaceFrac: Float = 0f,

    val widthMinFaceFrac: Float = 0f,
)

object StickerCatalog {

    val glasses = StickerAnchorConfig(
        id = "glasses",
        drawableRes = R.drawable.glasses_round,
        leftLandmark = 33,
        rightLandmark = 263,
        anchorLandmark = MediaPipeLandmarkIndices.NOSE_BRIDGE,
        useAveragedEyes = true,
        pinX = StickerPinX.NOSE_BRIDGE,
        pinY = StickerPinY.EYE_LINE,
        widthScreenMult = 3.5f,
        widthMinFaceFrac = 0.70f,
        pivotU = 0.5f,
        pivotV = 0.5f,
        yawSqueeze = 0f,
    )

    val shades = StickerAnchorConfig(
        id = "shades",
        drawableRes = R.drawable.glasses_aviator,
        leftLandmark = 33,
        rightLandmark = 263,
        anchorLandmark = MediaPipeLandmarkIndices.NOSE_BRIDGE,
        useAveragedEyes = true,
        pinX = StickerPinX.NOSE_BRIDGE,
        pinY = StickerPinY.EYE_LINE,
        widthScreenMult = 3.5f,
        widthMinFaceFrac = 0.70f,
        pivotU = 0.5f,
        pivotV = 0.48f,
        yawSqueeze = 0f,
    )

    val moustache = StickerAnchorConfig(
        id = "moustache",
        drawableRes = R.drawable.filter_moustache,
        leftLandmark = MediaPipeLandmarkIndices.MOUTH_LEFT,
        rightLandmark = MediaPipeLandmarkIndices.MOUTH_RIGHT,
        anchorLandmark = MediaPipeLandmarkIndices.NOSE_TIP,
        pinX = StickerPinX.REF_MIDPOINT,
        pinY = StickerPinY.NOSE_MOUTH_BLEND,
        widthScreenMult = 1.9f,
        widthMinFaceFrac = 0.48f,
        pivotU = 0.5f,
        pivotV = 0.45f,
        yawSqueeze = 0f,
    )

    val mask = StickerAnchorConfig(
        id = "mask",
        drawableRes = R.drawable.filter_skull_mask,
        leftLandmark = MediaPipeLandmarkIndices.LEFT_CHEEK,
        rightLandmark = MediaPipeLandmarkIndices.RIGHT_CHEEK,
        anchorLandmark = MediaPipeLandmarkIndices.NOSE_TIP,
        offsetYFaceFrac = 0.02f,
        pinX = StickerPinX.REF_MIDPOINT,
        pinY = StickerPinY.ANCHOR,
        widthScreenMult = 1.40f,
        widthMinFaceFrac = 1.05f,
        pivotU = 0.50f,
        pivotV = 0.30f,
        yawSqueeze = 0f,
        scaleFromFaceBox = true,
        heightSpanFrac = 0.42f,
        heightAnchorTopLandmark = MediaPipeLandmarkIndices.NOSE_TIP,
        heightAnchorBottomLandmark = MediaPipeLandmarkIndices.CHIN,
    )

    val dogEars = StickerAnchorConfig(
        id = "dog_ears",
        drawableRes = R.drawable.filter_ears,
        leftLandmark = 33,
        rightLandmark = 263,
        anchorLandmark = MediaPipeLandmarkIndices.FOREHEAD,
        useAveragedEyes = true,
        pinX = StickerPinX.EYE_MIDPOINT,
        pinY = StickerPinY.TOP_HEAD_OFFSET,
        offsetYFaceFrac = -0.18f,
        widthFaceFrac = 1.05f,
        pivotU = 0.5f,
        pivotV = 0.75f,
        yawSqueeze = 0.18f,
    )

    val dogNose = StickerAnchorConfig(
        id = "dog_nose",
        drawableRes = R.drawable.filter_nose,
        leftLandmark = 33,
        rightLandmark = 263,
        anchorLandmark = MediaPipeLandmarkIndices.NOSE_TIP,
        useAveragedEyes = true,
        pinX = StickerPinX.ANCHOR,
        pinY = StickerPinY.ANCHOR,
        widthScreenMult = 1.1f,

        pivotU = 0.305f,
        pivotV = 0.154f,
        yawSqueeze = 0.15f,
    )

    val dogTongue = StickerAnchorConfig(
        id = "dog_tongue",
        drawableRes = R.drawable.filter_tongue,
        leftLandmark = MediaPipeLandmarkIndices.MOUTH_LEFT,
        rightLandmark = MediaPipeLandmarkIndices.MOUTH_RIGHT,
        anchorLandmark = MediaPipeLandmarkIndices.MOUTH_BOTTOM,
        useAveragedEyes = true,
        pinX = StickerPinX.MOUTH_MIDPOINT,
        pinY = StickerPinY.ANCHOR,
        offsetYFaceFrac = 0.04f,
        widthScreenMult = 1.25f,

        pivotU = 0.333f,
        pivotV = 0.0f,
        yawSqueeze = 0.12f,
    )

    fun configsFor(filter: FilterType): List<StickerAnchorConfig> = when (filter) {
        FilterType.SUNGLASSES -> listOf(glasses)
        FilterType.SHADES -> listOf(shades)
        FilterType.MOUSTACHE -> listOf(moustache)
        FilterType.MASK -> listOf(mask)
        FilterType.EMOJI -> listOf(dogEars, dogNose, dogTongue)
        else -> emptyList()
    }
}
