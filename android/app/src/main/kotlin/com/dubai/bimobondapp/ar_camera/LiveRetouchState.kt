package com.dubai.bimobondapp.ar_camera

import android.graphics.PointF
import com.dubai.bimobondapp.beauty.BeautyFilterProcessor
import kotlin.math.roundToInt

/**
 * Live camera retouch sliders (−1…1, 0 = original). Applied in GPU preview and
 * baked into captures via the same GL pipeline.
 *
 * [liveBaseline] color grade (contrast max, saturation +10, brightness −47,
 * exposure +6, warmth −8, highlights +8, shadows +10) is for the **back
 * camera only** while Retouch/Magic is Off. Front stays neutral unless Magic
 * or a color filter pushes different values.
 */
data class LiveRetouchAdjustments(
    val saturation: Float = 0f,
    val brightness: Float = 0f,
    val contrast: Float = 0f,
    val exposure: Float = 0f,
    val whiteBalance: Float = 0f,
    val highlights: Float = 0f,
    val shadows: Float = 0f,
    /** Nose width: −1 expand, 0 natural, +1 slim. */
    val nose: Float = 0f,
    /** Jaw shape: −1 expand, 0 natural, +1 slim. */
    val shape: Float = 0f,
    /** Eye open/size: −1 smaller/closed, 0 natural, +1 more open & larger eyeball. */
    val eyes: Float = 0f,
    /** Teeth tone: −1 dull, 0 natural, +1 whiter. */
    val tooth: Float = 0f,
    /** Lip thickness: −1 thinner, 0 natural, +1 thicker. */
    val mouth: Float = 0f,
) {
    val hasColor: Boolean
        get() = kotlin.math.abs(saturation) > 0.01f ||
            kotlin.math.abs(brightness) > 0.01f ||
            kotlin.math.abs(contrast) > 0.01f ||
            kotlin.math.abs(exposure) > 0.01f ||
            kotlin.math.abs(whiteBalance) > 0.01f ||
            kotlin.math.abs(highlights) > 0.01f ||
            kotlin.math.abs(shadows) > 0.01f

    val isNoop: Boolean
        get() = !hasColor &&
            kotlin.math.abs(nose) < 0.01f &&
            kotlin.math.abs(shape) < 0.01f &&
            kotlin.math.abs(eyes) < 0.01f &&
            kotlin.math.abs(tooth) < 0.01f &&
            kotlin.math.abs(mouth) < 0.01f

    /** True when color channels match the back-camera Retouch-Off baseline. */
    fun matchesLiveBaselineColors(): Boolean {
        fun near(a: Float, b: Float) = kotlin.math.abs(a - b) < 0.005f
        return near(saturation, DEFAULT_SATURATION) &&
            near(brightness, DEFAULT_BRIGHTNESS) &&
            near(contrast, DEFAULT_CONTRAST) &&
            near(exposure, DEFAULT_EXPOSURE) &&
            near(whiteBalance, DEFAULT_WHITE_BALANCE) &&
            near(highlights, DEFAULT_HIGHLIGHTS) &&
            near(shadows, DEFAULT_SHADOWS)
    }

    fun toProcessorAdjustments(): BeautyFilterProcessor.Adjustments {
        fun level(v: Float) = (v * 100f).roundToInt().coerceIn(-100, 100)
        return BeautyFilterProcessor.Adjustments(
            saturation = level(saturation),
            brightness = level(brightness),
            contrast = level(contrast),
            exposure = level(exposure),
            whiteBalance = level(whiteBalance),
            highlights = level(highlights),
            shadows = level(shadows),
            nose = level(nose),
        )
    }

    companion object {
        /** Face slider labels (value×100) → back-camera Retouch-Off baseline. */
        const val DEFAULT_SATURATION = 0.10f
        const val DEFAULT_BRIGHTNESS = -0.47f
        const val DEFAULT_CONTRAST = 1.0f
        const val DEFAULT_EXPOSURE = 0.06f
        const val DEFAULT_WHITE_BALANCE = -0.08f
        const val DEFAULT_HIGHLIGHTS = 0.08f
        const val DEFAULT_SHADOWS = 0.10f

        fun neutral(): LiveRetouchAdjustments = LiveRetouchAdjustments()

        /** Color grade only — morphs (nose/shape/eyes/…) stay at 0. */
        fun liveBaseline(): LiveRetouchAdjustments = LiveRetouchAdjustments(
            saturation = DEFAULT_SATURATION,
            brightness = DEFAULT_BRIGHTNESS,
            contrast = DEFAULT_CONTRAST,
            exposure = DEFAULT_EXPOSURE,
            whiteBalance = DEFAULT_WHITE_BALANCE,
            highlights = DEFAULT_HIGHLIGHTS,
            shadows = DEFAULT_SHADOWS,
        )

        fun fromLevels(
            saturation: Int = 0,
            brightness: Int = 0,
            contrast: Int = 0,
            exposure: Int = 0,
            whiteBalance: Int = 0,
            highlights: Int = 0,
            shadows: Int = 0,
            nose: Int = 0,
            shape: Int = 0,
            eyes: Int = 0,
            tooth: Int = 0,
            mouth: Int = 0,
        ): LiveRetouchAdjustments = LiveRetouchAdjustments(
            saturation = saturation / 100f,
            brightness = brightness / 100f,
            contrast = contrast / 100f,
            exposure = exposure / 100f,
            whiteBalance = whiteBalance / 100f,
            highlights = highlights / 100f,
            shadows = shadows / 100f,
            nose = nose / 100f,
            shape = shape / 100f,
            eyes = eyes / 100f,
            tooth = tooth / 100f,
            mouth = mouth / 100f,
        )
    }
}

object LiveRetouchState {
    @Volatile
    var adjustments: LiveRetouchAdjustments = LiveRetouchAdjustments()

    /** Nose liquify wings in texture UV (0…1), updated from face landmarks. */
    @Volatile
    var noseWingL: FloatArray = floatArrayOf(0f, 0f)

    @Volatile
    var noseWingR: FloatArray = floatArrayOf(0f, 0f)

    @Volatile
    var noseRadius: Float = 0f

    /** Jaw liquify centers in texture UV (0…1). */
    @Volatile
    var jawWingL: FloatArray = floatArrayOf(0f, 0f)

    @Volatile
    var jawWingR: FloatArray = floatArrayOf(0f, 0f)

    @Volatile
    var jawRadius: Float = 0f

    /** Eye centers in texture UV (0…1). */
    @Volatile
    var eyeL: FloatArray = floatArrayOf(0f, 0f)

    @Volatile
    var eyeR: FloatArray = floatArrayOf(0f, 0f)

    @Volatile
    var eyeRadius: Float = 0f

    /** Mouth center in texture UV (0…1). */
    @Volatile
    var mouthCenter: FloatArray = floatArrayOf(0f, 0f)

    /** Mouth half-width in UV; height is derived in the shader. */
    @Volatile
    var mouthRadius: Float = 0f

    /** 0 when lips are closed, 1 when the mouth opening clearly exposes teeth. */
    @Volatile
    var toothVisibility: Float = 0f

    /**
     * Inner-mouth opening as (centerX, centerY, halfWidth, halfHeight) in UV.
     * X and Y are normalised by their own axis — reusing an X-derived radius for
     * the vertical extent made the band tall enough to cover both lips.
     */
    @Volatile
    var toothRegion: FloatArray = floatArrayOf(0f, 0f, 0f, 0f)

    fun clear() {
        // Back camera keeps Retouch-Off color baseline; front stays neutral.
        adjustments = if (ArCameraBridge.isFrontCamera) {
            LiveRetouchAdjustments.neutral()
        } else {
            LiveRetouchAdjustments.liveBaseline()
        }
        noseWingL = floatArrayOf(0f, 0f)
        noseWingR = floatArrayOf(0f, 0f)
        noseRadius = 0f
        jawWingL = floatArrayOf(0f, 0f)
        jawWingR = floatArrayOf(0f, 0f)
        jawRadius = 0f
        eyeL = floatArrayOf(0f, 0f)
        eyeR = floatArrayOf(0f, 0f)
        eyeRadius = 0f
        mouthCenter = floatArrayOf(0f, 0f)
        mouthRadius = 0f
        toothVisibility = 0f
        toothRegion = floatArrayOf(0f, 0f, 0f, 0f)
    }

    /** Maps nose alar wings for live slim/expand (−1 expand, +1 slim). */
    fun updateNoseLandmarks(
        snapshot: FaceLandmarkSnapshot?,
        imageWidth: Int,
        imageHeight: Int,
    ) {
        if (kotlin.math.abs(adjustments.nose) < 0.01f || snapshot == null ||
            imageWidth <= 0 || imageHeight <= 0
        ) {
            noseRadius = 0f
            return
        }
        var leftWing: PointF? = null
        var rightWing: PointF? = null
        for (idx in MediaPipeLandmarkIndices.NOSE_WING_ZONE) {
            val p = snapshot.landmarks.getOrNull(idx) ?: continue
            if (leftWing == null || p.x < leftWing!!.x) leftWing = p
            if (rightWing == null || p.x > rightWing!!.x) rightWing = p
        }
        val lw = leftWing ?: run {
            noseRadius = 0f
            return
        }
        val rw = rightWing ?: run {
            noseRadius = 0f
            return
        }
        // Keep wings on the nose tip band so they can't drift to eyes/mouth.
        val tip = snapshot.landmarks.getOrNull(MediaPipeLandmarkIndices.NOSE_TIP)
        val bridge = snapshot.landmarks.getOrNull(MediaPipeLandmarkIndices.NOSE_BRIDGE)
        val tipY = tip?.y ?: ((lw.y + rw.y) * 0.5f)
        val bridgeY = bridge?.y ?: (tipY - (rw.x - lw.x) * 0.35f)
        val bandTop = minOf(bridgeY, tipY)
        val bandBot = maxOf(tipY + (tipY - bandTop) * 0.35f, tipY)
        val left = PointF(lw.x, lw.y.coerceIn(bandTop, bandBot))
        val right = PointF(rw.x, rw.y.coerceIn(bandTop, bandBot))
        val front = ArCameraBridge.isFrontCamera
        noseWingL = FaceCoordinateMapper.toWarpUv(
            left.x, left.y, imageWidth, imageHeight, isFrontCamera = front,
        )
        noseWingR = FaceCoordinateMapper.toWarpUv(
            right.x, right.y, imageWidth, imageHeight, isFrontCamera = front,
        )
        val noseWidth = (right.x - left.x).coerceAtLeast(1f)
        noseRadius = FaceCoordinateMapper.toWarpRadiusX(noseWidth * 0.72f, imageWidth)
    }

    /**
     * Shape: left/right cheek pads only (−1 expand, +1 slim). Centers sit on
     * the cheek apples so nose and lips are not pulled with the sides.
     */
    fun updateJawLandmarks(
        snapshot: FaceLandmarkSnapshot?,
        imageWidth: Int,
        imageHeight: Int,
    ) {
        if (kotlin.math.abs(adjustments.shape) < 0.01f || snapshot == null ||
            imageWidth <= 0 || imageHeight <= 0
        ) {
            jawRadius = 0f
            return
        }
        val leftCheek = snapshot.landmarks.getOrNull(MediaPipeLandmarkIndices.LEFT_CHEEK)
            ?: averageZone(snapshot, MediaPipeLandmarkIndices.LEFT_JAW_ZONE)
            ?: snapshot.landmarks.getOrNull(172)
        val rightCheek = snapshot.landmarks.getOrNull(MediaPipeLandmarkIndices.RIGHT_CHEEK)
            ?: averageZone(snapshot, MediaPipeLandmarkIndices.RIGHT_JAW_ZONE)
            ?: snapshot.landmarks.getOrNull(397)
        if (leftCheek == null || rightCheek == null) {
            jawRadius = 0f
            return
        }
        // Bias slightly toward the jaw so the pad covers cheek → lower cheek,
        // without sliding onto the nose bridge / mouth.
        val chin = snapshot.landmarks.getOrNull(MediaPipeLandmarkIndices.CHIN)
        val chinY = chin?.y ?: (maxOf(leftCheek.y, rightCheek.y) + imageHeight * 0.08f)
        val cheekY = (leftCheek.y + rightCheek.y) * 0.5f
        val targetY = cheekY * 0.65f + chinY * 0.35f
        val left = PointF(leftCheek.x, targetY)
        val right = PointF(rightCheek.x, targetY)
        val front = ArCameraBridge.isFrontCamera
        jawWingL = FaceCoordinateMapper.toWarpUv(
            left.x, left.y, imageWidth, imageHeight, isFrontCamera = front,
        )
        jawWingR = FaceCoordinateMapper.toWarpUv(
            right.x, right.y, imageWidth, imageHeight, isFrontCamera = front,
        )
        val faceWidth = (right.x - left.x).coerceAtLeast(1f)
        // Soft cheek pad — slightly wider so the fade is gentle (no stamp).
        jawRadius = FaceCoordinateMapper.toWarpRadiusX(faceWidth * 0.24f, imageWidth)
    }

    /** Eye centers for lid open/close (−1 closed, +1 open). */
    fun updateEyeLandmarks(
        snapshot: FaceLandmarkSnapshot?,
        imageWidth: Int,
        imageHeight: Int,
    ) {
        if (kotlin.math.abs(adjustments.eyes) < 0.01f || snapshot == null ||
            imageWidth <= 0 || imageHeight <= 0
        ) {
            eyeRadius = 0f
            return
        }
        val left = snapshot.leftEyeBulge
        val right = snapshot.rightEyeBulge
        val front = ArCameraBridge.isFrontCamera
        eyeL = FaceCoordinateMapper.toWarpUv(
            left.x, left.y, imageWidth, imageHeight, isFrontCamera = front,
        )
        eyeR = FaceCoordinateMapper.toWarpUv(
            right.x, right.y, imageWidth, imageHeight, isFrontCamera = front,
        )
        // Radius from one eye's width so the warp stays on the lids, not the brow.
        val leftOuter = snapshot.landmarks.getOrNull(33)
        val leftInner = snapshot.landmarks.getOrNull(133)
        val rightInner = snapshot.landmarks.getOrNull(362)
        val rightOuter = snapshot.landmarks.getOrNull(263)
        val leftW = if (leftOuter != null && leftInner != null) {
            kotlin.math.abs(leftInner.x - leftOuter.x)
        } else {
            kotlin.math.abs(right.x - left.x) * 0.28f
        }
        val rightW = if (rightInner != null && rightOuter != null) {
            kotlin.math.abs(rightOuter.x - rightInner.x)
        } else {
            leftW
        }
        val eyeW = ((leftW + rightW) * 0.5f).coerceAtLeast(1f)
        // Full eye socket (corners + lids) so enlarge covers the whole eye.
        eyeRadius = FaceCoordinateMapper.toWarpRadiusX(eyeW * 1.05f, imageWidth)
    }

    /** Mouth center for lip thick/thin (−1 thinner, +1 thicker). */
    fun updateMouthLandmarks(
        snapshot: FaceLandmarkSnapshot?,
        imageWidth: Int,
        imageHeight: Int,
    ) {
        if ((kotlin.math.abs(adjustments.mouth) < 0.01f &&
                kotlin.math.abs(adjustments.tooth) < 0.01f) ||
            snapshot == null ||
            imageWidth <= 0 || imageHeight <= 0
        ) {
            mouthRadius = 0f
            toothVisibility = 0f
            toothRegion = floatArrayOf(0f, 0f, 0f, 0f)
            return
        }
        val left = snapshot.mouthLeft
        val right = snapshot.mouthRight
        val top = snapshot.landmarks.getOrNull(MediaPipeLandmarkIndices.MOUTH_TOP)
        val bottom = snapshot.mouthBottom
        val cx = (left.x + right.x) * 0.5f
        val cy = when {
            top != null -> (top.y + bottom.y) * 0.5f
            else -> (left.y + right.y + bottom.y) / 3f
        }
        val front = ArCameraBridge.isFrontCamera
        mouthCenter = FaceCoordinateMapper.toWarpUv(
            cx, cy, imageWidth, imageHeight, isFrontCamera = front,
        )
        val mouthW = (right.x - left.x).coerceAtLeast(1f)
        mouthRadius = FaceCoordinateMapper.toWarpRadiusX(mouthW * 0.58f, imageWidth)

        val innerTop =
            snapshot.landmarks.getOrNull(MediaPipeLandmarkIndices.MOUTH_INNER_TOP)
        val innerBottom =
            snapshot.landmarks.getOrNull(MediaPipeLandmarkIndices.MOUTH_INNER_BOTTOM)
        val innerLeft =
            snapshot.landmarks.getOrNull(MediaPipeLandmarkIndices.MOUTH_INNER_LEFT)
        val innerRight =
            snapshot.landmarks.getOrNull(MediaPipeLandmarkIndices.MOUTH_INNER_RIGHT)
        val openingPx = if (innerTop != null && innerBottom != null) {
            kotlin.math.abs(innerBottom.y - innerTop.y)
        } else {
            0f
        }
        val openingRatio = (openingPx / mouthW).coerceAtLeast(0f)
        // Stay completely off until the inner mouth has a real opening. This
        // hard closed-mouth floor prevents whitening from lingering on lips.
        toothVisibility = if (openingRatio <= 0.018f) {
            0f
        } else {
            ((openingRatio - 0.018f) / (0.045f - 0.018f)).coerceIn(0f, 1f)
        }

        if (innerTop != null && innerBottom != null && toothVisibility > 0f) {
            val innerCx = if (innerLeft != null && innerRight != null) {
                (innerLeft.x + innerRight.x) * 0.5f
            } else {
                cx
            }
            val innerW = if (innerLeft != null && innerRight != null) {
                kotlin.math.abs(innerRight.x - innerLeft.x)
            } else {
                mouthW * 0.72f
            }
            val mapped = FaceCoordinateMapper.toWarpUv(
                innerCx,
                (innerTop.y + innerBottom.y) * 0.5f,
                imageWidth,
                imageHeight,
                isFrontCamera = front,
            )
            toothRegion = floatArrayOf(
                mapped[0],
                mapped[1],
                // Stay inside the inner lip contour on both axes so no part of
                // the upper or lower lip can ever fall in the region.
                FaceCoordinateMapper.toWarpRadiusX(innerW * 0.49f, imageWidth),
                FaceCoordinateMapper.toWarpLengthY(openingPx * 0.49f, imageHeight),
            )
        } else {
            toothRegion = floatArrayOf(0f, 0f, 0f, 0f)
        }
    }

    private fun averageZone(snapshot: FaceLandmarkSnapshot, indices: IntArray): PointF? {
        var sx = 0f
        var sy = 0f
        var n = 0
        for (idx in indices) {
            val p = snapshot.landmarks.getOrNull(idx) ?: continue
            sx += p.x
            sy += p.y
            n++
        }
        if (n == 0) return null
        return PointF(sx / n, sy / n)
    }
}
