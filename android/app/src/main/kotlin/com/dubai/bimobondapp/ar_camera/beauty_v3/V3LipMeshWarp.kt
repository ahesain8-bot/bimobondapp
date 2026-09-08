package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.opengl.GLES20
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer
import kotlin.math.hypot

/**
 * Multi-ring lip filler mesh: distributed ring displacements + lightweight
 * similarity relaxation so enlargement reads as volume, not texture magnify.
 *
 * Draw: TARGET positions, SOURCE UVs (shape-preserving / UV-follow), no shading.
 */
internal class V3LipMeshWarp {
    private var program = 0
    private var aPos = 0
    private var aUv = 0
    private var uTex = 0

    /** Interleaved targetNdcX, targetNdcY, srcTexU, srcTexV. */
    private val vertData = FloatArray(V3LipTopology.TOTAL_VERTS * 4)
    private val restU = FloatArray(V3LipTopology.TOTAL_VERTS)
    private val restV = FloatArray(V3LipTopology.TOTAL_VERTS)
    private val tgtU = FloatArray(V3LipTopology.TOTAL_VERTS)
    private val tgtV = FloatArray(V3LipTopology.TOTAL_VERTS)
    private val srcU = FloatArray(V3LipTopology.TOTAL_VERTS)
    private val srcV = FloatArray(V3LipTopology.TOTAL_VERTS)
    private val scratchU = FloatArray(V3LipTopology.TOTAL_VERTS)
    private val scratchV = FloatArray(V3LipTopology.TOTAL_VERTS)

    private val vertBuf: FloatBuffer = ByteBuffer
        .allocateDirect(V3LipTopology.TOTAL_VERTS * 4 * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
    private val indexBuf: ShortBuffer = ByteBuffer
        .allocateDirect(V3LipTopology.INDEX_COUNT * 2)
        .order(ByteOrder.nativeOrder())
        .asShortBuffer()
        .also {
            it.put(V3LipTopology.INDICES)
            it.position(0)
        }

    fun ensureProgram(): Boolean {
        if (program != 0) return true
        program = V3GlProgram.build(VS, FS)
        if (program == 0) return false
        aPos = GLES20.glGetAttribLocation(program, "aPosition")
        aUv = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTex = GLES20.glGetUniformLocation(program, "uTexture")
        return true
    }

    fun draw(srcTexId: Int): Boolean {
        if (srcTexId == 0 || !ensureProgram()) return false
        if (!V3LipContourState.update()) return false
        val overall = V3BeautyConfig.lipOverallFullness()
        val upper = V3BeautyConfig.lipUpperFullness()
        val lower = V3BeautyConfig.lipLowerFullness()
        if (kotlin.math.abs(overall) < 0.01f &&
            kotlin.math.abs(upper) < 0.01f &&
            kotlin.math.abs(lower) < 0.01f
        ) {
            return false
        }

        var upperAmt = upper
        var lowerAmt = lower
        if (kotlin.math.abs(overall) > 0.01f) {
            if (kotlin.math.abs(upper) < 0.01f && kotlin.math.abs(lower) < 0.01f) {
                upperAmt = overall
                lowerAmt = overall
            } else {
                upperAmt += overall * 0.55f
                lowerAmt += overall * 0.55f
            }
        }
        upperAmt = upperAmt.coerceIn(-1.5f, 1.5f)
        lowerAmt = lowerAmt.coerceIn(-1.5f, 1.5f)

        val cuv = V3LipContourState.canonUv
        buildLip(
            lipBase = 0,
            outerOff = V3LipTopology.OFF_UPPER_OUTER,
            innerOff = V3LipTopology.OFF_UPPER_INNER,
            fullness = upperAmt,
            cuv = cuv,
        )
        buildLip(
            lipBase = V3LipTopology.VERTS_PER_LIP,
            outerOff = V3LipTopology.OFF_LOWER_OUTER,
            innerOff = V3LipTopology.OFF_LOWER_INNER,
            fullness = lowerAmt,
            cuv = cuv,
        )

        // Soften local scale/shear on free rings (skin + body).
        relaxSimilarity(lipBase = 0)
        relaxSimilarity(lipBase = V3LipTopology.VERTS_PER_LIP)

        // Recompute source UVs after relaxation (constraints refreshed).
        applySourceUvs(lipBase = 0)
        applySourceUvs(lipBase = V3LipTopology.VERTS_PER_LIP)

        for (v in 0 until V3LipTopology.TOTAL_VERTS) {
            val o = v * 4
            vertData[o] = tgtU[v] * 2f - 1f
            vertData[o + 1] = (1f - tgtV[v]) * 2f - 1f
            vertData[o + 2] = srcU[v]
            vertData[o + 3] = 1f - srcV[v]
        }

        vertBuf.position(0)
        vertBuf.put(vertData)
        vertBuf.position(0)
        indexBuf.position(0)

        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, srcTexId)
        GLES20.glUniform1i(uTex, 0)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glDisable(GLES20.GL_CULL_FACE)

        vertBuf.position(0)
        GLES20.glEnableVertexAttribArray(aPos)
        GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 16, vertBuf)
        vertBuf.position(2)
        GLES20.glEnableVertexAttribArray(aUv)
        GLES20.glVertexAttribPointer(aUv, 2, GLES20.GL_FLOAT, false, 16, vertBuf)
        vertBuf.position(0)

        GLES20.glDrawElements(
            GLES20.GL_TRIANGLES,
            V3LipTopology.INDEX_COUNT,
            GLES20.GL_UNSIGNED_SHORT,
            indexBuf,
        )
        GLES20.glDisableVertexAttribArray(aPos)
        GLES20.glDisableVertexAttribArray(aUv)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        return true
    }

    private fun buildLip(
        lipBase: Int,
        outerOff: Int,
        innerOff: Int,
        fullness: Float,
        cuv: FloatArray,
    ) {
        for (i in 0 until V3LipTopology.PAIRS) {
            val ou = cuv[outerOff + i * 2]
            val ov = cuv[outerOff + i * 2 + 1]
            val iu = cuv[innerOff + i * 2]
            val iv = cuv[innerOff + i * 2 + 1]
            var ax = ou - iu
            var ay = ov - iv
            var thick = hypot(ax, ay)
            if (thick < 1e-5f) {
                for (r in 0 until V3LipTopology.RINGS) {
                    val vi = V3LipTopology.vertIndex(lipBase, r, i)
                    restU[vi] = ou
                    restV[vi] = ov
                    tgtU[vi] = ou
                    tgtV[vi] = ov
                }
                continue
            }
            ax /= thick
            ay /= thick
            val w = V3LipTopology.PAIR_WEIGHT[i]
            val skinPad = (thick * SKIN_PAD_MUL).coerceAtLeast(SKIN_PAD_MIN)
            val ancPad = (thick * ANCHOR_PAD_MUL).coerceAtLeast(ANCHOR_PAD_MIN)

            // Rest ring positions along local outward axis.
            val ru = floatArrayOf(
                ou + ax * ancPad,
                ou + ax * skinPad,
                ou,
                ou * (1f - BODY_T) + iu * BODY_T,
                iu,
            )
            val rv = floatArrayOf(
                ov + ay * ancPad,
                ov + ay * skinPad,
                ov,
                ov * (1f - BODY_T) + iv * BODY_T,
                iv,
            )

            val baseDisp = if (fullness >= 0f) {
                thick * fullness * OUTER_GAIN * w
            } else {
                val red = -fullness
                val maxIn = thick * (1f - MIN_THICK_FRAC) * 0.90f
                -(thick * red * OUTER_GAIN * w).coerceAtMost(maxIn)
            }

            for (r in 0 until V3LipTopology.RINGS) {
                val vi = V3LipTopology.vertIndex(lipBase, r, i)
                restU[vi] = ru[r]
                restV[vi] = rv[r]
                val d = baseDisp * V3LipTopology.RING_DISP[r]
                var tu = ru[r] + ax * d
                var tv = rv[r] + ay * d
                // Keep inner/outer from crossing on reduction.
                if (r == V3LipTopology.RING_OUTER && fullness < 0f) {
                    val nx = tu - (ru[V3LipTopology.RING_INNER] + ax * baseDisp * V3LipTopology.RING_DISP[V3LipTopology.RING_INNER])
                    val ny = tv - (rv[V3LipTopology.RING_INNER] + ay * baseDisp * V3LipTopology.RING_DISP[V3LipTopology.RING_INNER])
                    val minT = thick * MIN_THICK_FRAC
                    if (hypot(nx, ny) < minT || nx * ax + ny * ay < 0f) {
                        val iU = ru[V3LipTopology.RING_INNER] +
                            ax * baseDisp * V3LipTopology.RING_DISP[V3LipTopology.RING_INNER]
                        val iV = rv[V3LipTopology.RING_INNER] +
                            ay * baseDisp * V3LipTopology.RING_DISP[V3LipTopology.RING_INNER]
                        tu = iU + ax * minT
                        tv = iV + ay * minT
                    }
                }
                tgtU[vi] = tu
                tgtV[vi] = tv
            }
        }
    }

    /**
     * One-shot / few-iter local similarity relaxation on SKIN + BODY rings.
     * Fits per-neighbor rotation (scale forced ≈ 1) to reduce shear/stretch;
     * ANCHOR / OUTER / INNER stay constrained.
     */
    private fun relaxSimilarity(lipBase: Int) {
        for (iter in 0 until RELAX_ITERS) {
            System.arraycopy(tgtU, lipBase, scratchU, lipBase, V3LipTopology.VERTS_PER_LIP)
            System.arraycopy(tgtV, lipBase, scratchV, lipBase, V3LipTopology.VERTS_PER_LIP)
            for (ring in intArrayOf(V3LipTopology.RING_SKIN, V3LipTopology.RING_BODY)) {
                for (i in 0 until V3LipTopology.PAIRS) {
                    val v = V3LipTopology.vertIndex(lipBase, ring, i)
                    var sx = 0f
                    var sy = 0f
                    var n = 0
                    fun addNeighbor(nr: Int, np: Int) {
                        if (np < 0 || np >= V3LipTopology.PAIRS) return
                        if (nr < 0 || nr >= V3LipTopology.RINGS) return
                        val u = V3LipTopology.vertIndex(lipBase, nr, np)
                        val ox = restU[v] - restU[u]
                        val oy = restV[v] - restV[u]
                        val lenR = hypot(ox, oy)
                        if (lenR < 1e-6f) return
                        val dx = tgtU[v] - tgtU[u]
                        val dy = tgtV[v] - tgtV[u]
                        val lenD = hypot(dx, dy).coerceAtLeast(1e-6f)
                        // Rotation taking rest edge → deformed edge (scale forced to 1).
                        val cosA = ((ox * dx + oy * dy) / (lenR * lenD)).coerceIn(-1f, 1f)
                        val sinA = ((ox * dy - oy * dx) / (lenR * lenD)).coerceIn(-1f, 1f)
                        val px = cosA * ox - sinA * oy
                        val py = sinA * ox + cosA * oy
                        sx += tgtU[u] + px
                        sy += tgtV[u] + py
                        n++
                    }
                    addNeighbor(ring, i - 1)
                    addNeighbor(ring, i + 1)
                    addNeighbor(ring - 1, i)
                    addNeighbor(ring + 1, i)
                    if (n > 0) {
                        scratchU[v] = sx / n
                        scratchV[v] = sy / n
                    }
                }
            }
            // Write free rings; keep constraints.
            for (ring in intArrayOf(V3LipTopology.RING_SKIN, V3LipTopology.RING_BODY)) {
                for (i in 0 until V3LipTopology.PAIRS) {
                    val v = V3LipTopology.vertIndex(lipBase, ring, i)
                    tgtU[v] = scratchU[v]
                    tgtV[v] = scratchV[v]
                }
            }
        }
    }

    /**
     * Source UV: rest + follow * (target − rest).
     * Skin follows (expansion absorbed outside vermilion); lip rings hold density.
     */
    private fun applySourceUvs(lipBase: Int) {
        for (ring in 0 until V3LipTopology.RINGS) {
            val follow = V3LipTopology.RING_UV_FOLLOW[ring]
            for (i in 0 until V3LipTopology.PAIRS) {
                val v = V3LipTopology.vertIndex(lipBase, ring, i)
                val du = tgtU[v] - restU[v]
                val dv = tgtV[v] - restV[v]
                srcU[v] = restU[v] + du * follow
                srcV[v] = restV[v] + dv * follow
            }
        }
        // Expanded silhouette band (skin→outer): bias samples toward original outer rim
        // so new area reads as lip tissue, not magnified mid-lip / raw skin hole.
        for (i in 0 until V3LipTopology.PAIRS) {
            val skin = V3LipTopology.vertIndex(lipBase, V3LipTopology.RING_SKIN, i)
            val outer = V3LipTopology.vertIndex(lipBase, V3LipTopology.RING_OUTER, i)
            // Pull skin-ring source slightly toward rest outer (vermilion edge).
            srcU[skin] = srcU[skin] * 0.55f + restU[outer] * 0.45f
            srcV[skin] = srcV[skin] * 0.55f + restV[outer] * 0.45f
        }
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
        /** Peak outer displacement as fraction of local thickness at fullness=1. */
        const val OUTER_GAIN = 0.58f
        const val MIN_THICK_FRAC = 0.32f
        /** Body ring parametric t from outer toward inner. */
        const val BODY_T = 0.42f
        const val SKIN_PAD_MUL = 0.55f
        const val SKIN_PAD_MIN = 0.008f
        const val ANCHOR_PAD_MUL = 1.15f
        const val ANCHOR_PAD_MIN = 0.016f
        const val RELAX_ITERS = 2

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
            void main() {
                gl_FragColor = texture2D(uTexture, vUv);
            }
        """
    }
}
