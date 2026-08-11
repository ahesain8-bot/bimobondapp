package com.dubai.bimobondapp.camera_engine

import android.opengl.GLES20
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Phase 7 Makeup — GPU region masks + color blending.
 *
 * Masks (lips / eyes / brows / cheeks / skin) come from landmarks as soft ellipses.
 * No full-frame Bitmap painting.
 */
class MakeupEffect(
    override val id: String = "makeup",
) : MakeupShaderEffect, EffectRenderer {

    @Volatile
    override var enabled: Boolean = false

    @Volatile
    override var intensity: Float = 1f
        set(value) {
            field = value.coerceIn(0f, 1f)
        }

    @Volatile
    private var params: MakeupParameters = MakeupParameters()

    @Volatile
    private var regions: MakeupFaceRegions = MakeupFaceRegions.EMPTY

    private var program = 0
    private var aPosition = -1
    private var aTexCoord = -1
    private var uTexture = -1
    private var uLipstick = -1
    private var uBlush = -1
    private var uEyeliner = -1
    private var uEyeshadow = -1
    private var uLipColor = -1
    private var uBlushColor = -1
    private var uLinerColor = -1
    private var uShadowColor = -1
    private var uHasFace = -1
    private var uSkin = -1
    private var uLips = -1
    private var uCheekL = -1
    private var uCheekR = -1
    private var uEyeL = -1
    private var uEyeR = -1
    private var uBrowL = -1
    private var uBrowR = -1

    private val vertexBuffer: FloatBuffer = floatBufferOf(
        -1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f,
    )
    private val texBuffer: FloatBuffer = floatBufferOf(
        0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f,
    )

    fun setParameters(next: MakeupParameters) {
        params = next.clamped()
        enabled = params.isVisuallyActive()
    }

    fun getParameters(): MakeupParameters = params

    fun setRegions(next: MakeupFaceRegions) {
        regions = next
    }

    fun clearRegions() {
        regions = MakeupFaceRegions.EMPTY
    }

    fun ensureProgram() {
        if (program != 0) return
        program = buildProgram(VERTEX, FRAGMENT)
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTexture = GLES20.glGetUniformLocation(program, "uTexture")
        uLipstick = GLES20.glGetUniformLocation(program, "uLipstick")
        uBlush = GLES20.glGetUniformLocation(program, "uBlush")
        uEyeliner = GLES20.glGetUniformLocation(program, "uEyeliner")
        uEyeshadow = GLES20.glGetUniformLocation(program, "uEyeshadow")
        uLipColor = GLES20.glGetUniformLocation(program, "uLipColor")
        uBlushColor = GLES20.glGetUniformLocation(program, "uBlushColor")
        uLinerColor = GLES20.glGetUniformLocation(program, "uLinerColor")
        uShadowColor = GLES20.glGetUniformLocation(program, "uShadowColor")
        uHasFace = GLES20.glGetUniformLocation(program, "uHasFace")
        uSkin = GLES20.glGetUniformLocation(program, "uSkin")
        uLips = GLES20.glGetUniformLocation(program, "uLips")
        uCheekL = GLES20.glGetUniformLocation(program, "uCheekL")
        uCheekR = GLES20.glGetUniformLocation(program, "uCheekR")
        uEyeL = GLES20.glGetUniformLocation(program, "uEyeL")
        uEyeR = GLES20.glGetUniformLocation(program, "uEyeR")
        uBrowL = GLES20.glGetUniformLocation(program, "uBrowL")
        uBrowR = GLES20.glGetUniformLocation(program, "uBrowR")
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
        if (!params.isVisuallyActive()) return
        ensureProgram()
        val p = params
        val r = regions

        GLES20.glViewport(0, 0, width, height)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glUseProgram(program)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture2dId)
        GLES20.glUniform1i(uTexture, 0)

        GLES20.glUniform1f(uLipstick, p.lipstick)
        GLES20.glUniform1f(uBlush, p.blush)
        GLES20.glUniform1f(uEyeliner, p.eyeliner)
        GLES20.glUniform1f(uEyeshadow, p.eyeshadow)
        GLES20.glUniform3fv(uLipColor, 1, p.lipstickColor, 0)
        GLES20.glUniform3fv(uBlushColor, 1, p.blushColor, 0)
        GLES20.glUniform3fv(uLinerColor, 1, p.eyelinerColor, 0)
        GLES20.glUniform3fv(uShadowColor, 1, p.eyeshadowColor, 0)

        GLES20.glUniform1i(uHasFace, if (r.hasFace) 1 else 0)
        GLES20.glUniform4fv(uSkin, 1, r.skin, 0)
        GLES20.glUniform4fv(uLips, 1, r.lips, 0)
        GLES20.glUniform3fv(uCheekL, 1, r.cheekL, 0)
        GLES20.glUniform3fv(uCheekR, 1, r.cheekR, 0)
        GLES20.glUniform4fv(uEyeL, 1, r.eyeL, 0)
        GLES20.glUniform4fv(uEyeR, 1, r.eyeR, 0)
        GLES20.glUniform4fv(uBrowL, 1, r.browL, 0)
        GLES20.glUniform4fv(uBrowR, 1, r.browR, 0)

        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 0, vertexBuffer)
        GLES20.glEnableVertexAttribArray(aTexCoord)
        GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 0, texBuffer)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }

    override fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        regions = MakeupFaceRegions.EMPTY
    }

    companion object {
        private const val TAG = "MakeupEffect"

        private const val VERTEX = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vUv;
            void main() {
              gl_Position = aPosition;
              vUv = aTexCoord;
            }
        """

        private const val FRAGMENT = """
            precision mediump float;
            uniform sampler2D uTexture;
            uniform float uLipstick;
            uniform float uBlush;
            uniform float uEyeliner;
            uniform float uEyeshadow;
            uniform vec3 uLipColor;
            uniform vec3 uBlushColor;
            uniform vec3 uLinerColor;
            uniform vec3 uShadowColor;
            uniform int uHasFace;
            uniform vec4 uSkin;
            uniform vec4 uLips;
            uniform vec3 uCheekL;
            uniform vec3 uCheekR;
            uniform vec4 uEyeL;
            uniform vec4 uEyeR;
            uniform vec4 uBrowL;
            uniform vec4 uBrowR;
            varying vec2 vUv;

            float softEllipse(vec2 uv, vec2 c, vec2 r) {
              vec2 d = (uv - c) / max(r, vec2(0.001));
              float v = 1.0 - dot(d, d);
              return smoothstep(0.0, 0.55, v);
            }

            float softCircle(vec2 uv, vec2 c, float r) {
              float d = length(uv - c) / max(r, 0.001);
              return 1.0 - smoothstep(0.55, 1.1, d);
            }

            // Ring for eyeliner: between inner and outer eye ellipse.
            float softRing(vec2 uv, vec4 eye) {
              float outer = softEllipse(uv, eye.xy, eye.zw * 1.25);
              float inner = softEllipse(uv, eye.xy, eye.zw * 0.72);
              return clamp(outer - inner, 0.0, 1.0);
            }

            // Eyeshadow band between brow and eye.
            float shadowBand(vec2 uv, vec4 eye, vec4 brow) {
              float eyeM = softEllipse(uv, eye.xy, eye.zw * 1.15);
              float browM = softEllipse(uv, brow.xy, brow.zw * 1.1);
              float midY = (eye.y + brow.y) * 0.5;
              float band = softEllipse(uv, vec2(eye.x, midY), vec2(eye.z * 1.2, abs(eye.y - brow.y) * 0.85 + 0.01));
              return clamp(band * (1.0 - eyeM * 0.65) * max(browM, 0.35), 0.0, 1.0);
            }

            vec3 softLight(vec3 base, vec3 blend, float w) {
              vec3 mixed = mix(base, blend, w);
              return mix(base, mixed, w);
            }

            vec3 multiplyBlend(vec3 base, vec3 blend, float w) {
              return mix(base, base * blend, w);
            }

            void main() {
              vec3 src = texture2D(uTexture, vUv).rgb;
              if (uHasFace == 0) {
                gl_FragColor = vec4(src, 1.0);
                return;
              }

              float skin = softEllipse(vUv, uSkin.xy, uSkin.zw);
              float lips = softEllipse(vUv, uLips.xy, uLips.zw);
              float cheek = max(
                softCircle(vUv, uCheekL.xy, uCheekL.z),
                softCircle(vUv, uCheekR.xy, uCheekR.z)
              ) * skin;

              float liner = max(softRing(vUv, uEyeL), softRing(vUv, uEyeR));
              float shadow = max(
                shadowBand(vUv, uEyeL, uBrowL),
                shadowBand(vUv, uEyeR, uBrowR)
              );

              vec3 color = src;

              // Blush on cheeks (skin-gated).
              float blushW = cheek * uBlush * 0.85;
              color = mix(color, mix(color, uBlushColor, 0.65), blushW);

              // Eyeshadow between brow and lid.
              float shadowW = shadow * uEyeshadow * 0.75;
              color = mix(color, mix(color, uShadowColor, 0.7), shadowW);

              // Eyeliner ring.
              float linerW = liner * uEyeliner * 0.9;
              color = mix(color, uLinerColor, linerW);

              // Lipstick — multiply then soft lift.
              float lipW = lips * uLipstick * 0.95;
              vec3 lip = multiplyBlend(color, uLipColor * 1.15, lipW * 0.85);
              color = mix(color, lip, lipW);

              gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
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
                throw IllegalStateException("makeup shader link failed")
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
                throw IllegalStateException("makeup shader compile failed: $log")
            }
            return shader
        }
    }
}
