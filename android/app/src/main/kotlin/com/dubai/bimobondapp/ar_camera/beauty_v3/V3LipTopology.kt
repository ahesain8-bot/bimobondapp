package com.dubai.bimobondapp.ar_camera.beauty_v3

/**
 * Fixed multi-ring lip mesh topology for volumetric filler warp.
 *
 * Per lip, along each outer↔inner pair (11 columns):
 *   RING0 anchor → RING1 skinSupport → RING2 outer → RING3 lipBody → RING4 inner
 *
 * Upper and lower lips are separate strips (shared corner landmarks only in contour data).
 */
internal object V3LipTopology {
    /** Outer upper arc, right corner → left corner. */
    val OUTER_UPPER = intArrayOf(291, 409, 270, 269, 267, 0, 37, 39, 40, 185, 61)

    /** Inner upper arc, right → left (paired with [OUTER_UPPER]). */
    val INNER_UPPER = intArrayOf(308, 415, 310, 311, 312, 13, 82, 81, 80, 191, 78)

    /** Outer lower arc, left corner → right corner. */
    val OUTER_LOWER = intArrayOf(61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291)

    /** Inner lower arc, left → right (paired with [OUTER_LOWER]). */
    val INNER_LOWER = intArrayOf(78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308)

    const val PAIRS = 11
    const val QUADS = PAIRS - 1 // 10
    const val LIP_COUNT = 2

    const val RING_ANCHOR = 0
    const val RING_SKIN = 1
    const val RING_OUTER = 2
    const val RING_BODY = 3
    const val RING_INNER = 4
    const val RINGS = 5

    /** Vertices per lip: rings × pairs. */
    const val VERTS_PER_LIP = RINGS * PAIRS // 55
    const val TOTAL_VERTS = VERTS_PER_LIP * LIP_COUNT // 110

    /** Bands between consecutive rings × quads × 2 tris × lips. */
    const val BANDS = RINGS - 1 // 4
    const val TRIS_PER_LIP = BANDS * QUADS * 2 // 80
    const val TOTAL_TRIS = TRIS_PER_LIP * LIP_COUNT // 160
    const val INDEX_COUNT = TOTAL_TRIS * 3 // 480

    /** Contour float count: 4 polylines × 11 × (u,v). */
    const val CONTOUR_FLOATS = PAIRS * 2 * 4 // 88

    const val OFF_UPPER_OUTER = 0
    const val OFF_UPPER_INNER = PAIRS * 2 // 22
    const val OFF_LOWER_OUTER = PAIRS * 2 * 2 // 44
    const val OFF_LOWER_INNER = PAIRS * 2 * 3 // 66

    /**
     * Relative displacement along local outward (outer−inner), vs outer = 1.
     * Spreads filler so vermilion translates more than it scales.
     */
    val RING_DISP = floatArrayOf(
        0.00f, // anchor
        0.24f, // skin support
        1.00f, // outer lips
        0.72f, // lip body (moves with outer → less body stretch)
        0.12f, // inner lips
    )

    /**
     * How much source UV follows target displacement (1 = rigid slide, 0 = rest UV).
     * Skin follows (absorb expansion); vermilion mostly holds texture density.
     */
    val RING_UV_FOLLOW = floatArrayOf(
        1.00f, // anchor: identity
        0.90f, // skin: slide with warp
        0.28f, // outer: keep near original rim
        0.22f, // body: preserve mid-vermilion scale
        0.18f, // inner: mostly fixed sampling
    )

    /** Horizontal body weight per pair (center strong, corners ~0.25). */
    val PAIR_WEIGHT: FloatArray = FloatArray(PAIRS) { i ->
        val edge = kotlin.math.abs(i - (PAIRS - 1) * 0.5f) / ((PAIRS - 1) * 0.5f)
        (0.25f + 0.75f * kotlin.math.cos((edge.coerceIn(0f, 1f) * (Math.PI * 0.5)).toFloat())
            .coerceIn(0f, 1f))
    }

    fun vertIndex(lipBase: Int, ring: Int, pair: Int): Int =
        lipBase + ring * PAIRS + pair

    /** Prebuilt triangle indices (upper then lower). */
    val INDICES: ShortArray = ShortArray(INDEX_COUNT).also { out ->
        var w = 0
        fun emitLip(base: Int) {
            for (band in 0 until BANDS) {
                val r0 = base + band * PAIRS
                val r1 = base + (band + 1) * PAIRS
                for (i in 0 until QUADS) {
                    val a = (r0 + i).toShort()
                    val b = (r0 + i + 1).toShort()
                    val c = (r1 + i).toShort()
                    val d = (r1 + i + 1).toShort()
                    out[w++] = a; out[w++] = b; out[w++] = c
                    out[w++] = b; out[w++] = d; out[w++] = c
                }
            }
        }
        emitLip(0)
        emitLip(VERTS_PER_LIP)
    }
}
