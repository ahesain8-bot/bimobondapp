package com.dubai.bimobondapp.ar_camera

import com.dubai.bimobondapp.R

/**
 * Per-sticker bind recipe — add a new sticker by appending a config, not by
 * writing another drawX() with magic numbers.
 *
 * All landmark indices are MediaPipe Face Mesh (468).
 * [pivotU]/[pivotV] are the PNG's "pin" in 0..1 texture space (center of draw).
 */
enum class StickerPinX {
    /** Midpoint of left/right reference landmarks on screen. */
    REF_MIDPOINT,
    /** Primary [anchorLandmark] screen X. */
    ANCHOR,
    /** Nose bridge (glasses horizontal lock). */
    NOSE_BRIDGE,
    /** Mouth corner midpoint. */
    MOUTH_MIDPOINT,
    /** Averaged eye-center midpoint. */
    EYE_MIDPOINT,
}

enum class StickerPinY {
    /** Primary [anchorLandmark] screen Y (+ [offsetYFaceFrac]). */
    ANCHOR,
    /** Midline Y of left/right reference landmarks. */
    REF_MIDLINE,
    /** Averaged eye-center line Y (glasses vertical lock). */
    EYE_LINE,
    /** 40% nose tip + 60% mouth midline (moustache). */
    NOSE_MOUTH_BLEND,
    /** [topHead] Y + faceHeight * [offsetYFaceFrac] (dog ears). */
    TOP_HEAD_OFFSET,
}

data class StickerAnchorConfig(
    val id: String,
    val drawableRes: Int,
    /** Left reference landmark for scale + roll (e.g. eye outer corner). */
    val leftLandmark: Int,
    /** Right reference landmark for scale + roll. */
    val rightLandmark: Int,
    /** Primary position landmark (e.g. nose bridge). */
    val anchorLandmark: Int,
    /** Optional second mix-in for Y (e.g. mouth). -1 = unused. */
    val secondaryAnchorLandmark: Int = -1,
    /** Blend of primary/secondary for Y: 0 = primary only, 1 = secondary only. */
    val secondaryBlendY: Float = 0f,
    /** Extra offset as a fraction of face height (positive = down). */
    val offsetYFaceFrac: Float = 0f,
    /** Extra offset as a fraction of face width (positive = right in image space). */
    val offsetXFaceFrac: Float = 0f,
    /**
     * Target sticker width = refDistance * [widthOverRef].
     * refDistance = distance(leftLandmark, rightLandmark).
     */
    val widthOverRef: Float = 2.4f,
    /** Cap width as a fraction of face bounding-box width (0 = no cap). */
    val maxFaceWidthFrac: Float = 0f,
    /** Floor width as a fraction of face width (0 = no floor). */
    val minFaceWidthFrac: Float = 0f,
    /** PNG pin (0..1). */
    val pivotU: Float = 0.5f,
    val pivotV: Float = 0.5f,
    /** Extra degrees added after roll from landmarks. */
    val rotationOffsetDeg: Float = 0f,
    /** How much yaw squeezes width (0 = ignore yaw, 0.35 = mild). */
    val yawSqueeze: Float = 0.25f,
    /**
     * When true, scale uses max(landmarkSpan, faceBoxWidth) so wide faces /
     * cheeks still get full cover (mask). Glasses should leave this false.
     */
    val scaleFromFaceBox: Boolean = false,
    /**
     * If > 0, quad HEIGHT is forced so [heightAnchorTopLandmark]→
     * [heightAnchorBottomLandmark] spans this fraction of it (guarantees the
     * gaiter reaches the chin regardless of PNG aspect). 0 = use PNG aspect.
     */
    val heightSpanFrac: Float = 0f,
    val heightAnchorTopLandmark: Int = -1,
    val heightAnchorBottomLandmark: Int = -1,
    /** Screen-space horizontal pin (after mapPoint). */
    val pinX: StickerPinX = StickerPinX.REF_MIDPOINT,
    /** Screen-space vertical pin (after mapPoint). */
    val pinY: StickerPinY = StickerPinY.ANCHOR,
    /**
     * When true, left/right refs use [FaceLandmarkSnapshot.leftEye]/[rightEye]
     * (averaged iris regions) instead of single corner indices — much stabler.
     */
    val useAveragedEyes: Boolean = false,
    /**
     * Sticker width = ref screen span * this (e.g. eye distance * 3.5 for glasses).
     * Ignored when [widthFaceFrac] > 0.
     */
    val widthScreenMult: Float = 0f,
    /** Sticker width = face screen width * this (dog ears). */
    val widthFaceFrac: Float = 0f,
    /** Floor width = face screen width * this (glasses min 0.7). */
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

    /**
     * Intact skull gaiter. PNG content is ~60% of asset width, so full-quad
     * width must be sized off the FACE box, not blown up arbitrarily.
     *
     * FIX: previous widthOverRef=2.65 + no cap (maxFaceWidthFrac=0) let width
     * grow to ~2.65x face width — the mask hung far past both jaw edges and
     * its aspect got squashed against the forced height, which is what made
     * it look stretched / mirrored-duplicate at the bottom. Now bounded to a
     * sane 1.05x–1.55x range around face width.
     */
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
        // filter_nose.png is mostly transparent padding; pin the opaque nose top
        // (not bitmap geometric center) onto the detected nose tip.
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
        // filter_tongue.png has empty padding on the right; pin top-center of
        // opaque tongue onto the mouth so it hangs straight down.
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