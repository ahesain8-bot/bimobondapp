package com.dubai.bimobondapp.camera_engine

/**
 * Phase 5 beauty controls — all intensities are 0.0–1.0.
 */
data class BeautyParameters(
    val skinSmooth: Float = 0f,
    val brightness: Float = 0f,
    val skinTone: Float = 0f,
    val sharpen: Float = 0f,
    val eyeEnhancement: Float = 0f,
    val enabled: Boolean = true,
) {
    fun clamped(): BeautyParameters = copy(
        skinSmooth = skinSmooth.coerceIn(0f, 1f),
        brightness = brightness.coerceIn(0f, 1f),
        skinTone = skinTone.coerceIn(0f, 1f),
        sharpen = sharpen.coerceIn(0f, 1f),
        eyeEnhancement = eyeEnhancement.coerceIn(0f, 1f),
    )

    /** True when any regional / tone effect needs a face mask path. */
    fun needsFaceMask(): Boolean {
        if (!enabled) return false
        return skinSmooth > 0.01f ||
            skinTone > 0.01f ||
            sharpen > 0.01f ||
            eyeEnhancement > 0.01f
    }

    fun isVisuallyActive(): Boolean {
        if (!enabled) return false
        return skinSmooth > 0.01f ||
            brightness > 0.01f ||
            skinTone > 0.01f ||
            sharpen > 0.01f ||
            eyeEnhancement > 0.01f
    }
}

/**
 * Soft face / eye ellipses in normalized UV [0,1] for up to [MAX_FACES] faces.
 * Packed for cheap uniform upload — no Bitmap mask.
 */
data class BeautyFaceMask(
    val faceCount: Int = 0,
    /** cx, cy, rx, ry per face (max 2). */
    val faces: FloatArray = FloatArray(MAX_FACES * 4),
    /** leftEye cx,cy,r + rightEye cx,cy,r per face (max 2). */
    val eyes: FloatArray = FloatArray(MAX_FACES * 6),
) {
    companion object {
        const val MAX_FACES = 2

        val EMPTY = BeautyFaceMask()

        fun fromFaces(faces: List<FaceLandmarks>): BeautyFaceMask {
            if (faces.isEmpty()) return EMPTY
            val count = faces.size.coerceAtMost(MAX_FACES)
            val facePacked = FloatArray(MAX_FACES * 4)
            val eyePacked = FloatArray(MAX_FACES * 6)
            for (i in 0 until count) {
                val f = faces[i]
                val xy = f.normalizedXy
                val scale = f.scale.coerceAtLeast(0.08f)
                facePacked[i * 4] = f.centerX
                facePacked[i * 4 + 1] = f.centerY
                facePacked[i * 4 + 2] = (scale * 0.55f).coerceIn(0.08f, 0.55f)
                facePacked[i * 4 + 3] = (scale * 0.72f).coerceIn(0.10f, 0.70f)

                val eyes = eyeCenters(xy, f.count)
                val eyeR = (scale * 0.11f).coerceIn(0.03f, 0.12f)
                eyePacked[i * 6] = eyes[0]
                eyePacked[i * 6 + 1] = eyes[1]
                eyePacked[i * 6 + 2] = eyeR
                eyePacked[i * 6 + 3] = eyes[2]
                eyePacked[i * 6 + 4] = eyes[3]
                eyePacked[i * 6 + 5] = eyeR
            }
            return BeautyFaceMask(faceCount = count, faces = facePacked, eyes = eyePacked)
        }

        private fun eyeCenters(xy: FloatArray, count: Int): FloatArray {
            // MediaPipe: 33 left eye outer, 263 right eye outer; average with inner corners.
            fun avg(vararg indices: Int): Pair<Float, Float> {
                var sx = 0f
                var sy = 0f
                var n = 0
                for (idx in indices) {
                    if (idx >= count) continue
                    sx += xy[idx * 2]
                    sy += xy[idx * 2 + 1]
                    n++
                }
                if (n == 0) return 0.5f to 0.5f
                return (sx / n) to (sy / n)
            }
            val left = avg(33, 133, 159, 145)
            val right = avg(263, 362, 386, 374)
            return floatArrayOf(left.first, left.second, right.first, right.second)
        }
    }
}
