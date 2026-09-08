package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.opengl.GLES20
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Core Phase 2 — UV liquify reshape (eyes / nose / cheek-jaw) plus optional
 * fixed-topology lip strip mesh filler (not analytical lip UV warp).
 */
internal class V3ReshapePass {
    private var program = 0
    private var aPos = 0
    private var aUv = 0
    private var uTex = 0
    private var uEyes = 0
    private var uNose = 0
    private var uShape = 0
    private var uEyeL = 0
    private var uEyeR = 0
    private var uEyeRad = 0
    private var uNoseL = 0
    private var uNoseR = 0
    private var uNoseRad = 0
    private var uCheekL = 0
    private var uCheekR = 0
    private var uCheekRad = 0
    private var uChin = 0

    private val lipMesh = V3LipMeshWarp()
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
        if (program == 0) {
            program = V3GlProgram.build(VS, FS)
            if (program == 0) return false
            aPos = GLES20.glGetAttribLocation(program, "aPosition")
            aUv = GLES20.glGetAttribLocation(program, "aTexCoord")
            uTex = GLES20.glGetUniformLocation(program, "uTexture")
            uEyes = GLES20.glGetUniformLocation(program, "uEyes")
            uNose = GLES20.glGetUniformLocation(program, "uNose")
            uShape = GLES20.glGetUniformLocation(program, "uShape")
            uEyeL = GLES20.glGetUniformLocation(program, "uEyeL")
            uEyeR = GLES20.glGetUniformLocation(program, "uEyeR")
            uEyeRad = GLES20.glGetUniformLocation(program, "uEyeRadius")
            uNoseL = GLES20.glGetUniformLocation(program, "uNoseL")
            uNoseR = GLES20.glGetUniformLocation(program, "uNoseR")
            uNoseRad = GLES20.glGetUniformLocation(program, "uNoseRadius")
            uCheekL = GLES20.glGetUniformLocation(program, "uCheekL")
            uCheekR = GLES20.glGetUniformLocation(program, "uCheekR")
            uCheekRad = GLES20.glGetUniformLocation(program, "uCheekRadius")
            uChin = GLES20.glGetUniformLocation(program, "uChin")
        }
        return lipMesh.ensureProgram()
    }

    fun draw(srcTexId: Int, dest: V3CanonicalTarget, contract: V3FrameContract): Boolean {
        if (!V3BeautyConfig.reshapeActive()) return false
        if (srcTexId == 0 || !ensureProgram()) return false
        if (!dest.ensure(contract.canonicalWidth, contract.canonicalHeight)) return false

        val haveAnchors = V3FaceRegionState.copyBeautyAnchors(anchors)
        val eyes = if (haveAnchors) V3BeautyConfig.eyes() else 0f
        val nose = if (haveAnchors) V3BeautyConfig.nose() else 0f
        val shape = if (haveAnchors) V3BeautyConfig.shape() else 0f

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, dest.fboId)
        GLES20.glViewport(0, 0, dest.width, dest.height)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glUseProgram(program)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, srcTexId)
        GLES20.glUniform1i(uTex, 0)
        GLES20.glUniform1f(uEyes, eyes)
        GLES20.glUniform1f(uNose, nose)
        GLES20.glUniform1f(uShape, shape)
        if (haveAnchors) {
            GLES20.glUniform2f(uEyeL, anchors[4], anchors[5])
            GLES20.glUniform2f(uEyeR, anchors[7], anchors[8])
            GLES20.glUniform1f(uEyeRad, anchors[6] * 1.05f)
            GLES20.glUniform2f(uNoseL, anchors[14], anchors[15])
            GLES20.glUniform2f(uNoseR, anchors[16], anchors[17])
            GLES20.glUniform1f(uNoseRad, anchors[26])
            GLES20.glUniform2f(uCheekL, anchors[20], anchors[21])
            GLES20.glUniform2f(uCheekR, anchors[22], anchors[23])
            GLES20.glUniform1f(uCheekRad, anchors[27])
            GLES20.glUniform2f(uChin, anchors[24], anchors[25])
        } else {
            GLES20.glUniform2f(uEyeL, 0f, 0f)
            GLES20.glUniform2f(uEyeR, 0f, 0f)
            GLES20.glUniform1f(uEyeRad, 0f)
            GLES20.glUniform2f(uNoseL, 0f, 0f)
            GLES20.glUniform2f(uNoseR, 0f, 0f)
            GLES20.glUniform1f(uNoseRad, 0f)
            GLES20.glUniform2f(uCheekL, 0f, 0f)
            GLES20.glUniform2f(uCheekR, 0f, 0f)
            GLES20.glUniform1f(uCheekRad, 0f)
            GLES20.glUniform2f(uChin, 0f, 0f)
        }

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
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)

        // Lip filler mesh: target geometry + source UVs (no analytical lip field).
        val lipOk = if (V3BeautyConfig.lipFullnessActive()) {
            lipMesh.draw(srcTexId)
        } else {
            false
        }
        return haveAnchors || lipOk
    }

    fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        lipMesh.release()
    }

    fun forgetHandles() {
        program = 0
        lipMesh.forgetHandles()
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
            uniform float uEyes;
            uniform float uNose;
            uniform float uShape;
            uniform vec2 uEyeL;
            uniform vec2 uEyeR;
            uniform float uEyeRadius;
            uniform vec2 uNoseL;
            uniform vec2 uNoseR;
            uniform float uNoseRadius;
            uniform vec2 uCheekL;
            uniform vec2 uCheekR;
            uniform float uCheekRadius;
            uniform vec2 uChin;

            vec2 eyeScale(vec2 uv, vec2 center, float halfW, float amount) {
                if (halfW <= 0.001 || abs(amount) < 0.01) return uv;
                float halfH = halfW * 0.72;
                vec2 d = uv - center;
                float ax = abs(d.x) / max(halfW, 0.001);
                float ay = abs(d.y) / max(halfH, 0.001);
                float w = exp(-(ax * ax * 3.6 + ay * ay * 3.6));
                float scale = 1.0 - amount * 0.42 * w;
                return center + d * scale;
            }

            vec2 wingDisp(vec2 uv, vec2 wing, float shiftX, float radius) {
                if (radius <= 0.001) return uv;
                vec2 d = uv - wing;
                d.y *= 1.70;
                float r2 = dot(d, d) / max(radius * radius, 1e-6);
                float f = exp(-r2 * 4.0);
                return uv - vec2(f * shiftX, 0.0);
            }

            vec2 noseWarp(vec2 uv) {
                if (abs(uNose) < 0.01 || uNoseRadius <= 0.001) return uv;
                float k = 0.28 * uNose;
                float tipX = (uNoseL.x + uNoseR.x) * 0.5;
                float tipY = (uNoseL.y + uNoseR.y) * 0.5;
                float shiftL = (tipX - uNoseL.x) * k;
                float shiftR = (tipX - uNoseR.x) * k;
                float above = tipY - uNoseRadius * 0.55;
                float below = tipY + uNoseRadius * 0.95;
                float yGate = smoothstep(above, tipY - uNoseRadius * 0.05, uv.y) *
                    (1.0 - smoothstep(tipY + uNoseRadius * 0.35, below, uv.y));
                if (yGate < 0.01) return uv;
                uv = wingDisp(uv, uNoseL, shiftL * yGate, uNoseRadius);
                uv = wingDisp(uv, uNoseR, shiftR * yGate, uNoseRadius);
                vec2 td = uv - vec2(tipX, tipY);
                float tw = exp(-dot(td, td) / max(uNoseRadius * uNoseRadius * 0.30, 1e-6));
                uv.x = mix(uv.x, tipX, tw * abs(uNose) * 0.06);
                return uv;
            }

            vec2 cheekPad(vec2 uv, vec2 cheek, float midX, float halfW, float halfH, float amount) {
                if (halfW <= 0.001 || abs(amount) < 0.001) return uv;
                float ax = abs(uv.x - cheek.x) / max(halfW, 0.001);
                float ay = abs(uv.y - cheek.y) / max(halfH, 0.001);
                float towardMid = abs(uv.x - midX) / max(abs(cheek.x - midX), 0.001);
                float centerGate = smoothstep(0.30, 0.60, towardMid);
                float w = exp(-(ax * ax * 2.3 + ay * ay * 1.9)) * centerGate;
                uv.x = midX + (uv.x - midX) * (1.0 - amount * w);
                uv.y = uv.y - amount * w * 0.012 * sign(amount);
                return uv;
            }

            vec2 shapeWarp(vec2 uv) {
                if (abs(uShape) < 0.01 || uCheekRadius <= 0.001) return uv;
                float midX = (uCheekL.x + uCheekR.x) * 0.5;
                float halfW = max(uCheekRadius * 1.15, abs(uCheekR.x - uCheekL.x) * 0.24);
                float halfH = halfW * 1.22;
                float amount = 0.12 * uShape;
                uv = cheekPad(uv, uCheekL, midX, halfW, halfH, amount);
                uv = cheekPad(uv, uCheekR, midX, halfW, halfH, amount);
                vec2 cd = uv - uChin;
                float cw = exp(-(cd.x * cd.x) / max(halfW * halfW * 0.55, 1e-6)
                    - (cd.y * cd.y) / max(halfH * halfH * 0.35, 1e-6));
                uv.x = midX + (uv.x - midX) * (1.0 - amount * 0.55 * cw);
                uv.y = mix(uv.y, uChin.y - abs(uCheekR.y - uCheekL.y) * 0.02, cw * abs(uShape) * 0.08);
                return uv;
            }

            void main() {
                vec2 canon = vec2(vUv.x, 1.0 - vUv.y);
                vec2 uv = canon;
                uv = eyeScale(uv, uEyeL, uEyeRadius, uEyes);
                uv = eyeScale(uv, uEyeR, uEyeRadius, uEyes);
                uv = noseWarp(uv);
                uv = shapeWarp(uv);
                vec2 sampleUv = vec2(clamp(uv.x, 0.0, 1.0), 1.0 - clamp(uv.y, 0.0, 1.0));
                gl_FragColor = texture2D(uTexture, sampleUv);
            }
        """
    }
}
