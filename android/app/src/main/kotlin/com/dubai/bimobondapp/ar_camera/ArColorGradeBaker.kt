package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import java.io.File
import java.io.FileOutputStream

/**
 * Bakes AR color grades into pixels so photo/video match the live GPU preview.
 * The grade is sampled from the same PNG LUT the live GPU preview uses.
 */
object ArColorGradeBaker {

    /**
     * Loads [inputPath], bakes the [filterId] color grade via its LUT, and writes
     * the result to a new JPEG in the cache dir. Returns the output path, or null
     * when there's nothing to apply / the LUT can't be loaded. Used by the editor
     * (photos) so gallery imports get the exact same look as the live camera.
     *
     * [maxEdge] > 0 downscales for a fast live preview; pass null/0 for full-res
     * export.
     */
    fun applyToFile(
        context: Context,
        inputPath: String,
        filterId: String,
        intensity: Float,
        maxEdge: Int? = null,
    ): String? {
        val filter = FilterType.fromId(filterId)
        val asset = filter.lutAsset() ?: return null
        val t = intensity.coerceIn(0f, 1f)
        if (t <= 0.001f) return null

        val decoded = BitmapFactory.decodeFile(inputPath) ?: return null
        val source = if (maxEdge != null && maxEdge > 0) {
            downscale(decoded, maxEdge)
        } else {
            decoded
        }

        // LutStore.apply returns the same instance it was given when the LUT
        // can't be loaded — treat that as "nothing baked".
        val graded = LutStore.apply(context, source, asset, t)
        val applied = graded !== source

        return try {
            if (!applied) return null
            val out = File(context.cacheDir, "ar_lut_${System.currentTimeMillis()}.jpg")
            FileOutputStream(out).use { stream ->
                graded.compress(Bitmap.CompressFormat.JPEG, 95, stream)
            }
            out.absolutePath
        } catch (_: Throwable) {
            null
        } finally {
            if (graded !== source && graded !== decoded && !graded.isRecycled) {
                graded.recycle()
            }
            if (source !== decoded && !source.isRecycled) source.recycle()
            if (!decoded.isRecycled) decoded.recycle()
        }
    }

    private fun downscale(src: Bitmap, maxEdge: Int): Bitmap {
        val longest = maxOf(src.width, src.height)
        if (longest <= maxEdge) return src
        val scale = maxEdge.toFloat() / longest
        val m = Matrix().apply { postScale(scale, scale) }
        return Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
    }

    fun apply(
        source: Bitmap,
        filter: FilterType,
        intensity: Float = 1f,
    ): Bitmap {
        if (!filter.isColorGrade() || source.isRecycled) return source
        val t = intensity.coerceIn(0f, 1f)
        if (t <= 0.001f) return source

        // Bake the same PNG LUT the live GPU preview uses so the saved photo
        // matches exactly. No matrix fallback — every grade ships a LUT.
        val ctx = ArCameraBridge.hostActivity?.applicationContext ?: return source
        val asset = filter.lutAsset() ?: return source
        return LutStore.apply(ctx, source, asset, t)
    }
}
