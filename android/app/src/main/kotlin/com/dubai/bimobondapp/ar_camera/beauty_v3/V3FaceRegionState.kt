package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * Builds / holds raw canonical landmark UVs and reusable region draw buffers.
 * Raw UVs are source-of-truth; calibration is applied only into draw buffers.
 */
object V3FaceRegionState {
    const val MAX_LANDMARKS = 478
    const val UV_FLOATS = MAX_LANDMARKS * 2
    const val MAX_CONTOUR_POINTS = 64
    const val MAX_DRAW_CONTOURS = 40

    private val lock = Any()

    /** Raw canonical UV after AnalysisToCanonical (immutable until next publish). */
    private val rawUv = FloatArray(UV_FLOATS) { Float.NaN }
    private var landmarkCount = 0
    private var valid = false
    private var cameraGen = -1L
    private var lensFront = true
    private var rotation = 0
    private var publishedAtMs = 0L

    private var faceWidth = 0.1f
    private var faceHeight = 0.1f
    private var faceCx = 0.5f
    private var faceCy = 0.5f

    // Working UV after head-motion (reused).
    private val motionUv = FloatArray(UV_FLOATS)

    // Per-contour draw: interleaved u,v for up to MAX_CONTOUR_POINTS
    private val drawU = Array(MAX_DRAW_CONTOURS) { FloatArray(MAX_CONTOUR_POINTS) }
    private val drawV = Array(MAX_DRAW_CONTOURS) { FloatArray(MAX_CONTOUR_POINTS) }
    private val drawCount = IntArray(MAX_DRAW_CONTOURS)
    private val drawClosed = BooleanArray(MAX_DRAW_CONTOURS)
    private val drawColor = Array(MAX_DRAW_CONTOURS) { FloatArray(3) }
    private var drawContourCount = 0

    // Scratch for centroid / teeth inset / publish mapping (outside draw lock path).
    private val scratchU = FloatArray(MAX_CONTOUR_POINTS)
    private val scratchV = FloatArray(MAX_CONTOUR_POINTS)
    private val pendingUv = FloatArray(UV_FLOATS)
    private val mapScratch = FloatArray(2)

    fun clear() {
        synchronized(lock) {
            valid = false
            landmarkCount = 0
            drawContourCount = 0
            rawUv.fill(Float.NaN)
        }
        V3TrackedFaceState.reset("region_clear")
        V3LipContourState.reset()
    }

    /** Latest camera generation for lip stabilizer reset (no lock hold by callers). */
    fun peekCameraGen(): Long = synchronized(lock) { cameraGen }

    /**
     * Full ordered lip strip polylines in motion-compensated canonical UV (+Y down).
     * Layout ([V3LipTopology.CONTOUR_FLOATS]):
     * upperOuter[11], upperInner[11], lowerOuter[11], lowerInner[11] as (u,v) pairs.
     * Does NOT use makeup mouth ellipses.
     */
    fun copyLipContours(out: FloatArray): Boolean {
        if (out.size < V3LipTopology.CONTOUR_FLOATS) return false
        if (V3TrackedFaceState.copyCachedLipContours(out)) return true
        return copyLipContoursUntracked(out)
    }

    private fun copyLipContoursUntracked(out: FloatArray): Boolean {
        val snapCount: Int
        val snapGen: Long
        val snapFront: Boolean
        val snapRot: Int
        synchronized(lock) {
            if (!valid || landmarkCount < 300) return false
            System.arraycopy(rawUv, 0, motionUv, 0, landmarkCount * 2)
            snapCount = landmarkCount
            snapGen = cameraGen
            snapFront = lensFront
            snapRot = rotation
        }
        V3HeadMotionPredictor.applyToUvPairs(
            motionUv,
            snapCount,
            SystemClock.elapsedRealtime(),
            snapGen,
            snapFront,
            snapRot,
        )
        return fillLipContoursFromUv(motionUv, snapCount, out)
    }

    /** Builds lip polylines from display-time UV (shared tracked state / fallback). */
    internal fun fillLipContoursFromUv(
        uv: FloatArray,
        snapCount: Int,
        out: FloatArray,
    ): Boolean {
        if (out.size < V3LipTopology.CONTOUR_FLOATS) return false
        fun put(polyline: IntArray, offset: Int): Boolean {
            for (i in polyline.indices) {
                val idx = polyline[i]
                if (idx < 0 || idx >= snapCount) return false
                val u = uv[idx * 2]
                val v = uv[idx * 2 + 1]
                if (!u.isFinite() || !v.isFinite()) return false
                out[offset + i * 2] = u
                out[offset + i * 2 + 1] = v
            }
            return true
        }
        if (!put(V3LipTopology.OUTER_UPPER, V3LipTopology.OFF_UPPER_OUTER)) return false
        if (!put(V3LipTopology.INNER_UPPER, V3LipTopology.OFF_UPPER_INNER)) return false
        if (!put(V3LipTopology.OUTER_LOWER, V3LipTopology.OFF_LOWER_OUTER)) return false
        if (!put(V3LipTopology.INNER_LOWER, V3LipTopology.OFF_LOWER_INNER)) return false
        return true
    }

    /** Face box metrics in canonical UV (width, height, cx, cy). */
    fun copyFaceMetrics(out: FloatArray): Boolean = synchronized(lock) {
        if (!valid || out.size < 4) return false
        out[0] = faceWidth
        out[1] = faceHeight
        out[2] = faceCx
        out[3] = faceCy
        return faceWidth > 1e-4f && faceHeight > 1e-4f
    }

    /**
     * Motion-compensated beauty / reshape anchors in canonical UV (top-left).
     * Does not alter calibration defaults.
     *
     * Layout (41 floats):
     * 0–3 faceW,faceH,cx,cy
     * 4–6 eyeL x,y,r | 7–9 eyeR x,y,r
     * 10–11 underEyeL | 12–13 underEyeR
     * 14–15 noseWingL | 16–17 noseWingR | 18–19 noseTip
     * 20–21 cheekL | 22–23 cheekR | 24–25 chin
     * 26 noseRadius | 27 cheekRadius
     * 28–29 mouthCenter | 30 mouthHalfW | 31 mouthHalfH
     * 32–33 toothCenter | 34 toothHalfW | 35 toothHalfH
     * 36–37 blushCheekL | 38–39 blushCheekR | 40 blushRadius
     */
    fun copyBeautyAnchors(out: FloatArray): Boolean {
        if (out.size < ANCHOR_FLOATS) return false
        if (V3TrackedFaceState.copyCachedBeautyAnchors(out)) return true
        return copyBeautyAnchorsUntracked(out)
    }

    private fun copyBeautyAnchorsUntracked(out: FloatArray): Boolean {
        val snapCount: Int
        val snapGen: Long
        val snapFront: Boolean
        val snapRot: Int
        val fw: Float
        val fh: Float
        val fcx: Float
        val fcy: Float
        synchronized(lock) {
            if (!valid || landmarkCount < 300) return false
            System.arraycopy(rawUv, 0, motionUv, 0, landmarkCount * 2)
            snapCount = landmarkCount
            snapGen = cameraGen
            snapFront = lensFront
            snapRot = rotation
            fw = faceWidth
            fh = faceHeight
            fcx = faceCx
            fcy = faceCy
        }
        V3HeadMotionPredictor.applyToUvPairs(
            motionUv,
            snapCount,
            SystemClock.elapsedRealtime(),
            snapGen,
            snapFront,
            snapRot,
        )
        return fillBeautyAnchorsFromUv(
            motionUv, snapCount, fw, fh, fcx, fcy, snapGen, out,
        )
    }

    /**
     * Builds beauty/reshape anchors from display-time UV.
     * Used by [V3TrackedFaceState] and untracked fallback.
     */
    internal fun fillBeautyAnchorsFromUv(
        motionUv: FloatArray,
        snapCount: Int,
        fw: Float,
        fh: Float,
        fcx: Float,
        fcy: Float,
        snapGen: Long,
        out: FloatArray,
    ): Boolean {
        if (out.size < ANCHOR_FLOATS) return false
        fun uv(index: Int, scratch: FloatArray = mapScratch): Boolean {
            if (index < 0 || index >= snapCount) return false
            val u = motionUv[index * 2]
            val v = motionUv[index * 2 + 1]
            if (!u.isFinite() || !v.isFinite()) return false
            scratch[0] = u
            scratch[1] = v
            return true
        }
        fun avg(indices: IntArray, scratch: FloatArray = mapScratch): Boolean {
            var sx = 0f
            var sy = 0f
            var n = 0
            for (idx in indices) {
                if (!uv(idx)) continue
                sx += mapScratch[0]
                sy += mapScratch[1]
                n++
            }
            if (n == 0) return false
            scratch[0] = sx / n
            scratch[1] = sy / n
            return true
        }

        out[0] = fw
        out[1] = fh
        out[2] = fcx
        out[3] = fcy

        if (!avg(intArrayOf(33, 133, 159, 145))) return false
        out[4] = mapScratch[0]
        out[5] = mapScratch[1]
        out[6] = (fw * 0.11f).coerceIn(0.02f, 0.12f)

        if (!avg(intArrayOf(263, 362, 386, 374))) return false
        out[7] = mapScratch[0]
        out[8] = mapScratch[1]
        out[9] = out[6]

        // Under-eye: slightly below eye centers.
        out[10] = out[4]
        out[11] = (out[5] + fh * 0.055f).coerceIn(0f, 1f)
        out[12] = out[7]
        out[13] = (out[8] + fh * 0.055f).coerceIn(0f, 1f)

        // Nose wings: extreme X in wing zone, clamped near tip band.
        var leftU = 1f
        var leftV = 0.5f
        var rightU = 0f
        var rightV = 0.5f
        var foundL = false
        var foundR = false
        for (idx in intArrayOf(98, 64, 48, 129, 219, 327, 294, 278, 358, 439)) {
            if (!uv(idx)) continue
            val u = mapScratch[0]
            val v = mapScratch[1]
            if (!foundL || u < leftU) {
                leftU = u
                leftV = v
                foundL = true
            }
            if (!foundR || u > rightU) {
                rightU = u
                rightV = v
                foundR = true
            }
        }
        if (!foundL || !foundR) return false
        if (!uv(1)) return false
        val tipU = mapScratch[0]
        val tipV = mapScratch[1]
        out[14] = leftU
        out[15] = leftV
        out[16] = rightU
        out[17] = rightV
        out[18] = tipU
        out[19] = tipV
        out[26] = ((rightU - leftU) * 0.72f).coerceAtLeast(fw * 0.04f)

        if (!uv(234)) return false
        out[20] = mapScratch[0]
        out[21] = mapScratch[1]
        if (!uv(454)) return false
        out[22] = mapScratch[0]
        out[23] = mapScratch[1]
        if (!uv(152)) return false
        out[24] = mapScratch[0]
        out[25] = mapScratch[1]
        // Bias cheek anchors slightly toward jaw for slim/lift.
        val chinY = out[25]
        val cheekY = (out[21] + out[23]) * 0.5f
        val shapeY = cheekY * 0.65f + chinY * 0.35f
        out[21] = shapeY
        out[23] = shapeY
        out[27] = (fw * 0.24f).coerceAtLeast(0.03f)

        // Outer lip center + half extents (lipstick).
        if (!uv(61)) return false
        val mouthLeftU = mapScratch[0]
        if (!uv(291)) return false
        val mouthRightU = mapScratch[0]
        if (!uv(0)) return false
        val mouthTopV = mapScratch[1]
        if (!uv(17)) return false
        val mouthBotV = mapScratch[1]
        out[28] = (mouthLeftU + mouthRightU) * 0.5f
        out[29] = (mouthTopV + mouthBotV) * 0.5f
        out[30] = ((mouthRightU - mouthLeftU) * 0.48f).coerceAtLeast(fw * 0.06f)
        out[31] = ((mouthBotV - mouthTopV) * 0.55f).coerceAtLeast(fh * 0.02f)

        // Inner mouth opening (exclude from lipstick).
        val ok78 = uv(78)
        val ilU = mapScratch[0]
        val ok308 = uv(308)
        val irU = mapScratch[0]
        val ok13 = uv(13)
        val itV = mapScratch[1]
        val ok14 = uv(14)
        val ibV = mapScratch[1]
        if (!(ok78 && ok308 && ok13 && ok14)) {
            out[32] = out[28]
            out[33] = out[29]
            out[34] = out[30] * 0.45f
            out[35] = out[31] * 0.35f
        } else {
            out[32] = (ilU + irU) * 0.5f
            out[33] = (itV + ibV) * 0.5f
            out[34] = ((irU - ilU) * 0.42f).coerceAtLeast(0.01f)
            out[35] = ((ibV - itV) * 0.42f).coerceAtLeast(0.008f)
        }

        // Blush apples — FRONT cheek body (not ear-side 234/454 extremes).
        // MediaPipe 50 / 280 sit on the cheek apples; contract toward face center
        // so placement stays below the eye, lateral to the nose, above the mouth.
        if (!uv(50)) return false
        val appleLU = mapScratch[0]
        val appleLV = mapScratch[1]
        if (!uv(280)) return false
        val appleRU = mapScratch[0]
        val appleRV = mapScratch[1]
        if (!uv(61)) return false
        val mouthCornerLY = mapScratch[1]
        if (!uv(291)) return false
        val mouthCornerRY = mapScratch[1]
        val mouthCornerY = (mouthCornerLY + mouthCornerRY) * 0.5f
        val eyeBotY = ((out[5] + out[8]) * 0.5f) + out[6] * 0.90f
        val noseSideLU = out[14]
        val noseSideRU = out[16]
        // Nose wings are extreme-X in image UV; normalize so left <= right even if a
        // transient pose swaps which landmark contributed which side.
        val noseLeftU = min(noseSideLU, noseSideRU)
        val noseRightU = max(noseSideLU, noseSideRU)
        // Inward from apple landmarks; clamp away from nose and outer face edge.
        // Margins can over-constrain on yaw / narrow nose (empty coerceIn range).
        val blushLeftU = safeClamp(
            value = appleLU * 0.62f + fcx * 0.38f,
            boundA = noseLeftU + fw * 0.06f,
            boundB = fcx - fw * 0.04f,
            name = "blushLeftU",
            cameraGen = snapGen,
        )
        val blushRightU = safeClamp(
            value = appleRU * 0.62f + fcx * 0.38f,
            boundA = fcx + fw * 0.04f,
            boundB = noseRightU - fw * 0.06f,
            name = "blushRightU",
            cameraGen = snapGen,
        )
        val blushY = safeClamp(
            value = appleLV * 0.35f + appleRV * 0.35f + eyeBotY * 0.18f + mouthCornerY * 0.12f,
            boundA = eyeBotY,
            boundB = mouthCornerY - fh * 0.03f,
            name = "blushY",
            cameraGen = snapGen,
        )
        out[36] = blushLeftU
        out[37] = blushY
        out[38] = blushRightU
        out[39] = blushY
        out[40] = (fw * 0.100f).coerceIn(0.022f, 0.085f)
        return true
    }

    /**
     * Allocation-free clamp that never throws on inverted / non-finite landmark bounds.
     * Normal frames (boundA <= boundB, finite) match [Float.coerceIn] exactly.
     * Degenerate ranges fall back to the unclamped base value.
     */
    private fun safeClamp(
        value: Float,
        boundA: Float,
        boundB: Float,
        name: String,
        cameraGen: Long,
    ): Float {
        if (!value.isFinite()) return value
        if (!boundA.isFinite() || !boundB.isFinite()) {
            noteBadAnchorRange(name, boundA, boundB, boundA, boundB, cameraGen, "non_finite")
            return value
        }
        val lo = min(boundA, boundB)
        val hi = max(boundA, boundB)
        if (boundA > boundB) {
            noteBadAnchorRange(name, boundA, boundB, lo, hi, cameraGen, "reversed")
        }
        // Effectively empty after normalize — keep semantic base anchor.
        if (hi - lo < 1e-4f) {
            noteBadAnchorRange(name, boundA, boundB, lo, hi, cameraGen, "degenerate")
            return value
        }
        return value.coerceIn(lo, hi)
    }

    private var lastAnchorRangeLogMs = 0L

    private fun noteBadAnchorRange(
        name: String,
        boundA: Float,
        boundB: Float,
        lo: Float,
        hi: Float,
        cameraGen: Long,
        reason: String,
    ) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastAnchorRangeLogMs < 1_000L) return
        lastAnchorRangeLogMs = now
        Log.w(
            "V3_BEAUTY_ANCHOR_RANGE",
            "name=$name reason=$reason " +
                "boundA=$boundA boundB=$boundB lo=$lo hi=$hi cameraGen=$cameraGen",
        )
    }

    const val ANCHOR_FLOATS = 41

    fun cameraMeta(out: LongArray, lensOut: BooleanArray): Boolean = synchronized(lock) {
        if (!valid) return false
        out[0] = cameraGen
        lensOut[0] = lensFront
        return true
    }

    /**
     * Publishes full mapped landmark UVs from MediaPipe (analysis thread).
     * Mapping runs outside [lock] to avoid nesting with AnalysisToCanonical.
     */
    fun publishFromMediaPipe(
        landmarks: List<NormalizedLandmark>,
        cameraGen: Long,
        lensFront: Boolean,
        rotationDegrees: Int,
        timestampMs: Long,
    ) {
        if (landmarks.size < 300) {
            clear()
            return
        }
        pendingUv.fill(Float.NaN)
        val n = landmarks.size.coerceAtMost(MAX_LANDMARKS)
        for (i in 0 until n) {
            val lm = landmarks[i]
            if (!V3AnalysisToCanonicalTransform.mapNormToCanonical(
                    lm.x(), lm.y(), mapScratch, 0,
                )
            ) {
                continue
            }
            pendingUv[i * 2] = mapScratch[0]
            pendingUv[i * 2 + 1] = mapScratch[1]
        }
        synchronized(lock) {
            System.arraycopy(pendingUv, 0, rawUv, 0, UV_FLOATS)
            landmarkCount = n
            this.cameraGen = cameraGen
            this.lensFront = lensFront
            this.rotation = rotationDegrees
            publishedAtMs = timestampMs
            updateFaceMetricsLocked()
            valid = faceWidth > 1e-4f && faceHeight > 1e-4f
            if (valid) {
                V3TrackedFaceState.pushObservation(
                    rawUv = rawUv,
                    pointCount = landmarkCount,
                    timestampMs = timestampMs,
                    cameraGen = cameraGen,
                    lensFront = lensFront,
                    rotationDegrees = rotationDegrees,
                    faceWidth = faceWidth,
                    faceHeight = faceHeight,
                    faceCx = faceCx,
                    faceCy = faceCy,
                )
            }
        }
    }

    /**
     * Prepares draw contours for [regionId] into internal buffers.
     * Applies head-motion compensation then region-local calibration.
     * @return number of contours ready to draw
     */
    fun prepareDraw(regionId: V3FaceRegionId): Int {
        // Prefer shared display-time UV from V3TrackedFaceState; fall back to
        // raw + global head predict if tracking has not advanced yet.
        var snapCount: Int
        var snapGen: Long
        var snapFront: Boolean
        var snapRot: Int
        var snapFw: Float
        var snapFh: Float
        synchronized(lock) {
            drawContourCount = 0
            if (!valid || landmarkCount < 300) return 0
            snapCount = landmarkCount
            snapGen = cameraGen
            snapFront = lensFront
            snapRot = rotation
            snapFw = faceWidth
            snapFh = faceHeight
        }

        if (regionId == V3FaceRegionId.RAW_LANDMARKS) {
            return 0
        }

        val trackedN = V3TrackedFaceState.copyDisplayUv(motionUv, snapCount)
        if (trackedN < 300) {
            synchronized(lock) {
                if (!valid || landmarkCount < 300) return 0
                System.arraycopy(rawUv, 0, motionUv, 0, landmarkCount * 2)
                snapCount = landmarkCount
                snapGen = cameraGen
                snapFront = lensFront
                snapRot = rotation
                snapFw = faceWidth
                snapFh = faceHeight
            }
            V3HeadMotionPredictor.applyToUvPairs(
                motionUv,
                snapCount,
                SystemClock.elapsedRealtime(),
                snapGen,
                snapFront,
                snapRot,
            )
        } else {
            snapCount = trackedN
        }

        synchronized(lock) {
            if (!valid || landmarkCount < 300) return 0
            val defs = V3FaceRegionTopology.contoursFor(regionId)
            for (def in defs) {
                if (drawContourCount >= MAX_DRAW_CONTOURS) break
                val slot = drawContourCount
                val count = fillContourFromUv(
                    def.indices,
                    motionUv,
                    snapCount,
                    scratchU,
                    scratchV,
                    requireIris = def.name == "iris",
                )
                if (count < 2) continue

                val useTeethInset = regionId == V3FaceRegionId.TEETH_CANDIDATE &&
                    def.name == "teeth_roi"
                if (useTeethInset) {
                    insetTowardCentroid(scratchU, scratchV, count, 0.35f)
                }

                var cx = 0f
                var cy = 0f
                for (i in 0 until count) {
                    cx += scratchU[i]
                    cy += scratchV[i]
                }
                cx /= count
                cy /= count

                val calibKey = calibrationKeyFor(regionId, def.name)
                V3FaceRegionCalibration.applyToContour(
                    key = calibKey,
                    srcU = scratchU,
                    srcV = scratchV,
                    pointCount = count,
                    cx = cx,
                    cy = cy,
                    faceWidth = snapFw,
                    faceHeight = snapFh,
                    outU = drawU[slot],
                    outV = drawV[slot],
                )

                drawCount[slot] = count
                drawClosed[slot] = def.kind == V3ContourKind.POLYGON
                drawColor[slot][0] = def.colorR
                drawColor[slot][1] = def.colorG
                drawColor[slot][2] = def.colorB
                drawContourCount++
            }
            return drawContourCount
        }
    }

    fun drawContourCount(): Int = synchronized(lock) { drawContourCount }

    fun copyContour(
        index: Int,
        outInterleavedUvRgb: FloatArray,
        maxFloats: Int,
    ): ContourDrawInfo? = synchronized(lock) {
        if (index < 0 || index >= drawContourCount) return null
        val n = drawCount[index]
        val need = n * 5
        if (need > maxFloats) return null
        var o = 0
        val col = drawColor[index]
        for (i in 0 until n) {
            outInterleavedUvRgb[o++] = drawU[index][i]
            outInterleavedUvRgb[o++] = drawV[index][i]
            outInterleavedUvRgb[o++] = col[0]
            outInterleavedUvRgb[o++] = col[1]
            outInterleavedUvRgb[o++] = col[2]
        }
        ContourDrawInfo(pointCount = n, closed = drawClosed[index], floatCount = o)
    }

    data class ContourDrawInfo(
        val pointCount: Int,
        val closed: Boolean,
        val floatCount: Int,
    )

    private fun calibrationKeyFor(regionId: V3FaceRegionId, contourName: String): String {
        return when (regionId) {
            V3FaceRegionId.CHEEKS ->
                if (contourName.startsWith("left")) {
                    V3FaceRegionCalibration.KEY_LEFT_CHEEK
                } else {
                    V3FaceRegionCalibration.KEY_RIGHT_CHEEK
                }
            else -> V3FaceRegionTopology.calibrationKey(regionId)
        }
    }

    private fun fillContourFromUv(
        indices: IntArray,
        uv: FloatArray,
        lmCount: Int,
        outU: FloatArray,
        outV: FloatArray,
        requireIris: Boolean,
    ): Int {
        var n = 0
        for (idx in indices) {
            if (idx < 0 || idx >= lmCount) {
                if (requireIris) return 0
                continue
            }
            val u = uv[idx * 2]
            val v = uv[idx * 2 + 1]
            if (!u.isFinite() || !v.isFinite()) {
                if (requireIris) return 0
                continue
            }
            if (n >= MAX_CONTOUR_POINTS) break
            outU[n] = u
            outV[n] = v
            n++
        }
        return n
    }

    private fun insetTowardCentroid(
        u: FloatArray,
        v: FloatArray,
        count: Int,
        amount: Float,
    ) {
        var cx = 0f
        var cy = 0f
        for (i in 0 until count) {
            cx += u[i]
            cy += v[i]
        }
        cx /= count
        cy /= count
        val t = amount.coerceIn(0f, 0.9f)
        for (i in 0 until count) {
            u[i] = u[i] + (cx - u[i]) * t
            v[i] = v[i] + (cy - v[i]) * t
        }
    }

    private val metricScratch = FloatArray(2)

    private fun updateFaceMetricsLocked() {
        if (!readUv(V3FaceRegionTopology.LEFT_CHEEK_POINT, metricScratch)) return
        val lx = metricScratch[0]
        val ly = metricScratch[1]
        if (!readUv(V3FaceRegionTopology.RIGHT_CHEEK_POINT, metricScratch)) return
        val rx = metricScratch[0]
        val ry = metricScratch[1]
        if (!readUv(V3FaceRegionTopology.FOREHEAD_POINT, metricScratch)) return
        val tx = metricScratch[0]
        val ty = metricScratch[1]
        if (!readUv(V3FaceRegionTopology.CHIN_POINT, metricScratch)) return
        val bx = metricScratch[0]
        val by = metricScratch[1]
        faceWidth = hypot(rx - lx, ry - ly).coerceAtLeast(1e-3f)
        faceHeight = hypot(bx - tx, by - ty).coerceAtLeast(1e-3f)
        faceCx = (lx + rx) * 0.5f
        faceCy = (ty + by) * 0.5f
    }

    private fun readUv(index: Int, out: FloatArray): Boolean {
        if (index < 0 || index >= landmarkCount) return false
        val u = rawUv[index * 2]
        val v = rawUv[index * 2 + 1]
        if (!u.isFinite() || !v.isFinite()) return false
        out[0] = u
        out[1] = v
        return true
    }
}
