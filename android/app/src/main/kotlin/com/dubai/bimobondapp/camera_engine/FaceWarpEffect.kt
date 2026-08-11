package com.dubai.bimobondapp.camera_engine

import android.opengl.GLES20
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer

/**
 * Phase 6: draws a deformed [FaceMesh] sampling a 2D texture (FBO color).
 * Vertex positions stay on a screen grid; warped UVs create the liquify look.
 */
class FaceWarpEffect(
    override val id: String = "face_warp",
) : FaceWarpShaderEffect, EffectRenderer {

    @Volatile
    override var enabled: Boolean = false

    @Volatile
    override var intensity: Float = 1f
        set(value) {
            field = value.coerceIn(0f, 1f)
        }

    private val mesh = FaceMesh()

    @Volatile
    private var params: WarpParameters = WarpParameters()

    @Volatile
    private var pendingInterleaved: FloatArray? = null

    private var program = 0
    private var aPosition = -1
    private var aTexCoord = -1
    private var uTexture = -1

    private var vbo = 0
    private var ibo = 0
    private var indexBuffer: ShortBuffer? = null

    private var passthroughProgram = 0
    private var ptPosition = -1
    private var ptTexCoord = -1
    private var ptTexture = -1
    private val quadPos: FloatBuffer = floatBufferOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)
    private val quadUv: FloatBuffer = floatBufferOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f)

    fun getMesh(): FaceMesh = mesh

    fun setParameters(next: WarpParameters) {
        params = next.clamped()
        enabled = params.isVisuallyActive()
        if (!enabled) {
            mesh.resetIdentity()
            pendingInterleaved = mesh.copyInterleaved()
        }
    }

    fun getParameters(): WarpParameters = params

    /** Analyzer thread: rebuild mesh UVs from face landmarks. */
    fun updateFromFaces(faces: List<FaceLandmarks>) {
        if (!params.isVisuallyActive()) {
            mesh.resetIdentity()
            pendingInterleaved = mesh.copyInterleaved()
            return
        }
        mesh.updateFromFace(faces.firstOrNull(), params)
        pendingInterleaved = mesh.copyInterleaved()
    }

    fun clearFace() {
        mesh.resetIdentity()
        pendingInterleaved = mesh.copyInterleaved()
    }

    fun ensureProgram() {
        if (program != 0) return
        program = buildProgram(VERTEX, FRAGMENT)
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTexture = GLES20.glGetUniformLocation(program, "uTexture")

        val vbos = IntArray(2)
        GLES20.glGenBuffers(2, vbos, 0)
        vbo = vbos[0]
        ibo = vbos[1]

        val idx = ByteBuffer.allocateDirect(mesh.indices.size * 2)
            .order(ByteOrder.nativeOrder())
            .asShortBuffer()
            .apply {
                put(mesh.indices)
                position(0)
            }
        indexBuffer = idx
        GLES20.glBindBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, ibo)
        GLES20.glBufferData(
            GLES20.GL_ELEMENT_ARRAY_BUFFER,
            mesh.indices.size * 2,
            idx,
            GLES20.GL_STATIC_DRAW,
        )
        GLES20.glBindBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, 0)

        // Initial identity mesh.
        uploadMesh(mesh.copyInterleaved())
    }

    override fun draw(
        oesTextureId: Int,
        width: Int,
        height: Int,
        transformMatrix: FloatArray,
    ) {
        drawFromTexture(oesTextureId, width, height)
    }

    fun drawFromTexture(texture2dId: Int, width: Int, height: Int) {
        if (!params.isVisuallyActive()) {
            drawPassthrough(texture2dId, width, height)
            return
        }
        ensureProgram()
        pendingInterleaved?.let {
            uploadMesh(it)
            pendingInterleaved = null
        }

        GLES20.glViewport(0, 0, width, height)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture2dId)
        GLES20.glUniform1i(uTexture, 0)

        GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, vbo)
        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 16, 0)
        GLES20.glEnableVertexAttribArray(aTexCoord)
        GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 16, 8)

        GLES20.glBindBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, ibo)
        GLES20.glDrawElements(
            GLES20.GL_TRIANGLES,
            mesh.indexCount,
            GLES20.GL_UNSIGNED_SHORT,
            0,
        )
        GLES20.glBindBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, 0)
        GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, 0)
        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }

    fun drawPassthrough(texture2dId: Int, width: Int, height: Int) {
        ensurePassthrough()
        GLES20.glViewport(0, 0, width, height)
        GLES20.glUseProgram(passthroughProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture2dId)
        GLES20.glUniform1i(ptTexture, 0)
        GLES20.glEnableVertexAttribArray(ptPosition)
        GLES20.glVertexAttribPointer(ptPosition, 2, GLES20.GL_FLOAT, false, 0, quadPos)
        GLES20.glEnableVertexAttribArray(ptTexCoord)
        GLES20.glVertexAttribPointer(ptTexCoord, 2, GLES20.GL_FLOAT, false, 0, quadUv)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(ptPosition)
        GLES20.glDisableVertexAttribArray(ptTexCoord)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }

    private fun uploadMesh(data: FloatArray) {
        val buf = ByteBuffer.allocateDirect(data.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                put(data)
                position(0)
            }
        GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, vbo)
        GLES20.glBufferData(
            GLES20.GL_ARRAY_BUFFER,
            data.size * 4,
            buf,
            GLES20.GL_DYNAMIC_DRAW,
        )
        GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, 0)
    }

    private fun ensurePassthrough() {
        if (passthroughProgram != 0) return
        passthroughProgram = buildProgram(VERTEX_PT, FRAGMENT)
        ptPosition = GLES20.glGetAttribLocation(passthroughProgram, "aPosition")
        ptTexCoord = GLES20.glGetAttribLocation(passthroughProgram, "aTexCoord")
        ptTexture = GLES20.glGetUniformLocation(passthroughProgram, "uTexture")
    }

    override fun release() {
        if (vbo != 0 || ibo != 0) {
            GLES20.glDeleteBuffers(2, intArrayOf(vbo, ibo), 0)
            vbo = 0
            ibo = 0
        }
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        if (passthroughProgram != 0) {
            GLES20.glDeleteProgram(passthroughProgram)
            passthroughProgram = 0
        }
        pendingInterleaved = null
        mesh.resetIdentity()
    }

    companion object {
        private const val TAG = "FaceWarpEffect"

        private const val VERTEX = """
            attribute vec2 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vUv;
            void main() {
              gl_Position = vec4(aPosition, 0.0, 1.0);
              vUv = aTexCoord;
            }
        """

        private const val VERTEX_PT = """
            attribute vec2 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vUv;
            void main() {
              gl_Position = vec4(aPosition, 0.0, 1.0);
              vUv = aTexCoord;
            }
        """

        private const val FRAGMENT = """
            precision mediump float;
            uniform sampler2D uTexture;
            varying vec2 vUv;
            void main() {
              gl_FragColor = texture2D(uTexture, vUv);
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
                throw IllegalStateException("face warp shader link failed")
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
                throw IllegalStateException("face warp shader compile failed: $log")
            }
            return shader
        }
    }
}
