package com.dubai.bimobondapp.effect360

import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.Matrix
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer
import kotlin.math.cos
import kotlin.math.sin

class EquirectangularSphereRenderer {
    companion object {
        private const val TAG = "360SphereRenderer"
        private const val SPHERE_RADIUS = 50.0f
        private const val LAT_SEGMENTS = 64
        private const val LON_SEGMENTS = 128

        private const val VERTEX_SHADER_CODE = """
            uniform mat4 uMVPMatrix;
            uniform mat4 uSTMatrix;
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;

            void main() {
                gl_Position = uMVPMatrix * aPosition;
                vec4 texVal = uSTMatrix * vec4(aTexCoord, 0.0, 1.0);
                vTexCoord = texVal.xy;
            }
        """

        private const val FRAGMENT_SHADER_CODE = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;

            varying vec2 vTexCoord;
            uniform samplerExternalOES sVideoTexture;
            uniform samplerExternalOES sAlphaTexture;
            uniform int uHasAlpha;
            uniform float uOpacity;

            void main() {
                // Seamless 360° horizontal wrap (U: fract, V: clamp)
                vec2 uv = vec2(fract(vTexCoord.x), clamp(vTexCoord.y, 0.0, 1.0));
                vec4 videoColor = texture2D(sVideoTexture, uv);
                float alpha = videoColor.a;

                // Live 360° Grid Fallback while buffering / decoding
                if (alpha == 0.0 || (videoColor.r == 0.0 && videoColor.g == 0.0 && videoColor.b == 0.0)) {
                    float gridX = abs(sin(uv.x * 12.566)); // 2 cycles across 360deg
                    float gridY = abs(sin(uv.y * 6.283));  // 1 cycle vertically
                    float line = max(step(0.95, gridX), step(0.95, gridY));
                    vec3 gridCol = mix(vec3(0.02, 0.05, 0.2), vec3(0.0, 0.85, 1.0), line);
                    videoColor = vec4(gridCol, 0.65);
                    alpha = 0.65;
                }

                if (uHasAlpha == 1) {
                    vec4 alphaColor = texture2D(sAlphaTexture, uv);
                    alpha = alphaColor.r;
                }
                gl_FragColor = vec4(videoColor.rgb, alpha * uOpacity);
            }
        """
    }

    private var program: Int = 0
    private var aPositionHandle: Int = -1
    private var aTexCoordHandle: Int = -1
    private var uMVPMatrixHandle: Int = -1
    private var uSTMatrixHandle: Int = -1
    private var uOpacityHandle: Int = -1
    private var uHasAlphaHandle: Int = -1
    private var sVideoTextureHandle: Int = -1
    private var sAlphaTextureHandle: Int = -1

    private var vertexBuffer: FloatBuffer? = null
    private var texCoordBuffer: FloatBuffer? = null
    private var indexBuffer: ShortBuffer? = null
    private var indexCount: Int = 0

    private val modelMatrix = FloatArray(16)

    init {
        Matrix.setIdentityM(modelMatrix, 0)
    }

    fun initializeGl() {
        if (program != 0) return
        createSphereMesh(SPHERE_RADIUS, LAT_SEGMENTS, LON_SEGMENTS)
        program = createProgram(VERTEX_SHADER_CODE, FRAGMENT_SHADER_CODE)

        aPositionHandle = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoordHandle = GLES20.glGetAttribLocation(program, "aTexCoord")
        uMVPMatrixHandle = GLES20.glGetUniformLocation(program, "uMVPMatrix")
        uSTMatrixHandle = GLES20.glGetUniformLocation(program, "uSTMatrix")
        uOpacityHandle = GLES20.glGetUniformLocation(program, "uOpacity")
        uHasAlphaHandle = GLES20.glGetUniformLocation(program, "uHasAlpha")
        sVideoTextureHandle = GLES20.glGetUniformLocation(program, "sVideoTexture")
        sAlphaTextureHandle = GLES20.glGetUniformLocation(program, "sAlphaTexture")
    }

    private fun createSphereMesh(radius: Float, latSegments: Int, longSegments: Int) {
        val vertices = FloatArray((latSegments + 1) * (longSegments + 1) * 3)
        val texCoords = FloatArray((latSegments + 1) * (longSegments + 1) * 2)
        val indices = ShortArray(latSegments * longSegments * 6)

        var vIndex = 0
        var tIndex = 0

        for (lat in 0..latSegments) {
            val theta = lat * Math.PI / latSegments
            val sinTheta = sin(theta).toFloat()
            val cosTheta = cos(theta).toFloat()

            for (lon in 0..longSegments) {
                val phi = lon * 2.0 * Math.PI / longSegments
                val sinPhi = sin(phi).toFloat()
                val cosPhi = cos(phi).toFloat()

                val x = cosPhi * sinTheta
                val y = cosTheta
                val z = sinPhi * sinTheta

                val u = lon.toFloat() / longSegments.toFloat()
                val v = lat.toFloat() / latSegments.toFloat()

                vertices[vIndex++] = x * radius
                vertices[vIndex++] = y * radius
                vertices[vIndex++] = z * radius

                texCoords[tIndex++] = u
                texCoords[tIndex++] = v
            }
        }

        var minU = 1.0f; var maxU = 0.0f
        var minV = 1.0f; var maxV = 0.0f
        for (i in 0 until tIndex step 2) {
            val uVal = texCoords[i]
            val vVal = texCoords[i + 1]
            if (uVal < minU) minU = uVal
            if (uVal > maxU) maxU = uVal
            if (vVal < minV) minV = vVal
            if (vVal > maxV) maxV = vVal
        }

        Log.i("UV_MAPPING", "SPHERE UV RANGE: U=[$minU -> $maxU], V=[$minV -> $maxV]")

        var iIndex = 0
        for (lat in 0 until latSegments) {
            for (lon in 0 until longSegments) {
                val first = (lat * (longSegments + 1) + lon).toShort()
                val second = (first + longSegments + 1).toShort()

                indices[iIndex++] = first
                indices[iIndex++] = second
                indices[iIndex++] = (first + 1).toShort()

                indices[iIndex++] = second
                indices[iIndex++] = (second + 1).toShort()
                indices[iIndex++] = (first + 1).toShort()
            }
        }

        indexCount = indices.size

        vertexBuffer = ByteBuffer.allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                put(vertices)
                position(0)
            }

        texCoordBuffer = ByteBuffer.allocateDirect(texCoords.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                put(texCoords)
                position(0)
            }

        indexBuffer = ByteBuffer.allocateDirect(indices.size * 2)
            .order(ByteOrder.nativeOrder())
            .asShortBuffer()
            .apply {
                put(indices)
                position(0)
            }
    }

    fun renderSphere(
        videoOesTextureId: Int,
        alphaOesTextureId: Int?,
        stMatrixIn: FloatArray,
        projectionMatrix: FloatArray,
        viewMatrix: FloatArray,
        opacity: Float
    ) {
        if (program == 0 || indexCount == 0 || videoOesTextureId == 0) return

        GLES20.glUseProgram(program)

        val mvMatrix = FloatArray(16)
        Matrix.multiplyMM(mvMatrix, 0, viewMatrix, 0, modelMatrix, 0)
        Matrix.multiplyMM(mvMatrix, 0, projectionMatrix, 0, mvMatrix, 0)

        GLES20.glUniformMatrix4fv(uMVPMatrixHandle, 1, false, mvMatrix, 0)
        GLES20.glUniformMatrix4fv(uSTMatrixHandle, 1, false, stMatrixIn, 0)
        GLES20.glUniform1f(uOpacityHandle, opacity)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, videoOesTextureId)
        GLES20.glUniform1i(sVideoTextureHandle, 0)

        if (alphaOesTextureId != null && alphaOesTextureId != 0) {
            GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, alphaOesTextureId)
            GLES20.glUniform1i(sAlphaTextureHandle, 1)
            GLES20.glUniform1i(uHasAlphaHandle, 1)
        } else {
            GLES20.glUniform1i(uHasAlphaHandle, 0)
        }

        // Disable Cull Face and Depth Test so inside-facing 360 sphere renders completely
        GLES20.glDisable(GLES20.GL_CULL_FACE)
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)

        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)

        vertexBuffer?.position(0)
        GLES20.glVertexAttribPointer(aPositionHandle, 3, GLES20.GL_FLOAT, false, 12, vertexBuffer)
        GLES20.glEnableVertexAttribArray(aPositionHandle)

        texCoordBuffer?.position(0)
        GLES20.glVertexAttribPointer(aTexCoordHandle, 2, GLES20.GL_FLOAT, false, 8, texCoordBuffer)
        GLES20.glEnableVertexAttribArray(aTexCoordHandle)

        indexBuffer?.position(0)
        GLES20.glDrawElements(GLES20.GL_TRIANGLES, indexCount, GLES20.GL_UNSIGNED_SHORT, indexBuffer)

        GLES20.glDisableVertexAttribArray(aPositionHandle)
        GLES20.glDisableVertexAttribArray(aTexCoordHandle)
        GLES20.glDisable(GLES20.GL_BLEND)
    }

    private fun createProgram(vertexSource: String, fragmentSource: String): Int {
        val vShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexSource)
        val fShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentSource)

        val p = GLES20.glCreateProgram()
        GLES20.glAttachShader(p, vShader)
        GLES20.glAttachShader(p, fShader)
        GLES20.glLinkProgram(p)

        val linkStatus = IntArray(1)
        GLES20.glGetProgramiv(p, GLES20.GL_LINK_STATUS, linkStatus, 0)
        if (linkStatus[0] != GLES20.GL_TRUE) {
            Log.e(TAG, "Could not link 360 sphere GL program: ${GLES20.glGetProgramInfoLog(p)}")
            GLES20.glDeleteProgram(p)
            return 0
        }
        return p
    }

    private fun loadShader(type: Int, shaderCode: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, shaderCode)
        GLES20.glCompileShader(shader)

        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            Log.e(TAG, "Could not compile 360 shader type $type: ${GLES20.glGetShaderInfoLog(shader)}")
            GLES20.glDeleteShader(shader)
            return 0
        }
        return shader
    }
}
