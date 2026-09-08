package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.opengl.GLES20
import android.util.Log

/**
 * Reusable RGBA8 FBO + texture for the canonical oriented camera frame.
 * Resizes only when dimensions change; never allocates per steady-state frame.
 */
internal class V3CanonicalTarget {
    var textureId: Int = 0
        private set
    var fboId: Int = 0
        private set
    var width: Int = 0
        private set
    var height: Int = 0
        private set

    /**
     * Ensures an RGBA texture+FBO of [w]×[h]. Returns false on GL failure.
     * Call only on the GL thread.
     */
    fun ensure(w: Int, h: Int): Boolean {
        val tw = w.coerceAtLeast(2)
        val th = h.coerceAtLeast(2)
        if (textureId != 0 && fboId != 0 && width == tw && height == th) {
            return true
        }
        V3Diagnostics.noteTextureOrFboAllocation("canonical ${tw}x$th (was ${width}x$height)")
        release()

        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        textureId = tex[0]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D,
            0,
            GLES20.GL_RGBA,
            tw,
            th,
            0,
            GLES20.GL_RGBA,
            GLES20.GL_UNSIGNED_BYTE,
            null,
        )

        val fbo = IntArray(1)
        GLES20.glGenFramebuffers(1, fbo, 0)
        fboId = fbo[0]
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fboId)
        GLES20.glFramebufferTexture2D(
            GLES20.GL_FRAMEBUFFER,
            GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D,
            textureId,
            0,
        )
        val status = GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        if (status != GLES20.GL_FRAMEBUFFER_COMPLETE) {
            Log.e(TAG, "canonical FBO incomplete status=0x${Integer.toHexString(status)}")
            release()
            return false
        }
        width = tw
        height = th
        return true
    }

    fun release() {
        if (fboId != 0) {
            GLES20.glDeleteFramebuffers(1, intArrayOf(fboId), 0)
            fboId = 0
        }
        if (textureId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
            textureId = 0
        }
        width = 0
        height = 0
    }

    /** Drop handles after EGL context loss without glDelete (names are invalid). */
    fun forgetHandles() {
        fboId = 0
        textureId = 0
        width = 0
        height = 0
    }

    companion object {
        private const val TAG = "BeautyV3"
    }
}
