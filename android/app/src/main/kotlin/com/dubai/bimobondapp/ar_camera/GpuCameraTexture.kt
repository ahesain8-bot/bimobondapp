package com.dubai.bimobondapp.ar_camera

import android.graphics.SurfaceTexture
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.view.Surface

/**
 * Encapsulates OpenGL OES GPU texture initialization, SurfaceTexture binding,
 * transform matrix retrieval, and CameraX surface generation for live GPU preview.
 */
class GpuCameraTexture : SurfaceTexture.OnFrameAvailableListener {

    var textureId: Int = 0
        private set

    var surfaceTexture: SurfaceTexture? = null
        private set

    var surface: Surface? = null
        private set

    val transformMatrix = FloatArray(16)

    private var onFrameAvailableCallback: (() -> Unit)? = null

    fun initialize(onFrameAvailable: (() -> Unit)? = null) {
        onFrameAvailableCallback = onFrameAvailable
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        textureId = textures[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MIN_FILTER,
            GLES20.GL_LINEAR
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MAG_FILTER,
            GLES20.GL_LINEAR
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_S,
            GLES20.GL_CLAMP_TO_EDGE
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_T,
            GLES20.GL_CLAMP_TO_EDGE
        )

        val st = SurfaceTexture(textureId)
        st.setOnFrameAvailableListener(this)
        surfaceTexture = st
        surface = Surface(st)
    }

    override fun onFrameAvailable(st: SurfaceTexture?) {
        onFrameAvailableCallback?.invoke()
    }

    fun updateFrame() {
        val st = surfaceTexture ?: return
        try {
            st.updateTexImage()
            st.getTransformMatrix(transformMatrix)
        } catch (_: Exception) {
        }
    }

    fun release() {
        onFrameAvailableCallback = null
        try {
            surface?.release()
        } catch (_: Exception) {
        }
        surface = null

        try {
            surfaceTexture?.release()
        } catch (_: Exception) {
        }
        surfaceTexture = null

        if (textureId != 0) {
            val textures = intArrayOf(textureId)
            GLES20.glDeleteTextures(1, textures, 0)
            textureId = 0
        }
    }
}
