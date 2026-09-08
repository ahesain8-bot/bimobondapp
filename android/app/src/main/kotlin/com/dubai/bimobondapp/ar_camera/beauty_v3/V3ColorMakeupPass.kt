package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.opengl.GLES20
import android.os.SystemClock
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Production stage: fused global color/light + eye brighten + makeup base.
 *
 * Order inside the shader: grade → foundation → contour → blush → lipstick →
 * under-eye (makeup) → eye brighten.
 * Runs after reshape so regions track liquified face geometry.
 */
internal class V3ColorMakeupPass {
    private var program = 0
    private var aPos = 0
    private var aUv = 0
    private var uTex = 0

    // Color grade
    private var uContrast = 0
    private var uSaturation = 0
    private var uBrightness = 0
    private var uExposure = 0
    private var uWarmth = 0
    private var uHighlights = 0
    private var uShadows = 0

    // Local eyes
    private var uBrightEye = 0
    private var uUnderEye = 0
    private var uEyeL = 0
    private var uEyeR = 0
    private var uEyeRad = 0

    // Makeup
    private var uLip = 0
    private var uLipColor = 0
    private var uLipMask = 0
    private var uFoundation = 0
    private var uFoundationColor = 0
    private var uContour = 0
    private var uBlush = 0
    private var uBlushColor = 0
    private var uMouth = 0
    private var uTooth = 0
    private var uBlushL = 0
    private var uBlushR = 0
    private var uBlushRad = 0
    private var uNoseL = 0
    private var uNoseR = 0
    private var uNoseRad = 0
    private var uFace = 0

    private val anchors = FloatArray(V3FaceRegionState.ANCHOR_FLOATS)
    private val lipMaskPass = V3LipMaskPass()
    private var linkedShaderVersion = -1

    // Lightly eased uniforms to avoid slider/shade flicker (GL thread only).
    // [0..12] strengths, [13..15] foundation shade RGB.
    private val eased = FloatArray(16)
    private var easedInit = false

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
        if (program != 0 && linkedShaderVersion == SHADER_VERSION) return true
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        program = V3GlProgram.build(VS, FS)
        if (program == 0) return false
        linkedShaderVersion = SHADER_VERSION
        aPos = GLES20.glGetAttribLocation(program, "aPosition")
        aUv = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTex = GLES20.glGetUniformLocation(program, "uTexture")
        uContrast = GLES20.glGetUniformLocation(program, "uContrast")
        uSaturation = GLES20.glGetUniformLocation(program, "uSaturation")
        uBrightness = GLES20.glGetUniformLocation(program, "uBrightness")
        uExposure = GLES20.glGetUniformLocation(program, "uExposure")
        uWarmth = GLES20.glGetUniformLocation(program, "uWarmth")
        uHighlights = GLES20.glGetUniformLocation(program, "uHighlights")
        uShadows = GLES20.glGetUniformLocation(program, "uShadows")
        uBrightEye = GLES20.glGetUniformLocation(program, "uBrightEye")
        uUnderEye = GLES20.glGetUniformLocation(program, "uUnderEye")
        uEyeL = GLES20.glGetUniformLocation(program, "uEyeL")
        uEyeR = GLES20.glGetUniformLocation(program, "uEyeR")
        uEyeRad = GLES20.glGetUniformLocation(program, "uEyeRadius")
        uLip = GLES20.glGetUniformLocation(program, "uLip")
        uLipColor = GLES20.glGetUniformLocation(program, "uLipColor")
        uLipMask = GLES20.glGetUniformLocation(program, "uLipMask")
        uFoundation = GLES20.glGetUniformLocation(program, "uFoundation")
        uFoundationColor = GLES20.glGetUniformLocation(program, "uFoundationColor")
        uContour = GLES20.glGetUniformLocation(program, "uContour")
        uBlush = GLES20.glGetUniformLocation(program, "uBlush")
        uBlushColor = GLES20.glGetUniformLocation(program, "uBlushColor")
        uMouth = GLES20.glGetUniformLocation(program, "uMouth")
        uTooth = GLES20.glGetUniformLocation(program, "uTooth")
        uBlushL = GLES20.glGetUniformLocation(program, "uBlushL")
        uBlushR = GLES20.glGetUniformLocation(program, "uBlushR")
        uBlushRad = GLES20.glGetUniformLocation(program, "uBlushRadius")
        uNoseL = GLES20.glGetUniformLocation(program, "uNoseL")
        uNoseR = GLES20.glGetUniformLocation(program, "uNoseR")
        uNoseRad = GLES20.glGetUniformLocation(program, "uNoseRadius")
        uFace = GLES20.glGetUniformLocation(program, "uFace")
        return true
    }

    fun draw(srcTexId: Int, dest: V3CanonicalTarget, contract: V3FrameContract): Boolean {
        if (!V3BeautyConfig.colorMakeupActive()) return false
        if (srcTexId == 0 || !ensureProgram()) return false
        if (!dest.ensure(contract.canonicalWidth, contract.canonicalHeight)) return false
        val haveAnchors = V3FaceRegionState.copyBeautyAnchors(anchors)

        // Continuous lip mask FBO (replaces strip-quad fragment evaluation).
        val wantLip = V3BeautyConfig.lipstick() > 0.01f
        val haveLipMask = wantLip && lipMaskPass.update(contract)
        val lipMaskTex = if (haveLipMask) lipMaskPass.maskTextureId() else 0

        val foundationShade = V3BeautyConfig.foundationColor()
        val target = floatArrayOf(
            V3BeautyConfig.contrast(),
            V3BeautyConfig.saturation(),
            V3BeautyConfig.brightnessGrade(),
            V3BeautyConfig.exposure(),
            V3BeautyConfig.warmth(),
            V3BeautyConfig.highlights(),
            V3BeautyConfig.shadows(),
            V3BeautyConfig.brightenEye(),
            V3BeautyConfig.makeupUnderEye(),
            V3BeautyConfig.lipstick(),
            V3BeautyConfig.foundation(),
            V3BeautyConfig.contour(),
            V3BeautyConfig.blush(),
            foundationShade[0],
            foundationShade[1],
            foundationShade[2],
        )
        if (!easedInit) {
            target.copyInto(eased)
            easedInit = true
        } else {
            val a = 0.35f
            for (i in target.indices) {
                eased[i] += (target[i] - eased[i]) * a
            }
        }

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, dest.fboId)
        GLES20.glViewport(0, 0, dest.width, dest.height)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glUseProgram(program)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, srcTexId)
        GLES20.glUniform1i(uTex, 0)

        GLES20.glUniform1f(uContrast, eased[0])
        GLES20.glUniform1f(uSaturation, eased[1])
        GLES20.glUniform1f(uBrightness, eased[2])
        GLES20.glUniform1f(uExposure, eased[3])
        GLES20.glUniform1f(uWarmth, eased[4])
        GLES20.glUniform1f(uHighlights, eased[5])
        GLES20.glUniform1f(uShadows, eased[6])
        GLES20.glUniform1f(uBrightEye, if (haveAnchors) eased[7] else 0f)
        GLES20.glUniform1f(uUnderEye, if (haveAnchors) eased[8] else 0f)
        GLES20.glUniform1f(uLip, if (haveLipMask) eased[9] else 0f)
        GLES20.glUniform1f(uFoundation, if (haveAnchors) eased[10] else 0f)
        GLES20.glUniform1f(uContour, if (haveAnchors) eased[11] else 0f)
        GLES20.glUniform1f(uBlush, if (haveAnchors) eased[12] else 0f)

        val lip = V3BeautyConfig.lipTintColor()
        val blush = V3BeautyConfig.blushColor()
        GLES20.glUniform3f(uLipColor, lip[0], lip[1], lip[2])
        GLES20.glUniform3f(uBlushColor, blush[0], blush[1], blush[2])
        GLES20.glUniform3f(uFoundationColor, eased[13], eased[14], eased[15])

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, if (lipMaskTex != 0) lipMaskTex else srcTexId)
        GLES20.glUniform1i(uLipMask, 1)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)

        if (haveAnchors) {
            GLES20.glUniform2f(uEyeL, anchors[4], anchors[5])
            GLES20.glUniform2f(uEyeR, anchors[7], anchors[8])
            GLES20.glUniform1f(uEyeRad, anchors[6])
            GLES20.glUniform4f(uMouth, anchors[28], anchors[29], anchors[30], anchors[31])
            GLES20.glUniform4f(uTooth, anchors[32], anchors[33], anchors[34], anchors[35])
            GLES20.glUniform2f(uBlushL, anchors[36], anchors[37])
            GLES20.glUniform2f(uBlushR, anchors[38], anchors[39])
            GLES20.glUniform1f(uBlushRad, anchors[40])
            GLES20.glUniform2f(uNoseL, anchors[14], anchors[15])
            GLES20.glUniform2f(uNoseR, anchors[16], anchors[17])
            GLES20.glUniform1f(uNoseRad, anchors[26])
            GLES20.glUniform4f(
                uFace,
                anchors[2],
                anchors[3],
                anchors[0] * 0.52f,
                anchors[1] * 0.62f,
            )
        } else {
            GLES20.glUniform2f(uEyeL, 0f, 0f)
            GLES20.glUniform2f(uEyeR, 0f, 0f)
            GLES20.glUniform1f(uEyeRad, 0f)
            GLES20.glUniform4f(uMouth, 0f, 0f, 0f, 0f)
            GLES20.glUniform4f(uTooth, 0f, 0f, 0f, 0f)
            GLES20.glUniform2f(uBlushL, 0f, 0f)
            GLES20.glUniform2f(uBlushR, 0f, 0f)
            GLES20.glUniform1f(uBlushRad, 0f)
            GLES20.glUniform2f(uNoseL, 0f, 0f)
            GLES20.glUniform2f(uNoseR, 0f, 0f)
            GLES20.glUniform1f(uNoseRad, 0f)
            GLES20.glUniform4f(uFace, 0.5f, 0.5f, 0.01f, 0.01f)
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
        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)

        V3BeautyDiagnostics.noteColorMakeupFrame(
            grade = V3BeautyConfig.gradeActive(),
            makeup = V3BeautyConfig.makeupActive(),
            eyes = V3BeautyConfig.eyeLocalActive(),
        )
        return true
    }

    fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        linkedShaderVersion = -1
        lipMaskPass.release()
        easedInit = false
    }

    fun forgetHandles() {
        program = 0
        linkedShaderVersion = -1
        lipMaskPass.forgetHandles()
        easedInit = false
    }

    companion object {
        /** Bump when FS/VS lipstick path changes so ensureProgram relinks. */
        private const val SHADER_VERSION = 3

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
            uniform sampler2D uLipMask;

            uniform float uContrast;
            uniform float uSaturation;
            uniform float uBrightness;
            uniform float uExposure;
            uniform float uWarmth;
            uniform float uHighlights;
            uniform float uShadows;

            uniform float uBrightEye;
            uniform float uUnderEye;
            uniform vec2 uEyeL;
            uniform vec2 uEyeR;
            uniform float uEyeRadius;

            uniform float uLip;
            uniform vec3 uLipColor;
            uniform float uFoundation;
            uniform vec3 uFoundationColor;
            uniform float uContour;
            uniform float uBlush;
            uniform vec3 uBlushColor;
            uniform vec4 uMouth; // cx,cy,halfW,halfH
            uniform vec4 uTooth; // cx,cy,halfW,halfH
            uniform vec2 uBlushL;
            uniform vec2 uBlushR;
            uniform float uBlushRadius;
            uniform vec2 uNoseL;
            uniform vec2 uNoseR;
            uniform float uNoseRadius;
            uniform vec4 uFace; // cx,cy,rx,ry

            float luma(vec3 c) {
                return dot(c, vec3(0.2126, 0.7152, 0.0722));
            }

            float softCircle(vec2 uv, vec2 c, float r) {
                float d = length(uv - c) / max(r, 0.001);
                return 1.0 - smoothstep(0.45, 1.15, d);
            }

            float softEllipse(vec2 uv, vec2 c, vec2 r) {
                vec2 d = (uv - c) / max(r, vec2(0.001));
                return smoothstep(0.0, 0.42, 1.0 - dot(d, d));
            }

            float softEllipseOriented(vec2 uv, vec2 c, vec2 r) {
                vec2 d = (uv - c) / max(r, vec2(0.001));
                float v = 1.0 - dot(d, d);
                return smoothstep(0.0, 0.55, v);
            }


            // Soft teardrop / oval on front cheek, elongated along cheekbone.
            float frontCheekBlush(vec2 uv, vec2 center, float radius, float towardCenterSign) {
                vec2 toMid = vec2(uFace.x - center.x, (uFace.y - center.y) * 0.35);
                float len = length(toMid);
                vec2 along = len > 1e-5 ? toMid / len : vec2(towardCenterSign, 0.0);
                // Cheekbone direction: slightly upward toward temple, but keep center inward.
                along = normalize(vec2(along.x * 0.85 - towardCenterSign * 0.15, along.y - 0.35));
                vec2 perp = vec2(-along.y, along.x);
                vec2 d = uv - center;
                float lx = dot(d, along);
                float ly = dot(d, perp);
                float rx = max(radius * 1.05, 0.001);
                float ry = max(radius * 0.58, 0.001);
                // Soft teardrop: taper slightly toward the ear side (negative along).
                float taper = 1.0 + 0.22 * clamp(-lx / rx, 0.0, 1.0);
                float ell = length(vec2(lx / rx, ly / (ry * taper)));
                return 1.0 - smoothstep(0.42, 1.05, ell);
            }

            // Luminance-preserving cosmetic tint (no flat RGB paint).
            vec3 cosmeticTint(vec3 src, vec3 tint, float amount) {
                float ys = max(luma(src), 1e-3);
                float yt = max(luma(tint), 1e-3);
                vec3 chroma = tint / yt;
                vec3 matched = chroma * ys;
                // Keep source shading / texture; blend chroma then soft re-sat.
                vec3 blended = mix(src, matched, 0.62);
                blended = mix(blended, src * chroma, 0.28);
                return mix(src, clamp(blended, 0.0, 1.0), clamp(amount, 0.0, 1.0));
            }

            // Foundation shade: unify complexion toward selected tone while
            // keeping local luminance (pores / lighting) from the source.
            vec3 foundationShade(vec3 src, vec3 shade, float amount) {
                float ys = max(luma(src), 1e-3);
                float yt = max(luma(shade), 1e-3);
                vec3 matched = shade * (ys / yt);
                // Soft evening of uneven chroma toward shade, not a flat fill.
                vec3 even = mix(src, matched, 0.58);
                even = mix(even, src + (matched - vec3(ys)) * 0.50, 0.42);
                // Re-inject micro texture from source luminance residuals.
                even = mix(even, even + (src - vec3(ys)) * 0.62, 0.38);
                // Mild lift toward shade luminance so deeper/lighter shades read.
                float shadeBias = clamp((yt - ys) * 0.22, -0.06, 0.06);
                even = clamp(even + shadeBias, 0.0, 1.0);
                return mix(src, even, clamp(amount, 0.0, 1.0));
            }

            // Contour shade derived from skin (warm deep tone, not gray dirt).
            vec3 contourShade(vec3 src) {
                float y = luma(src);
                vec3 deep = src * vec3(0.78, 0.62, 0.55);
                deep = mix(deep, vec3(y * 0.72, y * 0.58, y * 0.52), 0.35);
                return clamp(deep, 0.0, 1.0);
            }

            float underEyePad(vec2 uv, vec2 eye, float r) {
                vec2 d = uv - (eye + vec2(0.0, r * 0.72));
                float ax = abs(d.x) / max(r * 1.20, 0.001);
                float ay = abs(d.y) / max(r * 0.68, 0.001);
                float pad = 1.0 - smoothstep(0.35, 1.05, max(ax, ay));
                // Cut brow / lid (above eye) and strong spill toward nose.
                float below = smoothstep(eye.y - r * 0.05, eye.y + r * 0.15, uv.y);
                return pad * below;
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

            // Dark / low-chroma facial hair (beard / mustache) — reduce tint.
            float facialHairProb(vec3 rgb, vec2 canon) {
                float y = luma(rgb);
                float sat = length(rgb - vec3(y));
                float dark = 1.0 - smoothstep(0.16, 0.40, y);
                float lowSat = 1.0 - smoothstep(0.018, 0.095, sat);
                float lower = smoothstep(uFace.y - uFace.w * 0.08, uFace.y + uFace.w * 0.92, canon.y);
                float nearMouth = 0.0;
                if (uMouth.z > 0.001 && uMouth.w > 0.001) {
                    vec2 d = (canon - uMouth.xy) / max(uMouth.zw * vec2(1.55, 1.85), vec2(0.001));
                    nearMouth = 1.0 - smoothstep(0.55, 1.25, length(d));
                }
                return clamp(dark * lowSat * max(lower * 0.85, nearMouth), 0.0, 1.0);
            }

            vec3 applyGrade(vec3 col) {
                float ev = uExposure;
                if (abs(ev) > 0.01) {
                    float lum = max(luma(col), 0.0001);
                    float exponent = pow(2.0, -ev * 0.55);
                    float exposedLum = pow(clamp(lum, 0.0, 1.0), exponent);
                    col = clamp(col * (exposedLum / lum), 0.0, 1.0);
                }
                if (abs(uBrightness) > 0.01) {
                    col = clamp(col + uBrightness * 0.16, 0.0, 1.0);
                }
                if (abs(uWarmth) > 0.01) {
                    float k = uWarmth * 0.12;
                    col.r *= (1.0 + k);
                    col.b *= (1.0 - k);
                }
                float c = uContrast;
                if (abs(c) > 0.01) {
                    if (c > 0.0) {
                        col = (col - 0.5) * (1.0 + c * 0.24) + 0.5;
                    } else {
                        float lum = max(luma(col), 0.0001);
                        float brightW = smoothstep(0.28, 0.88, lum);
                        float resultLum = lum * (1.0 - (-c) * 0.18 * brightW);
                        col = clamp(col * (resultLum / lum), 0.0, 1.0);
                    }
                }
                if (abs(uHighlights) > 0.01) {
                    float l = luma(col);
                    col += uHighlights * (70.0 / 255.0) * (l * l);
                }
                if (abs(uShadows) > 0.01) {
                    float lum = max(luma(col), 0.0001);
                    float shadowW = 1.0 - smoothstep(0.30, 0.72, lum);
                    float exponent = uShadows > 0.0
                        ? 1.0 - uShadows * 0.28
                        : 1.0 + (-uShadows) * 0.32;
                    float curvedLum = pow(clamp(lum, 0.0, 1.0), exponent);
                    float resultLum = mix(lum, curvedLum, shadowW);
                    col = clamp(col * (resultLum / lum), 0.0, 1.0);
                }
                if (abs(uSaturation) > 0.01) {
                    float l = luma(col);
                    float factor = uSaturation >= 0.0
                        ? (1.0 + uSaturation * 0.35)
                        : max(1.0 + uSaturation, 0.0);
                    col = mix(vec3(l), col, factor);
                }
                return clamp(col, 0.0, 1.0);
            }

            void main() {
                vec2 sampleUv = vUv;
                vec2 canon = vec2(vUv.x, 1.0 - vUv.y);
                vec3 col = texture2D(uTexture, sampleUv).rgb;

                col = applyGrade(col);

                float face = softEllipse(canon, uFace.xy, uFace.zw);
                float skin = skinProb(col);
                float eyes = max(
                    softCircle(canon, uEyeL, uEyeRadius * 1.08),
                    softCircle(canon, uEyeR, uEyeRadius * 1.08));
                // Brow / lash band (above + slight on lid) — keep foundation out.
                float brows = max(
                    softCircle(canon, uEyeL + vec2(0.0, -uEyeRadius * 1.15), uEyeRadius * 1.15),
                    softCircle(canon, uEyeR + vec2(0.0, -uEyeRadius * 1.15), uEyeRadius * 1.15));
                float lashes = max(
                    softCircle(canon, uEyeL + vec2(0.0, uEyeRadius * 0.55), uEyeRadius * 0.72),
                    softCircle(canon, uEyeR + vec2(0.0, uEyeRadius * 0.55), uEyeRadius * 0.72));
                float nostrils = 0.0;
                if (uNoseRadius > 0.001) {
                    nostrils = softCircle(canon, (uNoseL + uNoseR) * 0.5 + vec2(0.0, uNoseRadius * 0.35),
                        uNoseRadius * 0.90);
                }
                float teeth = 0.0;
                if (uTooth.z > 0.001 && uTooth.w > 0.001) {
                    teeth = softEllipse(canon, uTooth.xy, uTooth.zw * 1.15);
                }
                float lipKill = 0.0;
                if (uMouth.z > 0.001 && uMouth.w > 0.001) {
                    vec2 d = (canon - uMouth.xy) / max(uMouth.zw * 1.18, vec2(0.001));
                    lipKill = 1.0 - smoothstep(0.50, 1.05, length(d));
                }
                float hairline = 1.0 - softEllipse(canon, uFace.xy, uFace.zw * vec2(0.92, 0.96));
                float beard = facialHairProb(col, canon);

                // Foundation — selected shade on skin only; preserve pores/shading.
                if (uFoundation > 0.01) {
                    float core = softEllipse(canon, uFace.xy, uFace.zw * vec2(0.76, 0.80));
                    float region = max(face * 0.52, core) *
                        mix(0.18, 1.0, skin) *
                        (1.0 - eyes * 0.98) *
                        (1.0 - brows * 0.95) *
                        (1.0 - lashes * 0.70) *
                        (1.0 - lipKill) *
                        (1.0 - teeth) *
                        (1.0 - nostrils * 0.82) *
                        (1.0 - beard * 0.88) *
                        (1.0 - hairline * 0.72);
                    float k = uFoundation * region * 0.78;
                    col = foundationShade(col, uFoundationColor, k);
                }

                // Contour — cheek hollows, jaw, temples, nose sides (skin-tone shade).
                if (uContour > 0.01 && uBlushRadius > 0.001) {
                    // Hollows sit below & slightly outer from blush apples.
                    vec2 hollowL = uBlushL + vec2(-(uBlushR.x - uBlushL.x) * 0.06, uBlushRadius * 0.72);
                    vec2 hollowR = uBlushR + vec2( (uBlushR.x - uBlushL.x) * 0.06, uBlushRadius * 0.72);
                    float hollow = max(
                        softEllipseOriented(canon, hollowL, vec2(uBlushRadius * 0.95, uBlushRadius * 1.25)),
                        softEllipseOriented(canon, hollowR, vec2(uBlushRadius * 0.95, uBlushRadius * 1.25)));
                    // Jawline pads toward chin corners.
                    vec2 jawL = mix(uBlushL, uFace.xy + vec2(-uFace.z * 0.55, uFace.w * 0.55), 0.55);
                    vec2 jawR = mix(uBlushR, uFace.xy + vec2( uFace.z * 0.55, uFace.w * 0.55), 0.55);
                    float jaw = max(
                        softEllipseOriented(canon, jawL, vec2(uBlushRadius * 0.85, uBlushRadius * 1.35)),
                        softEllipseOriented(canon, jawR, vec2(uBlushRadius * 0.85, uBlushRadius * 1.35)));
                    // Temples / outer forehead.
                    vec2 templeL = vec2(uEyeL.x - uEyeRadius * 1.4, uEyeL.y - uEyeRadius * 1.6);
                    vec2 templeR = vec2(uEyeR.x + uEyeRadius * 1.4, uEyeR.y - uEyeRadius * 1.6);
                    float temple = max(
                        softEllipseOriented(canon, templeL, vec2(uEyeRadius * 1.3, uEyeRadius * 1.1)),
                        softEllipseOriented(canon, templeR, vec2(uEyeRadius * 1.3, uEyeRadius * 1.1)));
                    float noseSide = 0.0;
                    if (uNoseRadius > 0.001) {
                        noseSide = max(
                            softEllipseOriented(canon, uNoseL, vec2(uNoseRadius * 0.45, uNoseRadius * 1.1)),
                            softEllipseOriented(canon, uNoseR, vec2(uNoseRadius * 0.45, uNoseRadius * 1.1)));
                    }
                    float mask = max(max(hollow, jaw * 0.85), max(temple * 0.55, noseSide * 0.50));
                    mask *= (1.0 - eyes * 0.95) * (1.0 - brows * 0.7);
                    float contourLipKill = 0.0;
                    if (uMouth.z > 0.001) {
                        vec2 d = (canon - uMouth.xy) / max(uMouth.zw * 1.2, vec2(0.001));
                        contourLipKill = 1.0 - smoothstep(0.6, 1.1, length(d));
                    }
                    mask *= (1.0 - contourLipKill);
                    float k = uContour * mask * 0.68;
                    col = mix(col, contourShade(col), k);
                }

                // Blush — soft oval/teardrop on FRONT cheeks (not ear-side stamps).
                if (uBlush > 0.01 && uBlushRadius > 0.001) {
                    float cheek = max(
                        frontCheekBlush(canon, uBlushL, uBlushRadius, 1.0),
                        frontCheekBlush(canon, uBlushR, uBlushRadius, -1.0));
                    // Keep fully inside face oval; kill eyes / lids / nose / mouth / hairline.
                    float faceClip = softEllipse(canon, uFace.xy, uFace.zw * vec2(0.88, 0.90));
                    float underLid = max(
                        softCircle(canon, uEyeL + vec2(0.0, uEyeRadius * 0.55), uEyeRadius * 0.95),
                        softCircle(canon, uEyeR + vec2(0.0, uEyeRadius * 0.55), uEyeRadius * 0.95));
                    float noseBlock = 0.0;
                    if (uNoseRadius > 0.001) {
                        noseBlock = softEllipseOriented(
                            canon,
                            (uNoseL + uNoseR) * 0.5,
                            vec2(abs(uNoseR.x - uNoseL.x) * 0.72, uNoseRadius * 1.35));
                    }
                    float mouthBlock = 0.0;
                    if (uMouth.z > 0.001 && uMouth.w > 0.001) {
                        vec2 d = (canon - uMouth.xy) / max(uMouth.zw * vec2(1.35, 1.55), vec2(0.001));
                        mouthBlock = 1.0 - smoothstep(0.55, 1.15, length(d));
                    }
                    float outerEdge = 1.0 - softEllipse(canon, uFace.xy, uFace.zw * vec2(0.78, 0.82));
                    cheek *= faceClip;
                    cheek *= (1.0 - eyes * 0.98);
                    cheek *= (1.0 - underLid * 0.85);
                    cheek *= (1.0 - brows * 0.55);
                    cheek *= (1.0 - noseBlock);
                    cheek *= (1.0 - mouthBlock);
                    cheek *= (1.0 - outerEdge * 0.95);
                    cheek *= (1.0 - beard * 0.75);
                    cheek *= mix(0.35, 1.0, skin);
                    float k = uBlush * cheek * 0.72;
                    float ys = luma(col);
                    vec3 softTint = mix(uBlushColor, vec3(ys) * uBlushColor / max(luma(uBlushColor), 1e-3), 0.35);
                    col = cosmeticTint(col, softTint, k * 0.85);
                }

                // Lipstick — continuous GPU mask (triangulated outer−inner, feathered).
                if (uLip > 0.01) {
                    float mask = texture2D(uLipMask, sampleUv).r;
                    mask = smoothstep(0.12, 0.55, mask);
                    float k = clamp(uLip * mask, 0.0, 1.0);
                    float ys = max(luma(col), 1e-3);
                    float yt = max(luma(uLipColor), 1e-3);
                    vec3 lipShade = uLipColor * (ys / yt);
                    lipShade = mix(lipShade, lipShade + (col - vec3(ys)) * 0.55, 0.40);
                    lipShade = mix(col, clamp(lipShade, 0.0, 1.0), 0.88);
                    col = mix(col, clamp(lipShade, 0.0, 1.0), k);
                }

                // Makeup under-eye (explicit slider; soft feather, no brow/nose spill).
                if (uUnderEye > 0.01 && uEyeRadius > 0.001) {
                    float bag = max(
                        underEyePad(canon, uEyeL, uEyeRadius),
                        underEyePad(canon, uEyeR, uEyeRadius));
                    float k = uUnderEye * bag * 0.75;
                    vec3 lift = mix(col, vec3(1.0), 0.18);
                    lift = mix(lift, col * vec3(1.10, 1.07, 1.04), 0.55);
                    col = mix(col, lift, k);
                }

                // Eye brightening — visible eye disk only (not lids/brows).
                if (uBrightEye > 0.01 && uEyeRadius > 0.001) {
                    float el = softCircle(canon, uEyeL, uEyeRadius * 0.88);
                    float er = softCircle(canon, uEyeR, uEyeRadius * 0.88);
                    float eye = max(el, er);
                    float k = uBrightEye * eye * 0.58;
                    col = mix(col, clamp(col * vec3(1.18, 1.15, 1.12) + 0.05, 0.0, 1.0), k);
                }

                gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
            }
        """
    }
}

/** ≤1 Hz beauty group diagnostics. */
object V3BeautyDiagnostics {
    private const val TAG = "V3_BEAUTY"
    private var lastLogMs = 0L

    fun noteColorMakeupFrame(grade: Boolean, makeup: Boolean, eyes: Boolean) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastLogMs < 1_000L) return
        lastLogMs = now
        Log.i(
            TAG,
            "grade=$grade makeup=$makeup eyeLocal=$eyes " +
                "beauty=${V3BeautyConfig.beautyActive()} " +
                "reshape=${V3BeautyConfig.reshapeActive()}",
        )
    }
}
