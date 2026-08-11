package com.dubai.bimobondapp.camera_engine

import android.opengl.GLES20
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Draws landmark dots on top of the filtered preview (debug visualization).
 * Runs entirely on the GL thread — no Dart traffic.
 */
class LandmarkDebugOverlay : EffectRenderer {

    @Volatile
    var enabled: Boolean = false

    /** Packed xy in [0,1]; updated atomically from analyzer thread via [updatePoints]. */
    @Volatile
    private var points: FloatArray = FloatArray(0)

    private var program = 0
    private var aPosition = -1
    private var uPointSize = -1
    private var uColor = -1

    fun updatePoints(normalizedXy: FloatArray) {
        points = normalizedXy.copyOf()
    }

    fun clear() {
        points = FloatArray(0)
    }

    fun ensureProgram() {
        if (program != 0) return
        program = buildProgram(VERTEX, FRAGMENT)
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        uPointSize = GLES20.glGetUniformLocation(program, "uPointSize")
        uColor = GLES20.glGetUniformLocation(program, "uColor")
    }

    override fun draw(
        oesTextureId: Int,
        width: Int,
        height: Int,
        transformMatrix: FloatArray,
    ) {
        if (!enabled) return
        val src = points
        if (src.isEmpty() || src.size < 2) return

        ensureProgram()

        // Convert UV [0,1] (top-left origin from MediaPipe) → NDC clip space.
        // MediaPipe y grows downward; GL y grows upward.
        val ndc = FloatArray(src.size)
        val vertexCount = src.size / 2
        for (i in 0 until vertexCount) {
            val u = src[i * 2]
            val v = src[i * 2 + 1]
            ndc[i * 2] = u * 2f - 1f
            ndc[i * 2 + 1] = 1f - v * 2f
        }

        val buffer = ByteBuffer.allocateDirect(ndc.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                put(ndc)
                position(0)
            }

        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glUseProgram(program)
        GLES20.glUniform1f(uPointSize, (width.coerceAtMost(height) / 90f).coerceIn(4f, 10f))
        GLES20.glUniform4f(uColor, 0.1f, 1f, 0.35f, 0.95f)
        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 0, buffer)
        GLES20.glDrawArrays(GLES20.GL_POINTS, 0, vertexCount)
        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisable(GLES20.GL_BLEND)
    }

    override fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        points = FloatArray(0)
    }

    companion object {
        private const val TAG = "LandmarkDebugOverlay"

        private const val VERTEX = """
            attribute vec2 aPosition;
            uniform float uPointSize;
            void main() {
              gl_Position = vec4(aPosition, 0.0, 1.0);
              gl_PointSize = uPointSize;
            }
        """

        private const val FRAGMENT = """
            precision mediump float;
            uniform vec4 uColor;
            void main() {
              vec2 c = gl_PointCoord - vec2(0.5);
              if (dot(c, c) > 0.25) discard;
              gl_FragColor = uColor;
            }
        """

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
                throw IllegalStateException("landmark shader link failed")
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
                throw IllegalStateException("landmark shader compile failed: $log")
            }
            return shader
        }
    }
}
