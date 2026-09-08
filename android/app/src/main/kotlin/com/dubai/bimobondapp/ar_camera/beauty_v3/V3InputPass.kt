package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.opengl.GLES11Ext
import android.opengl.GLES20
import java.nio.FloatBuffer

/**
 * OES external texture → canonical oriented RGBA2D.
 *
 * Applies only SurfaceTexture transform + the same Y tex-transform as legacy RAW.
 * No framing, beauty, color, or readback.
 */
internal class V3InputPass {
    private var program = 0
    private var aPosition = 0
    private var aTexCoord = 0
    private var uTexture = 0
    private var uStMatrix = 0
    private var uTexTransform = 0

    private val texTransform = FloatArray(9)
    private var texTransformReady = false

    fun ensureProgram(): Boolean {
        if (program != 0) return true
        program = V3GlProgram.build(VERTEX, FRAGMENT)
        if (program == 0) return false
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTexture = GLES20.glGetUniformLocation(program, "uTexture")
        uStMatrix = GLES20.glGetUniformLocation(program, "uStMatrix")
        uTexTransform = GLES20.glGetUniformLocation(program, "uTexTransform")
        return true
    }

    /**
     * Renders [oesTextureId] into [target] using [contract.stMatrix].
     * Leaves the default framebuffer unbound (FBO 0) and restores no viewport —
     * caller owns viewport restore.
     */
    fun draw(
        oesTextureId: Int,
        contract: V3FrameContract,
        target: V3CanonicalTarget,
        vertexBuffer: FloatBuffer,
    ): Boolean {
        if (oesTextureId == 0 || !ensureProgram()) return false
        if (!target.ensure(contract.canonicalWidth, contract.canonicalHeight)) return false

        if (!texTransformReady) {
            // Same Y-flip as FaceWarpRenderer RAW: Android top-left UV → ST space.
            texTransform[0] = 1f; texTransform[1] = 0f; texTransform[2] = 0f
            texTransform[3] = 0f; texTransform[4] = -1f; texTransform[5] = 0f
            texTransform[6] = 0f; texTransform[7] = 1f; texTransform[8] = 1f
            texTransformReady = true
        }

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, target.fboId)
        GLES20.glViewport(0, 0, target.width, target.height)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glUniform1i(uTexture, 0)
        GLES20.glUniformMatrix4fv(uStMatrix, 1, false, contract.stMatrix, 0)
        GLES20.glUniformMatrix3fv(uTexTransform, 1, false, texTransform, 0)

        vertexBuffer.position(0)
        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        GLES20.glEnableVertexAttribArray(aTexCoord)
        vertexBuffer.position(2)
        GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        vertexBuffer.position(0)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)

        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, 0)
        // Leave FBO bound — caller restores the previous framebuffer binding.
        return true
    }

    fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        texTransformReady = false
    }

    fun forgetHandles() {
        program = 0
        texTransformReady = false
    }

    companion object {
        private const val VERTEX = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = aPosition;
                vTexCoord = aTexCoord;
            }
        """

        /**
         * Full-buffer sample: no FILL/FIT. vTexCoord uses the same Android top-left
         * convention as legacy RAW quads; uTexTransform + uStMatrix match RAW.
         */
        private const val FRAGMENT = """
            #extension GL_OES_EGL_image_external : require
            precision highp float;
            varying vec2 vTexCoord;
            uniform samplerExternalOES uTexture;
            uniform mat4 uStMatrix;
            uniform mat3 uTexTransform;
            void main() {
                vec2 uv = (uTexTransform * vec3(vTexCoord, 1.0)).xy;
                vec2 st = (uStMatrix * vec4(uv, 0.0, 1.0)).xy;
                gl_FragColor = texture2D(uTexture, st);
            }
        """
    }
}
