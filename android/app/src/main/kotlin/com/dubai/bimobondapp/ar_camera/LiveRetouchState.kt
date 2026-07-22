package com.dubai.bimobondapp.ar_camera

import android.graphics.PointF
import com.dubai.bimobondapp.beauty.BeautyFilterProcessor
import kotlin.math.roundToInt

/**
 * Live camera retouch sliders (-1…1, 0 = original). Applied in GPU preview and
 * baked into captures via the same GL pipeline.
 */
data class LiveRetouchAdjustments(
    val saturation: Float = 0f,
    val brightness: Float = 0f,
    val contrast: Float = 0f,
    val exposure: Float = 0f,
    val whiteBalance: Float = 0f,
    val highlights: Float = 0f,
    val shadows: Float = 0f,
    val nose: Float = 0f,
) {
    val hasColor: Boolean
        get() = kotlin.math.abs(saturation) > 0.01f ||
            kotlin.math.abs(brightness) > 0.01f ||
            kotlin.math.abs(contrast) > 0.01f ||
            kotlin.math.abs(exposure) > 0.01f ||
            kotlin.math.abs(whiteBalance) > 0.01f ||
            kotlin.math.abs(highlights) > 0.01f ||
            kotlin.math.abs(shadows) > 0.01f

    val isNoop: Boolean get() = !hasColor && kotlin.math.abs(nose) < 0.01f

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
        fun fromLevels(
            saturation: Int = 0,
            brightness: Int = 0,
            contrast: Int = 0,
            exposure: Int = 0,
            whiteBalance: Int = 0,
            highlights: Int = 0,
            shadows: Int = 0,
            nose: Int = 0,
        ): LiveRetouchAdjustments = LiveRetouchAdjustments(
            saturation = saturation / 100f,
            brightness = brightness / 100f,
            contrast = contrast / 100f,
            exposure = exposure / 100f,
            whiteBalance = whiteBalance / 100f,
            highlights = highlights / 100f,
            shadows = shadows / 100f,
            nose = nose / 100f,
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

    fun clear() {
        adjustments = LiveRetouchAdjustments()
        noseWingL = floatArrayOf(0f, 0f)
        noseWingR = floatArrayOf(0f, 0f)
        noseRadius = 0f
    }

    /** Maps face landmarks to texture UV wings for live nose liquify. */
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
        val front = ArCameraBridge.isFrontCamera
        noseWingL = FaceCoordinateMapper.toWarpUv(lw.x, lw.y, imageWidth, imageHeight, isFrontCamera = front)
        noseWingR = FaceCoordinateMapper.toWarpUv(rw.x, rw.y, imageWidth, imageHeight, isFrontCamera = front)
        val noseWidth = (rw.x - lw.x).coerceAtLeast(1f)
        noseRadius = FaceCoordinateMapper.toWarpRadiusX(noseWidth * 0.80f, imageWidth)
    }
}
