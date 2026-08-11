package com.dubai.bimobondapp.camera_engine

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES20
import android.opengl.GLUtils
import android.util.Log
import java.io.File

/**
 * Phase 4: loadable 2D effect texture source.
 *
 * Supports asset-path, absolute file, or prebuilt [Bitmap].
 * GL upload happens on the GL thread via [uploadToGl].
 */
class EffectAsset private constructor(
    val id: String,
    private var bitmap: Bitmap?,
    private val ownsBitmap: Boolean,
) {
    @Volatile
    var glTextureId: Int = 0
        private set

    val width: Int get() = bitmap?.width ?: 0
    val height: Int get() = bitmap?.height ?: 0
    val aspect: Float
        get() {
            val b = bitmap ?: return 1f
            if (b.width <= 0) return 1f
            return b.height.toFloat() / b.width.toFloat()
        }

    fun isReady(): Boolean = bitmap != null && !bitmap!!.isRecycled

    /** Must run on GL thread. */
    fun uploadToGl() {
        val bmp = bitmap
        if (bmp == null || bmp.isRecycled) return
        if (glTextureId != 0) return

        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        val tex = textures[0]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        glTextureId = tex
        Log.i(TAG, "uploaded asset=$id tex=$tex ${bmp.width}x${bmp.height}")
    }

    /** Must run on GL thread. */
    fun releaseGl() {
        if (glTextureId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(glTextureId), 0)
            glTextureId = 0
        }
    }

    /** Safe from any thread — recycles bitmap only (no GLES). */
    fun releaseCpu() {
        if (ownsBitmap) {
            try {
                bitmap?.takeIf { !it.isRecycled }?.recycle()
            } catch (_: Throwable) {
            }
        }
        bitmap = null
    }

    /** Full release — must run on GL thread (deletes texture then bitmap). */
    fun release() {
        releaseGl()
        releaseCpu()
    }

    companion object {
        private const val TAG = "EffectAsset"

        fun fromBitmap(id: String, bitmap: Bitmap, ownsBitmap: Boolean = true): EffectAsset {
            return EffectAsset(id, bitmap, ownsBitmap)
        }

        fun fromAssetPath(context: Context, id: String, assetPath: String): EffectAsset? {
            return try {
                context.assets.open(assetPath).use { stream ->
                    val bmp = BitmapFactory.decodeStream(stream) ?: return null
                    fromBitmap(id, bmp, ownsBitmap = true)
                }
            } catch (t: Throwable) {
                Log.w(TAG, "fromAssetPath $assetPath", t)
                null
            }
        }

        fun fromFile(id: String, path: String): EffectAsset? {
            return try {
                val file = File(path)
                if (!file.exists()) return null
                val bmp = BitmapFactory.decodeFile(path) ?: return null
                fromBitmap(id, bmp, ownsBitmap = true)
            } catch (t: Throwable) {
                Log.w(TAG, "fromFile $path", t)
                null
            }
        }
    }
}
