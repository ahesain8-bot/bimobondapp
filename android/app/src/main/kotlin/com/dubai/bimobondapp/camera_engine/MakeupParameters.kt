package com.dubai.bimobondapp.camera_engine

import kotlin.math.hypot
import kotlin.math.min

/**
 * Phase 7 makeup controls — intensities 0.0–1.0 + RGB colors.
 */
data class MakeupParameters(
    val lipstick: Float = 0f,
    val blush: Float = 0f,
    val eyeliner: Float = 0f,
    val eyeshadow: Float = 0f,
    /** RGB 0–1 */
    val lipstickColor: FloatArray = floatArrayOf(0.78f, 0.18f, 0.28f),
    val blushColor: FloatArray = floatArrayOf(0.95f, 0.48f, 0.52f),
    val eyelinerColor: FloatArray = floatArrayOf(0.06f, 0.05f, 0.08f),
    val eyeshadowColor: FloatArray = floatArrayOf(0.42f, 0.28f, 0.55f),
    val enabled: Boolean = true,
) {
    fun clamped(): MakeupParameters = copy(
        lipstick = lipstick.coerceIn(0f, 1f),
        blush = blush.coerceIn(0f, 1f),
        eyeliner = eyeliner.coerceIn(0f, 1f),
        eyeshadow = eyeshadow.coerceIn(0f, 1f),
        lipstickColor = clampRgb(lipstickColor),
        blushColor = clampRgb(blushColor),
        eyelinerColor = clampRgb(eyelinerColor),
        eyeshadowColor = clampRgb(eyeshadowColor),
    )

    fun isVisuallyActive(): Boolean {
        if (!enabled) return false
        return lipstick > 0.01f || blush > 0.01f || eyeliner > 0.01f || eyeshadow > 0.01f
    }

    fun needsFaceTracking(): Boolean = isVisuallyActive()

    companion object {
        private fun clampRgb(c: FloatArray): FloatArray {
            val out = FloatArray(3)
            out[0] = (c.getOrElse(0) { 0.5f }).coerceIn(0f, 1f)
            out[1] = (c.getOrElse(1) { 0.5f }).coerceIn(0f, 1f)
            out[2] = (c.getOrElse(2) { 0.5f }).coerceIn(0f, 1f)
            return out
        }
    }
}

/**
 * Soft region ellipses for lips / eyes / brows / cheeks / skin (primary face).
 * No Bitmap mask — landmark-derived uniforms only.
 */
data class MakeupFaceRegions(
    val hasFace: Boolean = false,
    /** Face/skin oval: cx, cy, rx, ry */
    val skin: FloatArray = floatArrayOf(0.5f, 0.5f, 0.2f, 0.28f),
    /** Lips oval */
    val lips: FloatArray = FloatArray(4),
    /** Left / right cheek: cx, cy, r */
    val cheekL: FloatArray = FloatArray(3),
    val cheekR: FloatArray = FloatArray(3),
    /** Eyes: cx, cy, rx, ry */
    val eyeL: FloatArray = FloatArray(4),
    val eyeR: FloatArray = FloatArray(4),
    /** Eyebrows: cx, cy, rx, ry */
    val browL: FloatArray = FloatArray(4),
    val browR: FloatArray = FloatArray(4),
) {
    companion object {
        val EMPTY = MakeupFaceRegions()

        private const val MOUTH_L = 61
        private const val MOUTH_R = 291
        private const val MOUTH_TOP = 0
        private const val MOUTH_BOT = 17
        private const val L_CHEEK = 50
        private const val R_CHEEK = 280
        private const val L_CHEEK_OUTER = 234
        private const val R_CHEEK_OUTER = 454
        private const val L_EYE_O = 33
        private const val L_EYE_I = 133
        private const val R_EYE_O = 263
        private const val R_EYE_I = 362
        private const val L_BROW = 105
        private const val R_BROW = 334

        fun fromFaces(faces: List<FaceLandmarks>): MakeupFaceRegions {
            val face = faces.firstOrNull() ?: return EMPTY
            if (face.count < 300) return EMPTY
            val xy = face.normalizedXy
            val n = face.count
            fun pt(i: Int): Pair<Float, Float> {
                if (i >= n) return face.centerX to face.centerY
                return xy[i * 2] to xy[i * 2 + 1]
            }
            fun mid(a: Int, b: Int): Pair<Float, Float> {
                val pa = pt(a); val pb = pt(b)
                return (pa.first + pb.first) * 0.5f to (pa.second + pb.second) * 0.5f
            }

            val scale = face.scale.coerceAtLeast(0.08f)
            val skin = floatArrayOf(
                face.centerX,
                face.centerY,
                (scale * 0.52f).coerceIn(0.08f, 0.5f),
                (scale * 0.70f).coerceIn(0.10f, 0.68f),
            )

            val ml = pt(MOUTH_L)
            val mr = pt(MOUTH_R)
            val mt = pt(MOUTH_TOP)
            val mb = pt(MOUTH_BOT)
            val mouthW = hypot((mr.first - ml.first).toDouble(), (mr.second - ml.second).toDouble())
                .toFloat().coerceAtLeast(0.03f)
            val mouthH = hypot((mb.first - mt.first).toDouble(), (mb.second - mt.second).toDouble())
                .toFloat().coerceAtLeast(0.015f)
            val lips = floatArrayOf(
                (ml.first + mr.first) * 0.5f,
                (mt.second + mb.second) * 0.5f,
                mouthW * 0.58f,
                mouthH * 0.85f,
            )

            val cheekAppleL = mid(L_CHEEK, L_CHEEK_OUTER)
            val cheekAppleR = mid(R_CHEEK, R_CHEEK_OUTER)
            val cheekR = (scale * 0.16f).coerceIn(0.04f, 0.14f)
            val cheekLArr = floatArrayOf(cheekAppleL.first, cheekAppleL.second, cheekR)
            val cheekRArr = floatArrayOf(cheekAppleR.first, cheekAppleR.second, cheekR)

            val lEye = mid(L_EYE_O, L_EYE_I)
            val rEye = mid(R_EYE_O, R_EYE_I)
            val eyeSpan = hypot(
                (rEye.first - lEye.first).toDouble(),
                (rEye.second - lEye.second).toDouble(),
            ).toFloat().coerceAtLeast(0.04f)
            val eyeRx = (eyeSpan * 0.28f).coerceIn(0.025f, 0.1f)
            val eyeRy = eyeRx * 0.65f
            val eyeL = floatArrayOf(lEye.first, lEye.second, eyeRx, eyeRy)
            val eyeR = floatArrayOf(rEye.first, rEye.second, eyeRx, eyeRy)

            val browLpt = pt(L_BROW)
            val browRpt = pt(R_BROW)
            // Place brows slightly above eyes.
            val browLift = (scale * 0.06f).coerceIn(0.015f, 0.05f)
            val browRx = eyeRx * 1.35f
            val browRy = eyeRy * 0.55f
            val browL = floatArrayOf(browLpt.first, min(browLpt.second, lEye.second) - browLift, browRx, browRy)
            val browR = floatArrayOf(browRpt.first, min(browRpt.second, rEye.second) - browLift, browRx, browRy)

            return MakeupFaceRegions(
                hasFace = true,
                skin = skin,
                lips = lips,
                cheekL = cheekLArr,
                cheekR = cheekRArr,
                eyeL = eyeL,
                eyeR = eyeR,
                browL = browL,
                browR = browR,
            )
        }
    }
}
