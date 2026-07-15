package com.dubai.bimobondapp.ar_camera

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint

/**
 * Bakes AR color grades into pixels so photo/video match the live GPU preview.
 * Matrices align with Flutter [ArColorFilterMatrix].
 */
object ArColorGradeBaker {

    fun apply(
        source: Bitmap,
        filter: FilterType,
        intensity: Float = 1f,
    ): Bitmap {
        if (!filter.isColorGrade() || source.isRecycled) return source
        val t = intensity.coerceIn(0f, 1f)
        if (t <= 0.001f) return source

        val matrix = colorMatrixFor(filter) ?: return source
        val blended = if (t >= 0.999f) matrix else lerpIdentity(matrix, t)

        val out = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
            colorFilter = ColorMatrixColorFilter(ColorMatrix(blended))
        }
        canvas.drawBitmap(source, 0f, 0f, paint)
        return out
    }

    private fun colorMatrixFor(filter: FilterType): FloatArray? = when (filter) {
        FilterType.WHITENING -> floatArrayOf(
            1.12f, 0.02f, 0.02f, 0f, 12f,
            0.02f, 1.10f, 0.02f, 0f, 10f,
            0.02f, 0.02f, 1.08f, 0f, 8f,
            0f, 0f, 0f, 1f, 0f,
        )
        FilterType.CLARENDON -> floatArrayOf(
            1.15f, -0.04f, 0.04f, 0f, 8f,
            -0.02f, 1.12f, 0.02f, 0f, 4f,
            0.02f, -0.06f, 1.20f, 0f, 6f,
            0f, 0f, 0f, 1f, 0f,
        )
        FilterType.LUDWIG -> floatArrayOf(
            1.05f, 0.02f, 0.00f, 0f, 6f,
            0.00f, 1.08f, 0.02f, 0f, 4f,
            0.00f, 0.00f, 1.12f, 0f, 8f,
            0f, 0f, 0f, 1f, 0f,
        )
        FilterType.ROSY -> floatArrayOf(
            1.14f, 0.04f, 0.04f, 0f, 10f,
            0.02f, 0.98f, 0.02f, 0f, 4f,
            0.06f, 0.02f, 1.02f, 0f, 8f,
            0f, 0f, 0f, 1f, 0f,
        )
        FilterType.VALENCIA -> floatArrayOf(
            1.18f, 0.06f, -0.02f, 0f, 14f,
            0.04f, 1.06f, -0.02f, 0f, 8f,
            -0.04f, 0.00f, 0.96f, 0f, 2f,
            0f, 0f, 0f, 1f, 0f,
        )
        FilterType.WARM -> floatArrayOf(
            1.16f, 0.08f, 0.00f, 0f, 12f,
            0.04f, 1.06f, 0.00f, 0f, 6f,
            -0.04f, -0.02f, 0.94f, 0f, 0f,
            0f, 0f, 0f, 1f, 0f,
        )
        FilterType.COOL -> floatArrayOf(
            0.94f, 0.00f, 0.06f, 0f, 0f,
            0.00f, 1.02f, 0.06f, 0f, 4f,
            0.04f, 0.04f, 1.18f, 0f, 10f,
            0f, 0f, 0f, 1f, 0f,
        )
        FilterType.VINTAGE -> floatArrayOf(
            0.95f, 0.10f, 0.05f, 0f, 8f,
            0.05f, 0.90f, 0.05f, 0f, 4f,
            0.05f, 0.10f, 0.78f, 0f, 0f,
            0f, 0f, 0f, 1f, 0f,
        )
        FilterType.MONO -> floatArrayOf(
            0.33f, 0.59f, 0.08f, 0f, 0f,
            0.33f, 0.59f, 0.08f, 0f, 0f,
            0.33f, 0.59f, 0.08f, 0f, 0f,
            0f, 0f, 0f, 1f, 0f,
        )
        else -> null
    }

    private fun lerpIdentity(target: FloatArray, t: Float): FloatArray {
        val out = FloatArray(20)
        val identity = floatArrayOf(
            1f, 0f, 0f, 0f, 0f,
            0f, 1f, 0f, 0f, 0f,
            0f, 0f, 1f, 0f, 0f,
            0f, 0f, 0f, 1f, 0f,
        )
        for (i in 0 until 20) {
            out[i] = identity[i] + (target[i] - identity[i]) * t
        }
        return out
    }
}
