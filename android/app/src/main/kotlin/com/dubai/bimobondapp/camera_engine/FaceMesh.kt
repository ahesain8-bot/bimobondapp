package com.dubai.bimobondapp.camera_engine

import kotlin.math.hypot
import kotlin.math.max

/**
 * Phase 6: CPU-side face mesh used to drive GPU UV deformation.
 *
 * Grid positions stay fixed in NDC; texcoords are warped from landmarks + [WarpParameters].
 * No full-resolution Bitmap manipulation.
 */
class FaceMesh(
    val cols: Int = DEFAULT_COLS,
    val rows: Int = DEFAULT_ROWS,
) {
    /** Interleaved x,y,u,v per vertex (NDC position + sample UV). */
    val interleaved: FloatArray = FloatArray((cols + 1) * (rows + 1) * 4)

    /** Triangle indices. */
    val indices: ShortArray = ShortArray(cols * rows * 6)

    val vertexCount: Int = (cols + 1) * (rows + 1)
    val indexCount: Int = indices.size

    @Volatile
    private var hasFace: Boolean = false

    init {
        buildIndexBuffer()
        resetIdentity()
    }

    fun hasActiveFace(): Boolean = hasFace

    fun resetIdentity() {
        hasFace = false
        var i = 0
        for (row in 0..rows) {
            val v = row.toFloat() / rows
            val y = 1f - v * 2f
            for (col in 0..cols) {
                val u = col.toFloat() / cols
                val x = u * 2f - 1f
                interleaved[i++] = x
                interleaved[i++] = y
                interleaved[i++] = u
                interleaved[i++] = v
            }
        }
    }

    /**
     * Rebuilds sample UVs from the primary face. Safe to call from the analyzer thread;
     * GL upload happens later on the GL thread via a copy of [interleaved].
     */
    fun updateFromFace(face: FaceLandmarks?, params: WarpParameters) {
        if (face == null || !params.isVisuallyActive() || face.count < 300) {
            resetIdentity()
            return
        }
        hasFace = true
        val ctrl = FaceWarpControls.from(face)
        var i = 0
        for (row in 0..rows) {
            val v0 = row.toFloat() / rows
            val y = 1f - v0 * 2f
            for (col in 0..cols) {
                val u0 = col.toFloat() / cols
                val x = u0 * 2f - 1f
                val warped = warpUv(u0, v0, ctrl, params)
                interleaved[i++] = x
                interleaved[i++] = y
                interleaved[i++] = warped[0]
                interleaved[i++] = warped[1]
            }
        }
    }

    /** Snapshot for GL thread (avoids tearing while analyzer writes). */
    fun copyInterleaved(): FloatArray = interleaved.copyOf()

    private fun buildIndexBuffer() {
        var i = 0
        for (row in 0 until rows) {
            for (col in 0 until cols) {
                val topLeft = (row * (cols + 1) + col).toShort()
                val topRight = (topLeft + 1).toShort()
                val bottomLeft = ((row + 1) * (cols + 1) + col).toShort()
                val bottomRight = (bottomLeft + 1).toShort()
                indices[i++] = topLeft
                indices[i++] = bottomLeft
                indices[i++] = topRight
                indices[i++] = topRight
                indices[i++] = bottomLeft
                indices[i++] = bottomRight
            }
        }
    }

    companion object {
        const val DEFAULT_COLS = 24
        const val DEFAULT_ROWS = 32

        private fun warpUv(
            u: Float,
            v: Float,
            c: FaceWarpControls,
            p: WarpParameters,
        ): FloatArray {
            var x = u
            var y = v

            // Face slim — pull cheeks toward midline.
            if (p.faceSlim > 0.01f) {
                val wL = falloff(x, y, c.leftCheekX, c.leftCheekY, c.faceRx * 0.85f, c.faceRy * 0.9f)
                val wR = falloff(x, y, c.rightCheekX, c.rightCheekY, c.faceRx * 0.85f, c.faceRy * 0.9f)
                val slim = p.faceSlim * 0.22f
                x += (c.midX - x) * wL * slim
                x += (c.midX - x) * wR * slim
            }

            // Jaw — narrow/reshape lower face sides.
            if (p.jaw > 0.01f) {
                val wL = falloff(x, y, c.leftJawX, c.leftJawY, c.faceRx * 0.7f, c.faceRy * 0.55f)
                val wR = falloff(x, y, c.rightJawX, c.rightJawY, c.faceRx * 0.7f, c.faceRy * 0.55f)
                val amt = p.jaw * 0.20f
                x += (c.midX - x) * wL * amt
                x += (c.midX - x) * wR * amt
            }

            // Chin — lift chin slightly toward mouth.
            if (p.chin > 0.01f) {
                val w = falloff(x, y, c.chinX, c.chinY, c.faceRx * 0.55f, c.faceRy * 0.4f)
                y += (c.mouthY - y) * w * (p.chin * 0.18f)
            }

            // Big eyes — radial expand (sample from closer to center → looks larger).
            if (p.bigEyes > 0.01f) {
                val s = p.bigEyes * 0.28f
                val r = c.eyeR * 1.35f
                bulgeSample(x, y, c.leftEyeX, c.leftEyeY, r, s).let {
                    x = it[0]; y = it[1]
                }
                bulgeSample(x, y, c.rightEyeX, c.rightEyeY, r, s).let {
                    x = it[0]; y = it[1]
                }
            }

            // Small nose — pull wings toward bridge.
            if (p.smallNose > 0.01f) {
                val s = p.smallNose * 0.24f
                val r = c.noseR * 1.2f
                pinchSample(x, y, c.noseX, c.noseY, r, s).let {
                    x = it[0]; y = it[1]
                }
            }

            // Big lips — radial expand around mouth.
            if (p.bigLips > 0.01f) {
                val s = p.bigLips * 0.26f
                val r = c.mouthR * 1.25f
                bulgeSample(x, y, c.mouthX, c.mouthY, r, s).let {
                    x = it[0]; y = it[1]
                }
            }

            return floatArrayOf(x.coerceIn(0f, 1f), y.coerceIn(0f, 1f))
        }

        /** Sample UV moves toward center → magnification. */
        private fun bulgeSample(
            u: Float,
            v: Float,
            cx: Float,
            cy: Float,
            radius: Float,
            strength: Float,
        ): FloatArray {
            val dx = u - cx
            val dy = v - cy
            val d = hypot(dx.toDouble(), dy.toDouble()).toFloat()
            if (d >= radius || radius <= 1e-5f) return floatArrayOf(u, v)
            val t = 1f - d / radius
            val w = t * t * strength
            return floatArrayOf(u - dx * w, v - dy * w)
        }

        /** Sample UV moves away from center → shrink. */
        private fun pinchSample(
            u: Float,
            v: Float,
            cx: Float,
            cy: Float,
            radius: Float,
            strength: Float,
        ): FloatArray {
            val dx = u - cx
            val dy = v - cy
            val d = hypot(dx.toDouble(), dy.toDouble()).toFloat()
            if (d >= radius || radius <= 1e-5f) return floatArrayOf(u, v)
            val t = 1f - d / radius
            val w = t * t * strength
            return floatArrayOf(u + dx * w, v + dy * w)
        }

        private fun falloff(
            u: Float,
            v: Float,
            cx: Float,
            cy: Float,
            rx: Float,
            ry: Float,
        ): Float {
            val dx = (u - cx) / max(rx, 1e-4f)
            val dy = (v - cy) / max(ry, 1e-4f)
            val d2 = dx * dx + dy * dy
            if (d2 >= 1f) return 0f
            val t = 1f - d2
            return t * t
        }
    }
}

/** Landmark-derived control points in normalized UV space. */
data class FaceWarpControls(
    val midX: Float,
    val midY: Float,
    val faceRx: Float,
    val faceRy: Float,
    val leftCheekX: Float,
    val leftCheekY: Float,
    val rightCheekX: Float,
    val rightCheekY: Float,
    val leftJawX: Float,
    val leftJawY: Float,
    val rightJawX: Float,
    val rightJawY: Float,
    val leftEyeX: Float,
    val leftEyeY: Float,
    val rightEyeX: Float,
    val rightEyeY: Float,
    val eyeR: Float,
    val noseX: Float,
    val noseY: Float,
    val noseR: Float,
    val mouthX: Float,
    val mouthY: Float,
    val mouthR: Float,
    val chinX: Float,
    val chinY: Float,
) {
    companion object {
        private const val L_CHEEK = 234
        private const val R_CHEEK = 454
        private const val L_JAW = 172
        private const val R_JAW = 397
        private const val L_EYE = 33
        private const val R_EYE = 263
        private const val L_EYE_IN = 133
        private const val R_EYE_IN = 362
        private const val NOSE = 1
        private const val NOSE_L = 48
        private const val NOSE_R = 278
        private const val MOUTH_L = 61
        private const val MOUTH_R = 291
        private const val MOUTH_TOP = 0
        private const val MOUTH_BOT = 17
        private const val CHIN = 152

        fun from(face: FaceLandmarks): FaceWarpControls {
            val xy = face.normalizedXy
            val n = face.count
            fun pt(i: Int): Pair<Float, Float> {
                if (i >= n) return face.centerX to face.centerY
                return xy[i * 2] to xy[i * 2 + 1]
            }
            fun mid(a: Int, b: Int): Pair<Float, Float> {
                val pa = pt(a)
                val pb = pt(b)
                return (pa.first + pb.first) * 0.5f to (pa.second + pb.second) * 0.5f
            }

            val lCheek = pt(L_CHEEK)
            val rCheek = pt(R_CHEEK)
            val lJaw = pt(L_JAW)
            val rJaw = pt(R_JAW)
            val lEye = mid(L_EYE, L_EYE_IN)
            val rEye = mid(R_EYE, R_EYE_IN)
            val nose = pt(NOSE)
            val noseL = pt(NOSE_L)
            val noseR = pt(NOSE_R)
            val mouth = mid(MOUTH_L, MOUTH_R)
            val mouthTop = pt(MOUTH_TOP)
            val mouthBot = pt(MOUTH_BOT)
            val chin = pt(CHIN)

            val scale = face.scale.coerceAtLeast(0.08f)
            val faceRx = (scale * 0.55f).coerceIn(0.08f, 0.55f)
            val faceRy = (scale * 0.72f).coerceIn(0.10f, 0.70f)
            val eyeSpan = hypot(
                (rEye.first - lEye.first).toDouble(),
                (rEye.second - lEye.second).toDouble(),
            ).toFloat().coerceAtLeast(0.04f)
            val noseSpan = hypot(
                (noseR.first - noseL.first).toDouble(),
                (noseR.second - noseL.second).toDouble(),
            ).toFloat().coerceAtLeast(0.02f)
            val mouthSpan = hypot(
                (pt(MOUTH_R).first - pt(MOUTH_L).first).toDouble(),
                (mouthBot.second - mouthTop.second).toDouble(),
            ).toFloat().coerceAtLeast(0.03f)

            return FaceWarpControls(
                midX = face.centerX,
                midY = face.centerY,
                faceRx = faceRx,
                faceRy = faceRy,
                leftCheekX = lCheek.first,
                leftCheekY = lCheek.second,
                rightCheekX = rCheek.first,
                rightCheekY = rCheek.second,
                leftJawX = lJaw.first,
                leftJawY = lJaw.second,
                rightJawX = rJaw.first,
                rightJawY = rJaw.second,
                leftEyeX = lEye.first,
                leftEyeY = lEye.second,
                rightEyeX = rEye.first,
                rightEyeY = rEye.second,
                eyeR = (eyeSpan * 0.42f).coerceIn(0.03f, 0.14f),
                noseX = nose.first,
                noseY = nose.second,
                noseR = (noseSpan * 0.85f).coerceIn(0.025f, 0.12f),
                mouthX = mouth.first,
                mouthY = (mouthTop.second + mouthBot.second) * 0.5f,
                mouthR = (mouthSpan * 0.7f).coerceIn(0.03f, 0.16f),
                chinX = chin.first,
                chinY = chin.second,
            )
        }
    }
}
