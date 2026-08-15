package com.dubai.bimobondapp.ar_camera

import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.Matrix
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * OpenGL ES 2.0/3.0 Shader Compositor for blending MP4 video overlay textures on top
 * of raw Camera OES preview textures on the GPU with normalized position, scale,
 * opacity, rotation, and alpha blending.
 */
class GpuOverlayRenderer {

    private val vertexShaderCode = """
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        uniform mat4 uSTMatrix;
        uniform mat4 uMVPMatrix;
        varying vec2 vTextureCoord;
        void main() {
            gl_Position = uMVPMatrix * aPosition;
            vTextureCoord = (uSTMatrix * aTextureCoord).xy;
        }
    """.trimIndent()

    private val fragmentShaderCode = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        varying vec2 vTextureCoord;
        uniform samplerExternalOES sTexture;
        uniform float uOpacity;
        uniform int uChromaKey;
        void main() {
            vec4 color = texture2D(sTexture, vTextureCoord);
            if (uChromaKey == 1) {
                // Chroma-key green screen keying fallback
                if (color.g > 0.4 && color.r < 0.3 && color.b < 0.3) {
                    discard;
                }
            }
            color.a = color.a * uOpacity;
            gl_FragColor = color;
        }
    """.trimIndent()

    private var program = 0
    private var aPositionHandle = 0
    private var aTextureCoordHandle = 0
    private var uSTMatrixHandle = 0
    private var uMVPMatrixHandle = 0
    private var uOpacityHandle = 0
    private var uChromaKeyHandle = 0

    private val vertexBuffer: FloatBuffer
    private val textureBuffer: FloatBuffer

    private val mvpMatrix = FloatArray(16)

    init {
        val squareCoords = floatArrayOf(
            -1.0f, -1.0f, 0.0f,
             1.0f, -1.0f, 0.0f,
            -1.0f,  1.0f, 0.0f,
             1.0f,  1.0f, 0.0f
        )
        val textureCoords = floatArrayOf(
            0.0f, 0.0f,
            1.0f, 0.0f,
            0.0f, 1.0f,
            1.0f, 1.0f
        )

        vertexBuffer = ByteBuffer.allocateDirect(squareCoords.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer().apply {
                put(squareCoords)
                position(0)
            }

        textureBuffer = ByteBuffer.allocateDirect(textureCoords.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer().apply {
                put(textureCoords)
                position(0)
            }
    }

    fun initialize() {
        val vShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexShaderCode)
        val fShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentShaderCode)
        program = GLES20.glCreateProgram().also {
            GLES20.glAttachShader(it, vShader)
            GLES20.glAttachShader(it, fShader)
            GLES20.glLinkProgram(it)
        }

        aPositionHandle = GLES20.glGetAttribLocation(program, "aPosition")
        aTextureCoordHandle = GLES20.glGetAttribLocation(program, "aTextureCoord")
        uSTMatrixHandle = GLES20.glGetUniformLocation(program, "uSTMatrix")
        uMVPMatrixHandle = GLES20.glGetUniformLocation(program, "uMVPMatrix")
        uOpacityHandle = GLES20.glGetUniformLocation(program, "uOpacity")
        uChromaKeyHandle = GLES20.glGetUniformLocation(program, "uChromaKey")
    }

    fun drawLayer(
        textureId: Int,
        stMatrix: FloatArray,
        opacity: Float = 1.0f,
        posX: Float = 0.5f,
        posY: Float = 0.5f,
        scale: Float = 1.0f,
        rotation: Float = 0.0f,
        enableChromaKey: Boolean = false
    ) {
        if (program == 0 || textureId == 0) return

        GLES20.glUseProgram(program)

        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)

        Matrix.setIdentityM(mvpMatrix, 0)
        val tx = (posX - 0.5f) * 2.0f
        val ty = -(posY - 0.5f) * 2.0f
        Matrix.translateM(mvpMatrix, 0, tx, ty, 0f)
        Matrix.scaleM(mvpMatrix, 0, scale, scale, 1.0f)
        if (rotation != 0.0f) {
            Matrix.rotateM(mvpMatrix, 0, rotation, 0f, 0f, 1.0f)
        }

        vertexBuffer.position(0)
        GLES20.glVertexAttribPointer(aPositionHandle, 3, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(aPositionHandle)

        textureBuffer.position(0)
        GLES20.glVertexAttribPointer(aTextureCoordHandle, 2, GLES20.GL_FLOAT, false, 0, textureBuffer)
        GLES20.glEnableVertexAttribArray(aTextureCoordHandle)

        GLES20.glUniformMatrix4fv(uSTMatrixHandle, 1, false, stMatrix, 0)
        GLES20.glUniformMatrix4fv(uMVPMatrixHandle, 1, false, mvpMatrix, 0)
        GLES20.glUniform1f(uOpacityHandle, opacity)
        GLES20.glUniform1i(uChromaKeyHandle, if (enableChromaKey) 1 else 0)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(aPositionHandle)
        GLES20.glDisableVertexAttribArray(aTextureCoordHandle)
    }

    private fun loadShader(type: Int, shaderCode: String): Int {
        return GLES20.glCreateShader(type).also { shader ->
            GLES20.glShaderSource(shader, shaderCode)
            GLES20.glCompileShader(shader)
        }
    }

    fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
    }
}
