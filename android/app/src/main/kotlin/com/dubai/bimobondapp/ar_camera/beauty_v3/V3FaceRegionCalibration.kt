package com.dubai.bimobondapp.ar_camera.beauty_v3

/**
 * Region-local calibration. Does **not** modify AnalysisToCanonical mapping.
 *
 * ```
 * x' = cx + (x - cx) * widthScale + offsetX * faceWidth
 * y' = cy + (y - cy) * heightScale + offsetY * faceHeight
 * ```
 *
 * Offsets are normalized to face width/height so near/far and resolution stay consistent.
 *
 * Accepted V3-1.5 defaults were recovered from on-device tuning (JDWP dump) and must
 * round-trip exactly — no averaging / heuristic rewrites.
 */
data class V3RegionCalibParams(
    var widthScale: Float = 1f,
    var heightScale: Float = 1f,
    /** Fraction of face width. */
    var offsetX: Float = 0f,
    /** Fraction of face height. */
    var offsetY: Float = 0f,
) {
    fun matches(other: V3RegionCalibParams): Boolean =
        widthScale == other.widthScale &&
            heightScale == other.heightScale &&
            offsetX == other.offsetX &&
            offsetY == other.offsetY

    fun copyFrom(other: V3RegionCalibParams) {
        widthScale = other.widthScale
        heightScale = other.heightScale
        offsetX = other.offsetX
        offsetY = other.offsetY
    }

    fun copy(): V3RegionCalibParams =
        V3RegionCalibParams(widthScale, heightScale, offsetX, offsetY)
}

object V3FaceRegionCalibration {
    const val KEY_FACE_OVAL = "face_oval"
    const val KEY_LEFT_EYE = "left_eye"
    const val KEY_RIGHT_EYE = "right_eye"
    const val KEY_BROWS = "brows"
    const val KEY_NOSE = "nose"
    const val KEY_OUTER_LIPS = "outer_lips"
    const val KEY_INNER_LIPS = "inner_lips"
    const val KEY_MOUTH_OPENING = "mouth_opening"
    const val KEY_LEFT_CHEEK = "left_cheek"
    const val KEY_RIGHT_CHEEK = "right_cheek"

    /**
     * Frozen V3-1.5 accepted defaults (exact float literals from device recovery).
     * RESET REGION / RESET ALL restore these — not identity 1/1/0/0.
     */
    private val ACCEPTED_DEFAULTS: Map<String, V3RegionCalibParams> = linkedMapOf(
        KEY_FACE_OVAL to V3RegionCalibParams(
            widthScale = 0.9711985f,
            heightScale = 1.112397f,
            offsetX = -0.009550562f,
            offsetY = -0.056292135f,
        ),
        KEY_LEFT_EYE to V3RegionCalibParams(
            widthScale = 1.0f,
            heightScale = 1.0f,
            offsetX = 0.0f,
            offsetY = 0.0f,
        ),
        KEY_RIGHT_EYE to V3RegionCalibParams(
            widthScale = 1.0f,
            heightScale = 1.0f,
            offsetX = 0.0f,
            offsetY = 0.0f,
        ),
        KEY_BROWS to V3RegionCalibParams(
            widthScale = 1.0033333f,
            heightScale = 1.35f,
            offsetX = -0.001011236f,
            offsetY = 0.012921348f,
        ),
        KEY_NOSE to V3RegionCalibParams(
            widthScale = 1.0f,
            heightScale = 1.0f,
            offsetX = 0.0f,
            offsetY = 0.0f,
        ),
        KEY_OUTER_LIPS to V3RegionCalibParams(
            widthScale = 0.8689513f,
            heightScale = 0.89524347f,
            offsetX = -0.0059550563f,
            offsetY = 0.016067415f,
        ),
        KEY_INNER_LIPS to V3RegionCalibParams(
            widthScale = 0.8962172f,
            heightScale = 1.045206f,
            offsetX = -0.0050561796f,
            offsetY = 0.0f,
        ),
        KEY_MOUTH_OPENING to V3RegionCalibParams(
            widthScale = 0.852397f,
            heightScale = 1.0f,
            offsetX = -0.003258427f,
            offsetY = 0.015168539f,
        ),
        KEY_LEFT_CHEEK to V3RegionCalibParams(
            widthScale = 1.0f,
            heightScale = 1.0f,
            offsetX = 0.0f,
            offsetY = 0.0f,
        ),
        KEY_RIGHT_CHEEK to V3RegionCalibParams(
            widthScale = 1.0f,
            heightScale = 1.0f,
            offsetX = 0.0f,
            offsetY = 0.0f,
        ),
    )

    private val lock = Any()
    private val params: LinkedHashMap<String, V3RegionCalibParams> = LinkedHashMap()

    init {
        for ((key, def) in ACCEPTED_DEFAULTS) {
            params[key] = def.copy()
        }
    }

    fun acceptedDefault(key: String): V3RegionCalibParams =
        ACCEPTED_DEFAULTS[key]?.copy() ?: V3RegionCalibParams()

    fun get(key: String): V3RegionCalibParams = synchronized(lock) {
        params.getOrPut(key) { acceptedDefault(key) }
    }

    fun snapshot(key: String): V3RegionCalibParams = synchronized(lock) {
        get(key).copy()
    }

    fun set(
        key: String,
        widthScale: Float? = null,
        heightScale: Float? = null,
        offsetX: Float? = null,
        offsetY: Float? = null,
    ) {
        synchronized(lock) {
            val p = get(key)
            if (widthScale != null) p.widthScale = widthScale.coerceIn(WIDTH_MIN, WIDTH_MAX)
            if (heightScale != null) p.heightScale = heightScale.coerceIn(HEIGHT_MIN, HEIGHT_MAX)
            if (offsetX != null) p.offsetX = offsetX.coerceIn(OFFSET_MIN, OFFSET_MAX)
            if (offsetY != null) p.offsetY = offsetY.coerceIn(OFFSET_MIN, OFFSET_MAX)
        }
    }

    fun resetRegion(key: String) {
        synchronized(lock) {
            get(key).copyFrom(acceptedDefault(key))
        }
    }

    fun resetAll() {
        synchronized(lock) {
            for (key in ACCEPTED_DEFAULTS.keys) {
                get(key).copyFrom(acceptedDefault(key))
            }
        }
    }

    /**
     * Applies region-local calibration around [cx],[cy] using face metrics.
     * Writes into [outU]/[outV] at [outOffset] (pairs).
     */
    fun applyToContour(
        key: String,
        srcU: FloatArray,
        srcV: FloatArray,
        pointCount: Int,
        cx: Float,
        cy: Float,
        faceWidth: Float,
        faceHeight: Float,
        outU: FloatArray,
        outV: FloatArray,
        outOffset: Int = 0,
    ) {
        val ws: Float
        val hs: Float
        val oxN: Float
        val oyN: Float
        synchronized(lock) {
            val p = get(key)
            ws = p.widthScale
            hs = p.heightScale
            oxN = p.offsetX
            oyN = p.offsetY
        }
        val fw = faceWidth.coerceAtLeast(1e-4f)
        val fh = faceHeight.coerceAtLeast(1e-4f)
        val ox = oxN * fw
        val oy = oyN * fh
        for (i in 0 until pointCount) {
            val x = srcU[i]
            val y = srcV[i]
            outU[outOffset + i] = cx + (x - cx) * ws + ox
            outV[outOffset + i] = cy + (y - cy) * hs + oy
        }
    }

    const val WIDTH_MIN = 0.70f
    const val WIDTH_MAX = 1.35f
    const val HEIGHT_MIN = 0.70f
    const val HEIGHT_MAX = 1.35f
    const val OFFSET_MIN = -0.15f
    const val OFFSET_MAX = 0.15f
}
