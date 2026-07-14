package com.dubai.bimobondapp.ar_camera

import kotlin.math.abs
import kotlin.math.max

/**
 * Maps image-space landmarks to the same texture UV space used by the GPU
 * centerCrop shader and [FaceOverlayView] FILL_CENTER layout.
 */
object FaceCoordinateMapper {

    fun toScreenNormalized(
        x: Float,
        y: Float,
        imageWidth: Int,
        imageHeight: Int,
        viewWidth: Int,
        viewHeight: Int,
        isFrontCamera: Boolean = true,
    ): FloatArray {
        val scale = max(
            viewWidth.toFloat() / imageWidth,
            viewHeight.toFloat() / imageHeight,
        )
        val offsetX = (viewWidth - imageWidth * scale) / 2f
        val offsetY = (viewHeight - imageHeight * scale) / 2f

        var screenX = x * scale + offsetX
        val screenY = y * scale + offsetY

        if (isFrontCamera) {
            screenX = viewWidth - screenX
        }

        return floatArrayOf(
            (screenX / viewWidth).coerceIn(0f, 1f),
            (screenY / viewHeight).coerceIn(0f, 1f),
        )
    }

    fun toCenterCropTextureUv(
        x: Float,
        y: Float,
        imageWidth: Int,
        imageHeight: Int,
        viewWidth: Int,
        viewHeight: Int,
        isFrontCamera: Boolean = true,
    ): FloatArray {
        val screen = toScreenNormalized(
            x, y, imageWidth, imageHeight, viewWidth, viewHeight, isFrontCamera,
        )
        return inverseCenterCrop(
            screen[0], screen[1], imageWidth, imageHeight, viewWidth, viewHeight,
        )
    }

    fun inverseCenterCrop(
        screenNormX: Float,
        screenNormY: Float,
        imageWidth: Int,
        imageHeight: Int,
        viewWidth: Int,
        viewHeight: Int,
    ): FloatArray {
        val texAspect = imageWidth.toFloat() / imageHeight
        val viewAspect = viewWidth.toFloat() / viewHeight

        return if (texAspect > viewAspect) {
            val scale = viewAspect / texAspect
            val offset = (1f - scale) * 0.5f
            floatArrayOf(
                ((screenNormX - offset) / scale).coerceIn(0f, 1f),
                screenNormY.coerceIn(0f, 1f),
            )
        } else {
            val scale = texAspect / viewAspect
            val offset = (1f - scale) * 0.5f
            floatArrayOf(
                screenNormX.coerceIn(0f, 1f),
                ((screenNormY - offset) / scale).coerceIn(0f, 1f),
            )
        }
    }

    fun radiusToTextureUvX(
        centerX: Float,
        centerY: Float,
        radiusPx: Float,
        imageWidth: Int,
        imageHeight: Int,
        viewWidth: Int,
        viewHeight: Int,
    ): Float {
        val center = toCenterCropTextureUv(
            centerX, centerY, imageWidth, imageHeight, viewWidth, viewHeight,
        )
        val edge = toCenterCropTextureUv(
            centerX + radiusPx, centerY, imageWidth, imageHeight, viewWidth, viewHeight,
        )
        return abs(edge[0] - center[0]).coerceAtLeast(0.001f)
    }

    /**
     * Converts image-space landmark coordinates (from the un-mirrored oriented bitmap)
     * to raw texture UV coordinates matching the mirrored display bitmap.
     *
     * The GPU shader's centerCrop() maps screen UV → texture UV, so warp uniforms
     * (bulge centres, nose rect) must be in **raw texture UV space** (0..1).
     * Landmarks are detected on the un-mirrored image, but the texture uploaded to
     * the GPU is the horizontally-mirrored display bitmap, so we invert X here.
     */
    fun toWarpUv(
        x: Float,
        y: Float,
        imageWidth: Int,
        imageHeight: Int,
    ): FloatArray {
        val u = (1f - x / imageWidth).coerceIn(0f, 1f)
        val v = (y / imageHeight.toFloat()).coerceIn(0f, 1f)
        return floatArrayOf(u, v)
    }

    /** Converts a pixel radius to texture UV X units (mirror-safe, aspect-independent). */
    fun toWarpRadiusX(
        radiusPx: Float,
        imageWidth: Int,
    ): Float {
        return (radiusPx / imageWidth).coerceAtLeast(0.001f)
    }

    /** Converts a pixel length to texture UV Y units. */
    fun toWarpLengthY(
        lengthPx: Float,
        imageHeight: Int,
    ): Float {
        return (lengthPx / imageHeight).coerceAtLeast(0.001f)
    }
}
