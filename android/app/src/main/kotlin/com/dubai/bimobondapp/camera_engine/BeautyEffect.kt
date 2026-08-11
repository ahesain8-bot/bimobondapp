package com.dubai.bimobondapp.camera_engine

import android.opengl.GLES20
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Phase 5 Beauty Engine — GPU-only, face/skin masked.
 *
 * Does **not** blur the full frame. Skin smooth / tone / sharpen / eyes are
 * weighted by a soft face ellipse × YCbCr skin probability, with eye regions
 * protected for smoothing and boosted for eye enhancement.
 */
class BeautyEffect(
    override val id: String = "beauty_engine",
) : BeautyShaderEffect, EffectRenderer {

    @Volatile
    override var enabled: Boolean = true

    @Volatile
    override var intensity: Float = 1f
        set(value) {
            field = value.coerceIn(0f, 1f)
        }

    @Volatile
    private var params: BeautyParameters = BeautyParameters()

    @Volatile
    private var mask: BeautyFaceMask = BeautyFaceMask.EMPTY

    private var program = 0
    private var aPosition = -1
    private var aTexCoord = -1
    private var uTexture = -1
    private var uTexel = -1
    private var uSkinSmooth = -1
    private var uBrightness = -1
    private var uSkinTone = -1
    private var uSharpen = -1
    private var uEyeEnhance = -1
    private var uFaceCount = -1
    private var uFaces = -1
    private var uEyeL = -1
    private var uEyeR = -1

    private val vertexBuffer: FloatBuffer = floatBufferOf(
        -1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f,
    )
    private val texBuffer: FloatBuffer = floatBufferOf(
        0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f,
    )

    private val eyeLUpload = FloatArray(BeautyFaceMask.MAX_FACES * 3)
    private val eyeRUpload = FloatArray(BeautyFaceMask.MAX_FACES * 3)

    fun setParameters(next: BeautyParameters) {
        params = next.clamped()
        enabled = params.enabled && params.isVisuallyActive()
    }

    fun getParameters(): BeautyParameters = params

    fun setFaceMask(next: BeautyFaceMask) {
        mask = next
    }

    fun clearFaceMask() {
        mask = BeautyFaceMask.EMPTY
    }

    fun ensureProgram() {
        if (program != 0) return
        program = buildProgram(VERTEX, FRAGMENT)
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTexture = GLES20.glGetUniformLocation(program, "uTexture")
        uTexel = GLES20.glGetUniformLocation(program, "uTexel")
        uSkinSmooth = GLES20.glGetUniformLocation(program, "uSkinSmooth")
        uBrightness = GLES20.glGetUniformLocation(program, "uBrightness")
        uSkinTone = GLES20.glGetUniformLocation(program, "uSkinTone")
        uSharpen = GLES20.glGetUniformLocation(program, "uSharpen")
        uEyeEnhance = GLES20.glGetUniformLocation(program, "uEyeEnhance")
        uFaceCount = GLES20.glGetUniformLocation(program, "uFaceCount")
        uFaces = GLES20.glGetUniformLocation(program, "uFaces")
        uEyeL = GLES20.glGetUniformLocation(program, "uEyeL")
        uEyeR = GLES20.glGetUniformLocation(program, "uEyeR")
    }

    /**
     * Draws beauty from a 2D texture (FBO color attachment) onto the current framebuffer.
     * [oesTextureId] / [transformMatrix] are unused — signature matches [EffectRenderer].
     */
    override fun draw(
        oesTextureId: Int,
        width: Int,
        height: Int,
        transformMatrix: FloatArray,
    ) {
        // Prefer the dedicated entry point.
        drawFromTexture(oesTextureId, width, height)
    }

    fun drawFromTexture(texture2dId: Int, width: Int, height: Int) {
        if (!params.enabled || !params.isVisuallyActive()) {
            // Passthrough copy when inactive (caller may skip this entirely).
            return
        }
        ensureProgram()
        val p = params

        GLES20.glViewport(0, 0, width, height)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glUseProgram(program)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture2dId)
        GLES20.glUniform1i(uTexture, 0)
        GLES20.glUniform2f(uTexel, 1f / width.coerceAtLeast(1), 1f / height.coerceAtLeast(1))

        GLES20.glUniform1f(uSkinSmooth, p.skinSmooth)
        GLES20.glUniform1f(uBrightness, p.brightness)
        GLES20.glUniform1f(uSkinTone, p.skinTone)
        GLES20.glUniform1f(uSharpen, p.sharpen)
        GLES20.glUniform1f(uEyeEnhance, p.eyeEnhancement)

        val m = mask
        GLES20.glUniform1i(uFaceCount, m.faceCount)
        GLES20.glUniform4fv(uFaces, BeautyFaceMask.MAX_FACES, m.faces, 0)
        for (i in 0 until BeautyFaceMask.MAX_FACES) {
            eyeLUpload[i * 3] = m.eyes[i * 6]
            eyeLUpload[i * 3 + 1] = m.eyes[i * 6 + 1]
            eyeLUpload[i * 3 + 2] = m.eyes[i * 6 + 2]
            eyeRUpload[i * 3] = m.eyes[i * 6 + 3]
            eyeRUpload[i * 3 + 1] = m.eyes[i * 6 + 4]
            eyeRUpload[i * 3 + 2] = m.eyes[i * 6 + 5]
        }
        GLES20.glUniform3fv(uEyeL, BeautyFaceMask.MAX_FACES, eyeLUpload, 0)
        GLES20.glUniform3fv(uEyeR, BeautyFaceMask.MAX_FACES, eyeRUpload, 0)

        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(aTexCoord)
        GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 0, texBuffer)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }

    /** Copies texture2d → current FB without beauty (identity). */
    fun drawPassthrough(texture2dId: Int, width: Int, height: Int) {
        ensurePassthrough()
        GLES20.glViewport(0, 0, width, height)
        GLES20.glUseProgram(passthroughProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture2dId)
        GLES20.glUniform1i(ptTexture, 0)
        GLES20.glEnableVertexAttribArray(ptPosition)
        GLES20.glVertexAttribPointer(ptPosition, 2, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(ptTexCoord)
        GLES20.glVertexAttribPointer(ptTexCoord, 2, GLES20.GL_FLOAT, false, 0, texBuffer)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(ptPosition)
        GLES20.glDisableVertexAttribArray(ptTexCoord)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }

    private var passthroughProgram = 0
    private var ptPosition = -1
    private var ptTexCoord = -1
    private var ptTexture = -1

    private fun ensurePassthrough() {
        if (passthroughProgram != 0) return
        passthroughProgram = buildProgram(VERTEX, PASSTHROUGH_FRAGMENT)
        ptPosition = GLES20.glGetAttribLocation(passthroughProgram, "aPosition")
        ptTexCoord = GLES20.glGetAttribLocation(passthroughProgram, "aTexCoord")
        ptTexture = GLES20.glGetUniformLocation(passthroughProgram, "uTexture")
    }

    override fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        if (passthroughProgram != 0) {
            GLES20.glDeleteProgram(passthroughProgram)
            passthroughProgram = 0
        }
        mask = BeautyFaceMask.EMPTY
    }

    companion object {
        private const val TAG = "BeautyEffect"

        private const val VERTEX = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vUv;
            void main() {
              gl_Position = aPosition;
              vUv = aTexCoord;
            }
        """

        private const val PASSTHROUGH_FRAGMENT = """
            precision mediump float;
            uniform sampler2D uTexture;
            varying vec2 vUv;
            void main() {
              gl_FragColor = texture2D(uTexture, vUv);
            }
        """

        private const val FRAGMENT = """
            precision mediump float;
            uniform sampler2D uTexture;
            uniform vec2 uTexel;
            uniform float uSkinSmooth;
            uniform float uBrightness;
            uniform float uSkinTone;
            uniform float uSharpen;
            uniform float uEyeEnhance;
            uniform int uFaceCount;
            uniform vec4 uFaces[2];
            uniform vec3 uEyeL[2];
            uniform vec3 uEyeR[2];
            varying vec2 vUv;

            float softEllipse(vec2 uv, vec2 c, vec2 r) {
              vec2 d = (uv - c) / max(r, vec2(0.001));
              float v = 1.0 - dot(d, d);
              return smoothstep(0.0, 0.45, v);
            }

            float softCircle(vec2 uv, vec2 c, float r) {
              float d = length(uv - c) / max(r, 0.001);
              return 1.0 - smoothstep(0.65, 1.15, d);
            }

            float skinProb(vec3 rgb) {
              float y  = 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b;
              float cb = 0.5 + (rgb.b - y) * 0.564;
              float cr = 0.5 + (rgb.r - y) * 0.713;
              float cbW = 1.0 - smoothstep(0.10, 0.0, abs(cb - 0.45) - 0.12);
              float crW = 1.0 - smoothstep(0.10, 0.0, abs(cr - 0.58) - 0.12);
              float yW  = smoothstep(0.12, 0.28, y) * (1.0 - smoothstep(0.92, 1.0, y));
              return clamp(cbW * crW * yW, 0.0, 1.0);
            }

            vec3 boxBlur(vec2 uv) {
              vec3 sum = vec3(0.0);
              sum += texture2D(uTexture, uv).rgb * 0.20;
              sum += texture2D(uTexture, uv + vec2( uTexel.x * 2.5, 0.0)).rgb * 0.12;
              sum += texture2D(uTexture, uv + vec2(-uTexel.x * 2.5, 0.0)).rgb * 0.12;
              sum += texture2D(uTexture, uv + vec2(0.0,  uTexel.y * 2.5)).rgb * 0.12;
              sum += texture2D(uTexture, uv + vec2(0.0, -uTexel.y * 2.5)).rgb * 0.12;
              sum += texture2D(uTexture, uv + vec2( uTexel.x * 2.0,  uTexel.y * 2.0)).rgb * 0.08;
              sum += texture2D(uTexture, uv + vec2(-uTexel.x * 2.0,  uTexel.y * 2.0)).rgb * 0.08;
              sum += texture2D(uTexture, uv + vec2( uTexel.x * 2.0, -uTexel.y * 2.0)).rgb * 0.08;
              sum += texture2D(uTexture, uv + vec2(-uTexel.x * 2.0, -uTexel.y * 2.0)).rgb * 0.08;
              return sum;
            }

            float faceMask(vec2 uv) {
              float m = 0.0;
              if (uFaceCount > 0) {
                m = max(m, softEllipse(uv, uFaces[0].xy, uFaces[0].zw));
              }
              if (uFaceCount > 1) {
                m = max(m, softEllipse(uv, uFaces[1].xy, uFaces[1].zw));
              }
              return m;
            }

            float eyeMask(vec2 uv) {
              float m = 0.0;
              if (uFaceCount > 0) {
                m = max(m, softCircle(uv, uEyeL[0].xy, uEyeL[0].z));
                m = max(m, softCircle(uv, uEyeR[0].xy, uEyeR[0].z));
              }
              if (uFaceCount > 1) {
                m = max(m, softCircle(uv, uEyeL[1].xy, uEyeL[1].z));
                m = max(m, softCircle(uv, uEyeR[1].xy, uEyeR[1].z));
              }
              return m;
            }

            void main() {
              vec3 src = texture2D(uTexture, vUv).rgb;
              float face = faceMask(vUv);
              float eyes = eyeMask(vUv);
              float skin = skinProb(src);

              // Regional weight: face ∩ skin, protect eyes from heavy smooth.
              float region = face * mix(skin, 1.0, 0.35);
              float smoothW = region * (1.0 - eyes * 0.85) * uSkinSmooth;

              vec3 blurred = boxBlur(vUv);
              vec3 color = mix(src, blurred, clamp(smoothW, 0.0, 0.85));

              // Skin tone: slight lift + warm / desaturate toward healthy look (face only).
              float toneW = region * uSkinTone;
              float luma = dot(color, vec3(0.299, 0.587, 0.114));
              vec3 warm = vec3(luma * 1.05, luma * 0.98, luma * 0.94);
              warm = mix(warm, color * vec3(1.06, 1.01, 0.96), 0.55);
              warm = clamp(warm + 0.04, 0.0, 1.0);
              color = mix(color, warm, clamp(toneW, 0.0, 1.0));

              // Brightness: mild global + stronger open on face.
              float brightAmt = uBrightness * (0.30 + 0.70 * face);
              color = clamp(color + brightAmt * 0.22, 0.0, 1.0);

              // Sharpen on face only (unsharp), reduced where we heavily smoothed.
              float sharpW = face * uSharpen * (1.0 - smoothW * 0.55);
              color = clamp(color + (src - blurred) * sharpW * 1.35, 0.0, 1.0);

              // Eye enhancement: local lift + contrast in eye ellipses.
              float eyeW = eyes * uEyeEnhance;
              float eyeLuma = dot(color, vec3(0.299, 0.587, 0.114));
              vec3 eyeCol = (color - eyeLuma) * (1.0 + 0.35 * uEyeEnhance) + eyeLuma;
              eyeCol = clamp(eyeCol + 0.06 * uEyeEnhance, 0.0, 1.0);
              color = mix(color, eyeCol, clamp(eyeW, 0.0, 1.0));

              gl_FragColor = vec4(color, 1.0);
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
                throw IllegalStateException("beauty shader link failed: $log")
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
                throw IllegalStateException("beauty shader compile failed: $log")
            }
            return shader
        }
    }
}
