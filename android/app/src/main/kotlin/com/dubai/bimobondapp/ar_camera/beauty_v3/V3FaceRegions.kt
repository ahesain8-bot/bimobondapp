package com.dubai.bimobondapp.ar_camera.beauty_v3

/**
 * Semantic face-region identifiers for V3-1.5 debug / future beauty.
 * Topology uses MediaPipe Face Mesh indices; see [V3FaceRegionTopology].
 */
enum class V3FaceRegionId {
    RAW_LANDMARKS,
    FACE,
    LEFT_EYE,
    RIGHT_EYE,
    BROWS,
    NOSE,
    OUTER_LIPS,
    INNER_LIPS,
    MOUTH_OPENING,
    CHEEKS,
    SKIN_BASE,
    TEETH_CANDIDATE,
    ALL,
}

/**
 * Contour kind within a region (polyline or closed polygon).
 */
enum class V3ContourKind {
    POLYLINE,
    POLYGON,
}

/**
 * One named contour: MediaPipe indices in draw order (closed when [kind] is POLYGON).
 */
data class V3RegionContourDef(
    val name: String,
    val indices: IntArray,
    val kind: V3ContourKind,
    val colorR: Float,
    val colorG: Float,
    val colorB: Float,
)

/**
 * MediaPipe Face Mesh topology for V3 semantic regions.
 *
 * Ordering follows MediaPipe ring conventions (counter-clockwise where applicable).
 * Iris indices (468–477) are optional — used only when landmark count ≥ 478.
 */
object V3FaceRegionTopology {
    // --- Face ---
    /** Anatomical face oval (closed). */
    val FACE_OVAL = intArrayOf(
        10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288,
        397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,
        172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109,
    )
    /** Forehead reference arc. */
    val FOREHEAD = intArrayOf(109, 10, 338, 297, 332)
    /** Chin / jaw lower arc. */
    val CHIN_JAW = intArrayOf(
        172, 136, 150, 149, 176, 148, 152, 377, 400, 378, 379, 365, 397,
    )
    /** Vertical center axis: forehead → nose bridge → tip → chin. */
    val FACE_CENTER_AXIS = intArrayOf(10, 168, 6, 197, 5, 4, 1, 152)

    // --- Left eye (subject's left = mesh 33…133) ---
    val LEFT_EYE_OUTER = intArrayOf(
        33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246,
    )
    val LEFT_EYE_UPPER = intArrayOf(246, 161, 160, 159, 158, 157, 173, 133)
    val LEFT_EYE_LOWER = intArrayOf(33, 7, 163, 144, 145, 153, 154, 155, 133)
    const val LEFT_INNER_CANTHUS = 133
    const val LEFT_OUTER_CANTHUS = 33
    /** Iris ring when refineLandmarks present. */
    val LEFT_IRIS = intArrayOf(468, 469, 470, 471, 472)

    // --- Right eye ---
    val RIGHT_EYE_OUTER = intArrayOf(
        362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398,
    )
    val RIGHT_EYE_UPPER = intArrayOf(466, 388, 387, 386, 385, 384, 398, 362)
    val RIGHT_EYE_LOWER = intArrayOf(263, 249, 390, 373, 374, 380, 381, 382, 362)
    const val RIGHT_INNER_CANTHUS = 362
    const val RIGHT_OUTER_CANTHUS = 263
    val RIGHT_IRIS = intArrayOf(473, 474, 475, 476, 477)

    // --- Brows ---
    val LEFT_BROW = intArrayOf(70, 63, 105, 66, 107, 55, 65, 52, 53, 46)
    val RIGHT_BROW = intArrayOf(300, 293, 334, 296, 336, 285, 295, 282, 283, 276)

    // --- Nose ---
    val NOSE_BRIDGE = intArrayOf(168, 6, 197, 195, 5)
    val NOSE_TIP = intArrayOf(5, 4, 1, 19, 94)
    val NOSE_LEFT_ALA = intArrayOf(129, 49, 48, 64, 98, 97, 2)
    val NOSE_RIGHT_ALA = intArrayOf(358, 279, 278, 294, 327, 326, 2)
    val NOSE_BASE = intArrayOf(98, 97, 2, 326, 327)
    val NOSE_CENTER_AXIS = intArrayOf(168, 6, 197, 195, 5, 4, 1)

    // --- Lips / mouth ---
    /** Outer vermilion (closed). */
    val LIPS_OUTER = intArrayOf(
        61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291,
        409, 270, 269, 267, 0, 37, 39, 40, 185,
    )
    /** Inner lip contour (closed) — separate from outer and from teeth ROI. */
    val LIPS_INNER = intArrayOf(
        78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308,
        415, 310, 311, 312, 13, 82, 81, 80, 191,
    )
    /** Mouth opening polygon = inner lip ring (same indices, distinct semantic id). */
    val MOUTH_OPENING = LIPS_INNER
    val UPPER_LIP = intArrayOf(61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291)
    val LOWER_LIP = intArrayOf(61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291)
    /** Upper visible-mouth candidate (inner-lip upper arc). */
    val MOUTH_UPPER_CANDIDATE = intArrayOf(78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308)
    /** Lower visible-mouth candidate (inner-lip lower arc). */
    val MOUTH_LOWER_CANDIDATE = intArrayOf(78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308)
    const val MOUTH_LEFT_CORNER = 61
    const val MOUTH_RIGHT_CORNER = 291

    // --- Cheeks (face-relative polygons) ---
    val LEFT_CHEEK = intArrayOf(234, 93, 132, 58, 172, 136, 150, 187, 147, 123, 116, 111, 31)
    val RIGHT_CHEEK = intArrayOf(454, 323, 361, 288, 397, 365, 379, 411, 376, 352, 345, 340, 261)

    // Face metric anchors
    const val FOREHEAD_POINT = 10
    const val CHIN_POINT = 152
    const val LEFT_CHEEK_POINT = 234
    const val RIGHT_CHEEK_POINT = 454

    fun contoursFor(id: V3FaceRegionId): List<V3RegionContourDef> = when (id) {
        V3FaceRegionId.RAW_LANDMARKS -> emptyList()
        V3FaceRegionId.FACE -> listOf(
            V3RegionContourDef("face_oval", FACE_OVAL, V3ContourKind.POLYGON, 0.95f, 0.95f, 0.95f),
            V3RegionContourDef("forehead", FOREHEAD, V3ContourKind.POLYLINE, 0.7f, 0.85f, 1f),
            V3RegionContourDef("chin_jaw", CHIN_JAW, V3ContourKind.POLYLINE, 0.85f, 0.75f, 0.55f),
            V3RegionContourDef("center_axis", FACE_CENTER_AXIS, V3ContourKind.POLYLINE, 0.3f, 1f, 0.5f),
        )
        V3FaceRegionId.LEFT_EYE -> listOf(
            V3RegionContourDef("outer", LEFT_EYE_OUTER, V3ContourKind.POLYGON, 0.15f, 0.95f, 0.35f),
            V3RegionContourDef("upper", LEFT_EYE_UPPER, V3ContourKind.POLYLINE, 0.4f, 1f, 0.6f),
            V3RegionContourDef("lower", LEFT_EYE_LOWER, V3ContourKind.POLYLINE, 0.2f, 0.7f, 0.4f),
            V3RegionContourDef(
                "canthi",
                intArrayOf(LEFT_OUTER_CANTHUS, LEFT_INNER_CANTHUS),
                V3ContourKind.POLYLINE,
                1f, 1f, 0.3f,
            ),
            V3RegionContourDef("iris", LEFT_IRIS, V3ContourKind.POLYGON, 0.9f, 0.9f, 0.2f),
        )
        V3FaceRegionId.RIGHT_EYE -> listOf(
            V3RegionContourDef("outer", RIGHT_EYE_OUTER, V3ContourKind.POLYGON, 0.35f, 0.85f, 1f),
            V3RegionContourDef("upper", RIGHT_EYE_UPPER, V3ContourKind.POLYLINE, 0.5f, 0.9f, 1f),
            V3RegionContourDef("lower", RIGHT_EYE_LOWER, V3ContourKind.POLYLINE, 0.25f, 0.65f, 0.9f),
            V3RegionContourDef(
                "canthi",
                intArrayOf(RIGHT_OUTER_CANTHUS, RIGHT_INNER_CANTHUS),
                V3ContourKind.POLYLINE,
                1f, 1f, 0.3f,
            ),
            V3RegionContourDef("iris", RIGHT_IRIS, V3ContourKind.POLYGON, 0.9f, 0.9f, 0.2f),
        )
        V3FaceRegionId.BROWS -> listOf(
            V3RegionContourDef("left_brow", LEFT_BROW, V3ContourKind.POLYLINE, 0.95f, 0.7f, 0.3f),
            V3RegionContourDef("right_brow", RIGHT_BROW, V3ContourKind.POLYLINE, 0.95f, 0.55f, 0.25f),
        )
        V3FaceRegionId.NOSE -> listOf(
            V3RegionContourDef("bridge", NOSE_BRIDGE, V3ContourKind.POLYLINE, 0.25f, 0.45f, 1f),
            V3RegionContourDef("tip", NOSE_TIP, V3ContourKind.POLYLINE, 0.4f, 0.6f, 1f),
            V3RegionContourDef("left_ala", NOSE_LEFT_ALA, V3ContourKind.POLYLINE, 0.5f, 0.7f, 1f),
            V3RegionContourDef("right_ala", NOSE_RIGHT_ALA, V3ContourKind.POLYLINE, 0.5f, 0.7f, 1f),
            V3RegionContourDef("base", NOSE_BASE, V3ContourKind.POLYLINE, 0.35f, 0.5f, 0.95f),
            V3RegionContourDef("axis", NOSE_CENTER_AXIS, V3ContourKind.POLYLINE, 0.2f, 1f, 0.8f),
        )
        V3FaceRegionId.OUTER_LIPS -> listOf(
            V3RegionContourDef("outer", LIPS_OUTER, V3ContourKind.POLYGON, 1f, 0.25f, 0.35f),
            V3RegionContourDef("upper", UPPER_LIP, V3ContourKind.POLYLINE, 1f, 0.4f, 0.5f),
            V3RegionContourDef("lower", LOWER_LIP, V3ContourKind.POLYLINE, 0.9f, 0.2f, 0.35f),
        )
        V3FaceRegionId.INNER_LIPS -> listOf(
            V3RegionContourDef("inner", LIPS_INNER, V3ContourKind.POLYGON, 1f, 0.55f, 0.95f),
        )
        V3FaceRegionId.MOUTH_OPENING -> listOf(
            V3RegionContourDef("opening", MOUTH_OPENING, V3ContourKind.POLYGON, 1f, 0.8f, 0.4f),
        )
        V3FaceRegionId.CHEEKS -> listOf(
            V3RegionContourDef("left_cheek", LEFT_CHEEK, V3ContourKind.POLYGON, 1f, 0.6f, 0.45f),
            V3RegionContourDef("right_cheek", RIGHT_CHEEK, V3ContourKind.POLYGON, 1f, 0.5f, 0.4f),
        )
        V3FaceRegionId.SKIN_BASE -> listOf(
            V3RegionContourDef("skin_face", FACE_OVAL, V3ContourKind.POLYGON, 0.6f, 0.9f, 0.7f),
        )
        V3FaceRegionId.TEETH_CANDIDATE -> listOf(
            V3RegionContourDef("mouth_opening", MOUTH_OPENING, V3ContourKind.POLYGON, 0.5f, 0.5f, 0.55f),
            V3RegionContourDef(
                "upper_mouth",
                MOUTH_UPPER_CANDIDATE,
                V3ContourKind.POLYLINE,
                0.7f, 0.75f, 0.9f,
            ),
            V3RegionContourDef(
                "lower_mouth",
                MOUTH_LOWER_CANDIDATE,
                V3ContourKind.POLYLINE,
                0.65f, 0.7f, 0.85f,
            ),
            // Teeth ROI: same ring, inset toward centroid in V3FaceRegionState (not true teeth).
            V3RegionContourDef("teeth_roi", MOUTH_OPENING, V3ContourKind.POLYGON, 0.95f, 0.95f, 1f),
        )
        V3FaceRegionId.ALL -> (
            contoursFor(V3FaceRegionId.FACE) +
                contoursFor(V3FaceRegionId.LEFT_EYE) +
                contoursFor(V3FaceRegionId.RIGHT_EYE) +
                contoursFor(V3FaceRegionId.BROWS) +
                contoursFor(V3FaceRegionId.NOSE) +
                contoursFor(V3FaceRegionId.OUTER_LIPS) +
                contoursFor(V3FaceRegionId.INNER_LIPS) +
                contoursFor(V3FaceRegionId.MOUTH_OPENING) +
                contoursFor(V3FaceRegionId.CHEEKS) +
                contoursFor(V3FaceRegionId.SKIN_BASE) +
                contoursFor(V3FaceRegionId.TEETH_CANDIDATE)
            )
    }

    /** Calibration bucket for a debug selection. */
    fun calibrationKey(id: V3FaceRegionId): String = when (id) {
        V3FaceRegionId.RAW_LANDMARKS, V3FaceRegionId.ALL -> "face_oval"
        V3FaceRegionId.FACE, V3FaceRegionId.SKIN_BASE -> "face_oval"
        V3FaceRegionId.LEFT_EYE -> "left_eye"
        V3FaceRegionId.RIGHT_EYE -> "right_eye"
        V3FaceRegionId.BROWS -> "brows"
        V3FaceRegionId.NOSE -> "nose"
        V3FaceRegionId.OUTER_LIPS -> "outer_lips"
        V3FaceRegionId.INNER_LIPS -> "inner_lips"
        V3FaceRegionId.MOUTH_OPENING, V3FaceRegionId.TEETH_CANDIDATE -> "mouth_opening"
        V3FaceRegionId.CHEEKS -> "left_cheek" // UI can also edit right via offset; default left
    }
}
