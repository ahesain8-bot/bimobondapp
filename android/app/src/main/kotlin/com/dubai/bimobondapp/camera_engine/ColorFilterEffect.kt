package com.dubai.bimobondapp.camera_engine

import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Phase 2: one GPU color filter (brightness / contrast / saturation).
 * No Bitmap path — samples [samplerExternalOES] only.
 */
class ColorFilterEffect(
    override val id: String = "color_bcs",
) : FilterEffect, EffectRenderer {

    @Volatile
    override var enabled: Boolean = true

    @Volatile
    override var intensity: Float = 0.55f
        set(value) {
            field = value.coerceIn(0f, 1f)
        }

    private var program = 0
    private var aPosition = -1
    private var aTexCoord = -1
    private var uTexture = -1
    private var uTexMatrix = -1
    private var uIntensity = -1
    private var uBrightness = -1
    private var uContrast = -1
    private var uSaturation = -1

    private val vertexBuffer: FloatBuffer = floatBufferOf(
        -1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f,
    )
    private val texBuffer: FloatBuffer = floatBufferOf(
        0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f,
    )

    fun ensureProgram() {
        if (program != 0) return
        program = buildProgram(VERTEX, FRAGMENT)
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTexture = GLES20.glGetUniformLocation(program, "uTexture")
        uTexMatrix = GLES20.glGetUniformLocation(program, "uTexMatrix")
        uIntensity = GLES20.glGetUniformLocation(program, "uIntensity")
        uBrightness = GLES20.glGetUniformLocation(program, "uBrightness")
        uContrast = GLES20.glGetUniformLocation(program, "uContrast")
        uSaturation = GLES20.glGetUniformLocation(program, "uSaturation")
    }

    override fun draw(
        oesTextureId: Int,
        width: Int,
        height: Int,
        transformMatrix: FloatArray,
    ) {
        ensureProgram()
        GLES20.glViewport(0, 0, width, height)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glUniform1i(uTexture, 0)
        GLES20.glUniformMatrix4fv(uTexMatrix, 1, false, transformMatrix, 0)

        val amount = if (enabled) intensity else 0f
        // Base look at intensity=1.0 — mild vivid grade.
        GLES20.glUniform1f(uIntensity, amount)
        GLES20.glUniform1f(uBrightness, 0.06f)
        GLES20.glUniform1f(uContrast, 1.12f)
        GLES20.glUniform1f(uSaturation, 1.18f)

        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(aTexCoord)
        GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 0, texBuffer)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, 0)
    }

    override fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
    }

    companion object {
        private const val TAG = "ColorFilterEffect"

        private const val VERTEX = """
            attribute vec4 aPosition;
            attribute vec4 aTexCoord;
            uniform mat4 uTexMatrix;
            varying vec2 vTexCoord;
            void main() {
              gl_Position = aPosition;
              vTexCoord = (uTexMatrix * aTexCoord).xy;
            }
        """

        private const val FRAGMENT = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            uniform samplerExternalOES uTexture;
            uniform float uIntensity;
            uniform float uBrightness;
            uniform float uContrast;
            uniform float uSaturation;
            varying vec2 vTexCoord;

            void main() {
              vec4 src = texture2D(uTexture, vTexCoord);
              vec3 color = src.rgb;

              // Brightness
              color += uBrightness;

              // Contrast around mid-gray
              color = (color - 0.5) * uContrast + 0.5;

              // Saturation
              float luma = dot(color, vec3(0.299, 0.587, 0.114));
              color = mix(vec3(luma), color, uSaturation);

              color = clamp(color, 0.0, 1.0);
              vec3 outRgb = mix(src.rgb, color, clamp(uIntensity, 0.0, 1.0));
              gl_FragColor = vec4(outRgb, src.a);
            }
        """

        private fun floatBufferOf(vararg values: Float): FloatBuffer {
            return ByteBuffer.allocateDirect(values.size * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
                .apply {
                    put(values)
                    position(0)
                }
        }

        private fun buildProgram(vertexSrc: String, fragmentSrc: String): Int {
            val vs = compile(GLES20.GL_VERTEX_SHADER, vertexSrc)
            val fs = compile(GLES20.GL_FRAGMENT_SHADER, fragmentSrc)
            val program = GLES20.glCreateProgram()
            GLES20.glAttachShader(program, vs)
            GLES20.glAttachShader(program, fs)
            GLES20.glLinkProgram(program)
            val link = IntArray(1)
            GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, link, 0)
            GLES20.glDeleteShader(vs)
            GLES20.glDeleteShader(fs)
            if (link[0] == 0) {
                val log = GLES20.glGetProgramInfoLog(program)
                GLES20.glDeleteProgram(program)
                Log.e(TAG, "link failed: $log")
                throw IllegalStateException("shader link failed: $log")
            }
            return program
        }

        private fun compile(type: Int, source: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, source)
            GLES20.glCompileShader(shader)
            val compiled = IntArray(1)
            GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
            if (compiled[0] == 0) {
                val log = GLES20.glGetShaderInfoLog(shader)
                GLES20.glDeleteShader(shader)
                Log.e(TAG, "compile failed: $log")
                throw IllegalStateException("shader compile failed: $log")
            }
            return shader
        }
    }
}
