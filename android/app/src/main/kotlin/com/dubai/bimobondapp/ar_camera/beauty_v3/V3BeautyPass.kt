package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.opengl.GLES20
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Phase 1 — GPU beauty base on canonical RGBA (face-masked).
 * Skin smooth + tone + under-eye soften; preserves eye/brow/lip/hair edges via
 * skin probability × face ellipse × eye protect.
 */
internal class V3BeautyPass {
    private var program = 0
    private var aPos = 0
    private var aUv = 0
    private var uTex = 0
    private var uTexel = 0
    private var uSmooth = 0
    private var uTone = 0
    private var uBright = 0
    private var uUnderEye = 0
    private var uSharpen = 0
    private var uFace = 0
    private var uEyeL = 0
    private var uEyeR = 0
    private var uUnderL = 0
    private var uUnderR = 0

    private val anchors = FloatArray(V3FaceRegionState.ANCHOR_FLOATS)
    private val quad: FloatBuffer = ByteBuffer
        .allocateDirect(4 * 4 * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .also {
            it.put(
                floatArrayOf(
                    -1f, -1f, 0f, 0f,
                    1f, -1f, 1f, 0f,
                    -1f, 1f, 0f, 1f,
                    1f, 1f, 1f, 1f,
                ),
            )
            it.position(0)
        }

    fun ensureProgram(): Boolean {
        if (program != 0) return true
        program = V3GlProgram.build(VS, FS)
        if (program == 0) return false
        aPos = GLES20.glGetAttribLocation(program, "aPosition")
        aUv = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTex = GLES20.glGetUniformLocation(program, "uTexture")
        uTexel = GLES20.glGetUniformLocation(program, "uTexel")
        uSmooth = GLES20.glGetUniformLocation(program, "uSmooth")
        uTone = GLES20.glGetUniformLocation(program, "uTone")
        uBright = GLES20.glGetUniformLocation(program, "uBright")
        uUnderEye = GLES20.glGetUniformLocation(program, "uUnderEye")
        uSharpen = GLES20.glGetUniformLocation(program, "uSharpen")
        uFace = GLES20.glGetUniformLocation(program, "uFace")
        uEyeL = GLES20.glGetUniformLocation(program, "uEyeL")
        uEyeR = GLES20.glGetUniformLocation(program, "uEyeR")
        uUnderL = GLES20.glGetUniformLocation(program, "uUnderL")
        uUnderR = GLES20.glGetUniformLocation(program, "uUnderR")
        return true
    }

    /**
     * Reads [srcTexId], writes into [dest] FBO. Returns false if skipped.
     */
    fun draw(srcTexId: Int, dest: V3CanonicalTarget, contract: V3FrameContract): Boolean {
        if (!V3BeautyConfig.beautyActive()) return false
        if (srcTexId == 0 || !ensureProgram()) return false
        if (!dest.ensure(contract.canonicalWidth, contract.canonicalHeight)) return false
        if (!V3FaceRegionState.copyBeautyAnchors(anchors)) return false

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, dest.fboId)
        GLES20.glViewport(0, 0, dest.width, dest.height)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glUseProgram(program)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, srcTexId)
        GLES20.glUniform1i(uTex, 0)
        GLES20.glUniform2f(uTexel, 1f / dest.width.coerceAtLeast(1), 1f / dest.height.coerceAtLeast(1))
        GLES20.glUniform1f(uSmooth, V3BeautyConfig.skinSmooth())
        GLES20.glUniform1f(uTone, V3BeautyConfig.skinTone())
        GLES20.glUniform1f(uBright, V3BeautyConfig.brighten())
        GLES20.glUniform1f(uUnderEye, V3BeautyConfig.underEye())
        GLES20.glUniform1f(uSharpen, V3BeautyConfig.sharpen())

        val fw = anchors[0]
        val fh = anchors[1]
        GLES20.glUniform4f(uFace, anchors[2], anchors[3], fw * 0.52f, fh * 0.62f)
        GLES20.glUniform3f(uEyeL, anchors[4], anchors[5], anchors[6] * 1.15f)
        GLES20.glUniform3f(uEyeR, anchors[7], anchors[8], anchors[9] * 1.15f)
        GLES20.glUniform3f(uUnderL, anchors[10], anchors[11], anchors[6] * 1.35f)
        GLES20.glUniform3f(uUnderR, anchors[12], anchors[13], anchors[9] * 1.35f)

        drawQuad()
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        return true
    }

    private fun drawQuad() {
        quad.position(0)
        GLES20.glEnableVertexAttribArray(aPos)
        GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 16, quad)
        quad.position(2)
        GLES20.glEnableVertexAttribArray(aUv)
        GLES20.glVertexAttribPointer(aUv, 2, GLES20.GL_FLOAT, false, 16, quad)
        quad.position(0)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(aPos)
        GLES20.glDisableVertexAttribArray(aUv)
    }

    fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
    }

    fun forgetHandles() {
        program = 0
    }

    companion object {
        private const val VS = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vUv;
            void main() {
                gl_Position = aPosition;
                vUv = aTexCoord;
            }
        """

        private const val FS = """
            precision mediump float;
            varying vec2 vUv;
            uniform sampler2D uTexture;
            uniform vec2 uTexel;
            uniform float uSmooth;
            uniform float uTone;
            uniform float uBright;
            uniform float uUnderEye;
            uniform float uSharpen;
            uniform vec4 uFace;   // cx,cy,rx,ry in canonical UV
            uniform vec3 uEyeL;   // cx,cy,r
            uniform vec3 uEyeR;
            uniform vec3 uUnderL;
            uniform vec3 uUnderR;

            vec2 toSample(vec2 canon) {
                return vec2(canon.x, 1.0 - canon.y);
            }

            float softEllipse(vec2 uv, vec2 c, vec2 r) {
                vec2 d = (uv - c) / max(r, vec2(0.001));
                return smoothstep(0.0, 0.42, 1.0 - dot(d, d));
            }

            float softCircle(vec2 uv, vec2 c, float r) {
                float d = length(uv - c) / max(r, 0.001);
                return 1.0 - smoothstep(0.55, 1.15, d);
            }

            float skinProb(vec3 rgb) {
                float y  = 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b;
                float cb = 0.5 + (rgb.b - y) * 0.564;
                float cr = 0.5 + (rgb.r - y) * 0.713;
                float cbW = 1.0 - smoothstep(0.10, 0.0, abs(cb - 0.45) - 0.13);
                float crW = 1.0 - smoothstep(0.10, 0.0, abs(cr - 0.58) - 0.13);
                float yW  = smoothstep(0.12, 0.28, y) * (1.0 - smoothstep(0.92, 1.0, y));
                return clamp(cbW * crW * yW, 0.0, 1.0);
            }

            // Edge-aware blur: reject neighbors with large luma delta (pores yes, lids/brows no).
            vec3 smartBlur(vec2 sampleUv, float centerY) {
                vec3 sum = texture2D(uTexture, sampleUv).rgb * 0.22;
                float wSum = 0.22;
                for (int i = 0; i < 8; i++) {
                    float ang = float(i) * 0.785398;
                    vec2 off = vec2(cos(ang), sin(ang)) * uTexel * 2.8;
                    vec3 n = texture2D(uTexture, sampleUv + off).rgb;
                    float ny = dot(n, vec3(0.299, 0.587, 0.114));
                    float w = exp(-abs(ny - centerY) * 18.0);
                    sum += n * w * 0.0975;
                    wSum += w * 0.0975;
                }
                return sum / max(wSum, 1e-3);
            }

            void main() {
                // vUv is FBO tex space (origin bottom-left). Canonical UV is top-left.
                vec2 canon = vec2(vUv.x, 1.0 - vUv.y);
                vec2 sampleUv = vUv;
                vec3 src = texture2D(uTexture, sampleUv).rgb;
                float Y = dot(src, vec3(0.299, 0.587, 0.114));

                float face = softEllipse(canon, uFace.xy, uFace.zw);
                float eyes = max(
                    softCircle(canon, uEyeL.xy, uEyeL.z),
                    softCircle(canon, uEyeR.xy, uEyeR.z));
                float under = max(
                    softCircle(canon, uUnderL.xy, uUnderL.z),
                    softCircle(canon, uUnderR.xy, uUnderR.z));
                // Keep iris/lid sharp; allow mild under-eye work below.
                under *= (1.0 - eyes * 0.85);

                float skin = skinProb(src);
                float region = face * mix(skin, 1.0, 0.30);
                float smoothW = region * (1.0 - eyes * 0.90) * uSmooth;

                vec3 blurred = smartBlur(sampleUv, Y);
                vec3 color = mix(src, blurred, clamp(smoothW, 0.0, 0.88));

                // Skin tone: even + slight lift, keep shading.
                float toneW = region * (1.0 - eyes * 0.7) * uTone;
                float luma = dot(color, vec3(0.299, 0.587, 0.114));
                vec3 even = mix(color, vec3(luma), 0.28);
                even = even * vec3(1.03, 1.01, 0.99) + 0.025;
                color = mix(color, clamp(even, 0.0, 1.0), clamp(toneW, 0.0, 0.85));

                float brightAmt = uBright * (0.25 + 0.75 * face) * (1.0 - eyes * 0.5);
                color = clamp(color + brightAmt * 0.20, 0.0, 1.0);

                // Under-eye: soft lift + mild blur (not on eyeball).
                float ue = under * uUnderEye;
                vec3 ueBlur = smartBlur(sampleUv, Y);
                vec3 ueCol = mix(color, ueBlur, 0.45 * ue);
                ueCol = clamp(ueCol + vec3(0.045) * ue, 0.0, 1.0);
                color = mix(color, ueCol, clamp(ue, 0.0, 1.0));

                float sharpW = face * uSharpen * (1.0 - smoothW * 0.6);
                color = clamp(color + (src - blurred) * sharpW * 1.2, 0.0, 1.0);

                gl_FragColor = vec4(color, 1.0);
            }
        """
    }
}
