package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.opengl.GLES20
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer

/**
 * Continuous lipstick mask: triangulate outer−inner lip strips on CPU, rasterize
 * connected triangles into a reusable mask FBO (no per-fragment strip-quad cells).
 *
 * Topology (MediaPipe via [V3LipTopology]):
 * - Upper: OUTER_UPPER ↔ INNER_UPPER
 * - Lower: OUTER_LOWER ↔ INNER_LOWER
 * Inner mouth opening is a hole (never filled).
 */
internal class V3LipMaskPass {
    private var fillProgram = 0
    private var blurProgram = 0
    private var aPos = 0
    private var blurAPos = 0
    private var blurAUv = 0
    private var blurUTex = 0
    private var blurUTexel = 0
    private var blurUDir = 0

    private val hardMask = V3CanonicalTarget()
    private val softMask = V3CanonicalTarget()
    private val blurScratch = V3CanonicalTarget()

    /** Canonical UV (+Y down) contours from shared tracked state. */
    private val rawContour = FloatArray(V3LipTopology.CONTOUR_FLOATS)
    private val smoothContour = FloatArray(V3LipTopology.CONTOUR_FLOATS)

    /** NDC xy per strip vertex: upper outer/inner then lower outer/inner. */
    private val ndc = FloatArray(TOTAL_VERTS * 2)
    private val vertBuf: FloatBuffer = ByteBuffer
        .allocateDirect(TOTAL_VERTS * 2 * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
    private val indexBuf: ShortBuffer = ByteBuffer
        .allocateDirect(INDEX_COUNT * 2)
        .order(ByteOrder.nativeOrder())
        .asShortBuffer()
        .also {
            it.put(INDICES)
            it.position(0)
        }

    private val fullscreen: FloatBuffer = ByteBuffer
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

    private val restoreVp = IntArray(4)
    private val restoreFbo = IntArray(1)

    @Volatile
    var valid: Boolean = false
        private set

    fun maskTextureId(): Int = if (valid && softMask.textureId != 0) softMask.textureId else 0

    fun ensurePrograms(): Boolean {
        if (fillProgram == 0) {
            fillProgram = V3GlProgram.build(FILL_VS, FILL_FS)
            if (fillProgram == 0) return false
            aPos = GLES20.glGetAttribLocation(fillProgram, "aPosition")
        }
        if (blurProgram == 0) {
            blurProgram = V3GlProgram.build(BLUR_VS, BLUR_FS)
            if (blurProgram == 0) return false
            blurAPos = GLES20.glGetAttribLocation(blurProgram, "aPosition")
            blurAUv = GLES20.glGetAttribLocation(blurProgram, "aTexCoord")
            blurUTex = GLES20.glGetUniformLocation(blurProgram, "uTexture")
            blurUTexel = GLES20.glGetUniformLocation(blurProgram, "uTexel")
            blurUDir = GLES20.glGetUniformLocation(blurProgram, "uDir")
        }
        return true
    }

    /**
     * Updates lip vertices from latest mapped landmarks and rasterizes a continuous
     * feathered mask. Call on the GL thread when lipstick is active.
     */
    fun update(contract: V3FrameContract): Boolean {
        valid = false
        if (!ensurePrograms()) return false
        if (!V3FaceRegionState.copyLipContours(rawContour)) return false
        // Shared tracker already filters; no per-pass EMA (avoids lipstick lag).
        System.arraycopy(rawContour, 0, smoothContour, 0, rawContour.size)
        fillNdcFromContours(smoothContour)

        val mw = (contract.canonicalWidth / 2).coerceIn(MASK_MIN, MASK_MAX)
        val mh = (contract.canonicalHeight / 2).coerceIn(MASK_MIN, MASK_MAX)
        if (!hardMask.ensure(mw, mh)) return false
        if (!softMask.ensure(mw, mh)) return false
        if (!blurScratch.ensure(mw, mh)) return false

        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, restoreVp, 0)
        GLES20.glGetIntegerv(GLES20.GL_FRAMEBUFFER_BINDING, restoreFbo, 0)

        vertBuf.position(0)
        vertBuf.put(ndc)
        vertBuf.position(0)
        indexBuf.position(0)

        // Hard geometric fill: connected lip-tissue triangles only.
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, hardMask.fboId)
        GLES20.glViewport(0, 0, hardMask.width, hardMask.height)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glClearColor(0f, 0f, 0f, 0f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(fillProgram)
        GLES20.glEnableVertexAttribArray(aPos)
        GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 8, vertBuf)
        GLES20.glDrawElements(
            GLES20.GL_TRIANGLES,
            INDEX_COUNT,
            GLES20.GL_UNSIGNED_SHORT,
            indexBuf,
        )
        GLES20.glDisableVertexAttribArray(aPos)

        // Tiny separable blur ≈ 1–2 output pixels of edge feather (not heavy blur).
        blurPass(hardMask.textureId, blurScratch, horizontal = true)
        blurPass(blurScratch.textureId, softMask, horizontal = false)

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, restoreFbo[0])
        GLES20.glViewport(restoreVp[0], restoreVp[1], restoreVp[2], restoreVp[3])
        valid = softMask.textureId != 0
        return valid
    }

    fun release() {
        if (fillProgram != 0) {
            GLES20.glDeleteProgram(fillProgram)
            fillProgram = 0
        }
        if (blurProgram != 0) {
            GLES20.glDeleteProgram(blurProgram)
            blurProgram = 0
        }
        hardMask.release()
        softMask.release()
        blurScratch.release()
        valid = false
    }

    fun forgetHandles() {
        fillProgram = 0
        blurProgram = 0
        hardMask.forgetHandles()
        softMask.forgetHandles()
        blurScratch.forgetHandles()
        valid = false
    }

    private fun fillNdcFromContours(c: FloatArray) {
        // Upper: verts 0..10 outer, 11..21 inner
        putLipStrip(
            dstBase = 0,
            outerOff = V3LipTopology.OFF_UPPER_OUTER,
            innerOff = V3LipTopology.OFF_UPPER_INNER,
            c = c,
        )
        // Lower: verts 22..32 outer, 33..43 inner
        putLipStrip(
            dstBase = VERTS_PER_LIP,
            outerOff = V3LipTopology.OFF_LOWER_OUTER,
            innerOff = V3LipTopology.OFF_LOWER_INNER,
            c = c,
        )
    }

    private fun putLipStrip(dstBase: Int, outerOff: Int, innerOff: Int, c: FloatArray) {
        for (i in 0 until V3LipTopology.PAIRS) {
            val ou = c[outerOff + i * 2]
            val ov = c[outerOff + i * 2 + 1]
            val iu = c[innerOff + i * 2]
            val iv = c[innerOff + i * 2 + 1]
            val oIdx = (dstBase + i) * 2
            val iIdx = (dstBase + V3LipTopology.PAIRS + i) * 2
            // Canonical UV (+Y down) → clip / sample space matching color pass.
            ndc[oIdx] = ou * 2f - 1f
            ndc[oIdx + 1] = (1f - ov) * 2f - 1f
            ndc[iIdx] = iu * 2f - 1f
            ndc[iIdx + 1] = (1f - iv) * 2f - 1f
        }
    }

    private fun blurPass(srcTex: Int, dest: V3CanonicalTarget, horizontal: Boolean) {
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, dest.fboId)
        GLES20.glViewport(0, 0, dest.width, dest.height)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glUseProgram(blurProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, srcTex)
        GLES20.glUniform1i(blurUTex, 0)
        GLES20.glUniform2f(blurUTexel, 1f / dest.width, 1f / dest.height)
        if (horizontal) {
            GLES20.glUniform2f(blurUDir, 1f, 0f)
        } else {
            GLES20.glUniform2f(blurUDir, 0f, 1f)
        }
        fullscreen.position(0)
        GLES20.glEnableVertexAttribArray(blurAPos)
        GLES20.glVertexAttribPointer(blurAPos, 2, GLES20.GL_FLOAT, false, 16, fullscreen)
        fullscreen.position(2)
        GLES20.glEnableVertexAttribArray(blurAUv)
        GLES20.glVertexAttribPointer(blurAUv, 2, GLES20.GL_FLOAT, false, 16, fullscreen)
        fullscreen.position(0)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(blurAPos)
        GLES20.glDisableVertexAttribArray(blurAUv)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }

    companion object {
        private const val MASK_MIN = 160
        private const val MASK_MAX = 512

        private const val VERTS_PER_LIP = V3LipTopology.PAIRS * 2 // 22
        private const val TOTAL_VERTS = VERTS_PER_LIP * 2 // 44
        private const val QUADS_PER_LIP = V3LipTopology.PAIRS - 1 // 10
        private const val TRIS_PER_LIP = QUADS_PER_LIP * 2 // 20
        private const val INDEX_COUNT = TRIS_PER_LIP * 2 * 3 // 120

        /**
         * Fixed strip indices: for each lip, outer[i]–outer[i+1]–inner[i+1]–inner[i]
         * as two triangles. Shared edges → continuous rasterized surface.
         */
        private val INDICES: ShortArray = ShortArray(INDEX_COUNT).also { out ->
            var w = 0
            fun emitLip(base: Int) {
                val outer = base
                val inner = base + V3LipTopology.PAIRS
                for (i in 0 until QUADS_PER_LIP) {
                    val o0 = (outer + i).toShort()
                    val o1 = (outer + i + 1).toShort()
                    val i0 = (inner + i).toShort()
                    val i1 = (inner + i + 1).toShort()
                    out[w++] = o0; out[w++] = o1; out[w++] = i0
                    out[w++] = o1; out[w++] = i1; out[w++] = i0
                }
            }
            emitLip(0)
            emitLip(VERTS_PER_LIP)
        }

        private const val FILL_VS = """
            attribute vec2 aPosition;
            void main() {
                gl_Position = vec4(aPosition, 0.0, 1.0);
            }
        """

        private const val FILL_FS = """
            precision mediump float;
            void main() {
                gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
            }
        """

        private const val BLUR_VS = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vUv;
            void main() {
                gl_Position = aPosition;
                vUv = aTexCoord;
            }
        """

        /** 5-tap separable blur — feather only, not a soft glow. */
        private const val BLUR_FS = """
            precision mediump float;
            varying vec2 vUv;
            uniform sampler2D uTexture;
            uniform vec2 uTexel;
            uniform vec2 uDir;
            void main() {
                vec2 step = uTexel * uDir;
                float c = texture2D(uTexture, vUv).r * 0.40;
                c += texture2D(uTexture, vUv + step).r * 0.25;
                c += texture2D(uTexture, vUv - step).r * 0.25;
                c += texture2D(uTexture, vUv + step * 2.0).r * 0.05;
                c += texture2D(uTexture, vUv - step * 2.0).r * 0.05;
                gl_FragColor = vec4(c, c, c, 1.0);
            }
        """
    }
}
