package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.os.SystemClock
import android.util.Log
import com.dubai.bimobondapp.ar_camera.MediaPipeLandmarkIndices
import kotlin.math.hypot

/**
 * Sole display-time face geometry source for all V3 effects.
 *
 * Hybrid loop:
 * - [applyVisualMotion] — per-frame sparse optical tracking (camera FPS)
 * - [pushMediaPipeCorrection] — soft re-anchor from MediaPipe (~ML FPS)
 * - [advance] — present mesh at SurfaceTexture / display timestamp
 *
 * MediaPipe is ground truth; optical tracking bridges ML gaps.
 * Effects must consume cached anchors / lip contours / display UV only.
 */
object V3TrackedFaceState {
    private val lock = Any()

    private val meshUv = FloatArray(V3FaceRegionState.UV_FLOATS)
    private val displayUv = FloatArray(V3FaceRegionState.UV_FLOATS)
    private val mpUv = FloatArray(V3FaceRegionState.UV_FLOATS)
    private val filterX = FloatArray(V3FaceRegionState.UV_FLOATS)

    private var meshCount = 0
    private var meshTsMs = 0L
    private var hasMesh = false
    private var hasFilter = false

    private var cameraGen = -1L
    private var lensFront = true
    private var rotation = 0
    private var faceW = 0.1f
    private var faceH = 0.1f
    private var faceCx = 0.5f
    private var faceCy = 0.5f

    private var lastVisTx = 0f
    private var lastVisTy = 0f
    private var lastVisRot = 0f
    private var lastVisScale = 1f
    private var lastVisCx = 0.5f
    private var lastVisCy = 0.5f
    private var lastVisDtMs = 16f
    private var lastVisConf = 0f
    private var lastCorrectMag = 0f

    private val cachedAnchors = FloatArray(V3FaceRegionState.ANCHOR_FLOATS)
    private val cachedContours = FloatArray(V3LipTopology.CONTOUR_FLOATS)
    private var anchorsValid = false
    private var contoursValid = false
    private var advancedFrameGen = -1L

    private var renderFramesInWindow = 0
    private var renderWindowStartMs = 0L
    private var lastRenderFps = 0f

    // Geometry age stats at render (ms)
    private val ageHist = FloatArray(AGE_HIST)
    private var ageHistN = 0
    private var ageHistWrite = 0
    private var lastMedianAge = 0f
    private var lastP95Age = 0f

    private var lastDiagMs = 0L

    private val isMouth = BooleanArray(V3FaceRegionState.MAX_LANDMARKS)
    private val isEye = BooleanArray(V3FaceRegionState.MAX_LANDMARKS)
    private val isBrow = BooleanArray(V3FaceRegionState.MAX_LANDMARKS)

    @Volatile
    var valid: Boolean = false
        private set

    init {
        mark(isMouth, V3LipTopology.OUTER_UPPER)
        mark(isMouth, V3LipTopology.INNER_UPPER)
        mark(isMouth, V3LipTopology.OUTER_LOWER)
        mark(isMouth, V3LipTopology.INNER_LOWER)
        mark(isMouth, MediaPipeLandmarkIndices.UPPER_LIP)
        mark(isMouth, MediaPipeLandmarkIndices.LOWER_LIP)
        mark(isMouth, MediaPipeLandmarkIndices.LIPS_OUTER)
        mark(isEye, MediaPipeLandmarkIndices.LEFT_EYE)
        mark(isEye, MediaPipeLandmarkIndices.RIGHT_EYE)
        mark(isEye, MediaPipeLandmarkIndices.LEFT_EYE_BULGE)
        mark(isEye, MediaPipeLandmarkIndices.RIGHT_EYE_BULGE)
        mark(isBrow, MediaPipeLandmarkIndices.LEFT_EYEBROW)
        mark(isBrow, MediaPipeLandmarkIndices.RIGHT_EYEBROW)
    }

    fun reset(reason: String) {
        synchronized(lock) {
            hasMesh = false
            meshCount = 0
            hasFilter = false
            anchorsValid = false
            contoursValid = false
            advancedFrameGen = -1L
            lastVisConf = 0f
            valid = false
            try {
                V3SparseFaceTracker.reset(reason)
            } catch (t: Throwable) {
                Log.e(TAG, "sparse tracker reset failed (non-fatal)", t)
            }
            Log.i(TAG, "reset reason=$reason")
        }
    }

    /**
     * Soft MediaPipe re-anchor at the **original camera-frame** timestamp.
     * Blends toward MP without snapping; reseeds visual tracker externally.
     */
    fun pushMediaPipeCorrection(
        rawUv: FloatArray,
        pointCount: Int,
        frameTsMs: Long,
        cameraGen: Long,
        lensFront: Boolean,
        rotationDegrees: Int,
        faceWidth: Float,
        faceHeight: Float,
        faceCx: Float,
        faceCy: Float,
    ) {
        if (pointCount < 300) {
            reset("landmarks_short")
            return
        }
        synchronized(lock) {
            val discontinuity =
                this.cameraGen != -1L &&
                    (cameraGen != this.cameraGen ||
                        lensFront != this.lensFront ||
                        rotationDegrees != this.rotation)
            val jump = hasMesh &&
                hypot(faceCx - this.faceCx, faceCy - this.faceCy) > MAX_CENTER_JUMP_UV
            if (discontinuity || jump) {
                hasMesh = false
                hasFilter = false
                anchorsValid = false
                contoursValid = false
                advancedFrameGen = -1L
                try {
                    V3SparseFaceTracker.reset(
                        if (discontinuity) "mapping_discontinuity" else "major_jump",
                    )
                } catch (t: Throwable) {
                    Log.e(TAG, "sparse tracker reacquire reset failed (non-fatal)", t)
                }
                Log.i(
                    TAG,
                    "reacquire reason=${if (discontinuity) "mapping_discontinuity" else "major_jump"}",
                )
            }

            System.arraycopy(rawUv, 0, mpUv, 0, pointCount * 2)
            this.cameraGen = cameraGen
            this.lensFront = lensFront
            this.rotation = rotationDegrees
            this.faceW = faceWidth
            this.faceH = faceHeight
            this.faceCx = faceCx
            this.faceCy = faceCy

            if (!hasMesh) {
                System.arraycopy(rawUv, 0, meshUv, 0, pointCount * 2)
                meshCount = pointCount
                meshTsMs = frameTsMs
                hasMesh = true
                lastCorrectMag = 0f
            } else {
                // Soft correction: larger error → slightly stronger blend, never snap.
                var sum = 0f
                var n = 0
                val floats = pointCount * 2
                for (i in 0 until floats) {
                    val a = meshUv[i]
                    val b = rawUv[i]
                    if (!a.isFinite() || !b.isFinite()) {
                        meshUv[i] = b
                        continue
                    }
                    val d = b - a
                    sum += kotlin.math.abs(d)
                    n++
                    val alpha = when {
                        kotlin.math.abs(d) > 0.04f -> CORRECT_ALPHA_FAST
                        kotlin.math.abs(d) > 0.015f -> CORRECT_ALPHA_MED
                        else -> CORRECT_ALPHA_SLOW
                    }
                    meshUv[i] = a + d * alpha
                }
                lastCorrectMag = if (n > 0) sum / n else 0f
                meshCount = pointCount
                // Geometry time becomes MP frame time (optical will carry forward).
                if (frameTsMs >= meshTsMs) meshTsMs = frameTsMs
            }
            valid = true
            advancedFrameGen = -1L
            V3CameraClock.Latency.noteGeometry(meshTsMs)

            // Keep head-velocity predictor fed for OF-failure fallback only.
            // Use frame time so ages are camera-based.
        }
    }

    /**
     * Apply observed optical motion from sparse LK (analysis thread).
     */
    fun applyVisualMotion(
        frameTsMs: Long,
        sampleDtMs: Float,
        cx: Float,
        cy: Float,
        cosR: Float,
        sinR: Float,
        scale: Float,
        tx: Float,
        ty: Float,
        localIdx: IntArray,
        localDu: FloatArray,
        localDv: FloatArray,
        localN: Int,
        confidence: Float,
    ): Boolean {
        synchronized(lock) {
            if (!hasMesh || meshCount < 300) return false
            if (confidence < 0.25f) return false
            if (frameTsMs + 1L < meshTsMs) return false // stale

            val count = meshCount
            for (i in 0 until count) {
                val o = i * 2
                val u = meshUv[o]
                val v = meshUv[o + 1]
                if (!u.isFinite() || !v.isFinite()) continue
                val dx = u - cx
                val dy = v - cy
                meshUv[o] = cx + (cosR * dx - sinR * dy) * scale + tx
                meshUv[o + 1] = cy + (sinR * dx + cosR * dy) * scale + ty
            }

            // Local residuals: control landmarks + propagate to region members.
            val mouthDu: Float
            val mouthDv: Float
            val eyeDu: Float
            val eyeDv: Float
            val browDu: Float
            val browDv: Float
            run {
                var mDu = 0f
                var mDv = 0f
                var mN = 0
                var eDu = 0f
                var eDv = 0f
                var eN = 0
                var bDu = 0f
                var bDv = 0f
                var bN = 0
                for (k in 0 until localN) {
                    val id = localIdx[k]
                    if (id < 0 || id >= count) continue
                    val o = id * 2
                    meshUv[o] += localDu[k]
                    meshUv[o + 1] += localDv[k]
                    when {
                        id < isMouth.size && isMouth[id] -> {
                            mDu += localDu[k]; mDv += localDv[k]; mN++
                        }
                        id < isEye.size && isEye[id] -> {
                            eDu += localDu[k]; eDv += localDv[k]; eN++
                        }
                        id < isBrow.size && isBrow[id] -> {
                            bDu += localDu[k]; bDv += localDv[k]; bN++
                        }
                    }
                }
                mouthDu = if (mN > 0) mDu / mN else 0f
                mouthDv = if (mN > 0) mDv / mN else 0f
                eyeDu = if (eN > 0) eDu / eN else 0f
                eyeDv = if (eN > 0) eDv / eN else 0f
                browDu = if (bN > 0) bDu / bN else 0f
                browDv = if (bN > 0) bDv / bN else 0f
            }
            // Propagate average local residual to non-control region landmarks
            // (control points already received exact residual above — skip double).
            val touched = BooleanArray(count)
            for (k in 0 until localN) {
                val id = localIdx[k]
                if (id in 0 until count) touched[id] = true
            }
            if (mouthDu != 0f || mouthDv != 0f) {
                for (i in 0 until count) {
                    if (touched[i] || i >= isMouth.size || !isMouth[i]) continue
                    meshUv[i * 2] += mouthDu * 0.85f
                    meshUv[i * 2 + 1] += mouthDv * 0.85f
                }
            }
            if (eyeDu != 0f || eyeDv != 0f) {
                for (i in 0 until count) {
                    if (touched[i] || i >= isEye.size || !isEye[i]) continue
                    meshUv[i * 2] += eyeDu * 0.75f
                    meshUv[i * 2 + 1] += eyeDv * 0.75f
                }
            }
            if (browDu != 0f || browDv != 0f) {
                for (i in 0 until count) {
                    if (touched[i] || i >= isBrow.size || !isBrow[i]) continue
                    meshUv[i * 2] += browDu * 0.75f
                    meshUv[i * 2 + 1] += browDv * 0.75f
                }
            }

            lastVisTx = tx
            lastVisTy = ty
            lastVisRot = kotlin.math.atan2(sinR, cosR)
            lastVisScale = scale
            lastVisCx = cx
            lastVisCy = cy
            lastVisDtMs = sampleDtMs.coerceAtLeast(1f)
            lastVisConf = confidence
            meshTsMs = frameTsMs
            advancedFrameGen = -1L
            V3CameraClock.Latency.noteGeometry(meshTsMs)
            return true
        }
    }

    /**
     * GL-thread: materialize display geometry for [displayTimeMs] (camera/ST clock).
     */
    fun advance(frameGeneration: Long, displayTimeMs: Long): Boolean {
        synchronized(lock) {
            if (!hasMesh || meshCount < 300) {
                anchorsValid = false
                contoursValid = false
                return false
            }
            if (advancedFrameGen == frameGeneration && anchorsValid) {
                noteRenderLocked(displayTimeMs)
                return true
            }

            val count = meshCount
            System.arraycopy(meshUv, 0, displayUv, 0, count * 2)

            // Bridge last visual/MP sample → current display camera timestamp.
            val age = (displayTimeMs - meshTsMs).toFloat()
            lastMedianAge = age // provisional; stats updated below
            if (age > 1f && age < MAX_BRIDGE_MS && lastVisConf >= 0.30f) {
                val t = (age / lastVisDtMs).coerceIn(0f, MAX_BRIDGE_RATIO)
                val tx = (lastVisTx * t).coerceIn(-MAX_BRIDGE_UV, MAX_BRIDGE_UV)
                val ty = (lastVisTy * t).coerceIn(-MAX_BRIDGE_UV, MAX_BRIDGE_UV)
                if (kotlin.math.abs(tx) > 1e-5f || kotlin.math.abs(ty) > 1e-5f) {
                    for (i in 0 until count) {
                        val o = i * 2
                        if (!displayUv[o].isFinite()) continue
                        displayUv[o] += tx
                        displayUv[o + 1] += ty
                    }
                }
            } else if (age > 1f && age < MAX_BRIDGE_MS && lastVisConf < 0.30f) {
                // OF weak: bounded global head predictor fallback only.
                V3HeadMotionPredictor.applyToUvPairs(
                    displayUv,
                    count,
                    displayTimeMs,
                    cameraGen,
                    lensFront,
                    rotation,
                )
            }

            // Near-identity filter during motion; light damp only when still.
            applyAdaptiveStillFilterLocked(displayTimeMs, count)

            anchorsValid = V3FaceRegionState.fillBeautyAnchorsFromUv(
                displayUv, count, faceW, faceH, faceCx, faceCy, cameraGen, cachedAnchors,
            )
            contoursValid = V3FaceRegionState.fillLipContoursFromUv(
                displayUv, count, cachedContours,
            )
            advancedFrameGen = frameGeneration
            noteAgeLocked(age.coerceAtLeast(0f))
            noteRenderLocked(displayTimeMs)
            V3CameraClock.Latency.noteRender(
                surfaceTsNs = displayTimeMs * 1_000_000L,
                geometryTsMs = meshTsMs,
            )
            logDiagLocked(age)
            return anchorsValid
        }
    }

    fun copyCachedBeautyAnchors(out: FloatArray): Boolean {
        if (out.size < V3FaceRegionState.ANCHOR_FLOATS) return false
        synchronized(lock) {
            if (!anchorsValid || advancedFrameGen < 0L) return false
            System.arraycopy(cachedAnchors, 0, out, 0, V3FaceRegionState.ANCHOR_FLOATS)
            return true
        }
    }

    fun copyCachedLipContours(out: FloatArray): Boolean {
        if (out.size < V3LipTopology.CONTOUR_FLOATS) return false
        synchronized(lock) {
            if (!contoursValid || advancedFrameGen < 0L) return false
            System.arraycopy(cachedContours, 0, out, 0, V3LipTopology.CONTOUR_FLOATS)
            return true
        }
    }

    fun copyDisplayUv(out: FloatArray, maxPoints: Int): Int {
        synchronized(lock) {
            if (!hasMesh || meshCount < 300 || advancedFrameGen < 0L) return 0
            val n = meshCount.coerceAtMost(maxPoints)
            System.arraycopy(displayUv, 0, out, 0, n * 2)
            return n
        }
    }

    /** Compatibility shim — routes to soft MediaPipe correction. */
    fun pushObservation(
        rawUv: FloatArray,
        pointCount: Int,
        timestampMs: Long,
        cameraGen: Long,
        lensFront: Boolean,
        rotationDegrees: Int,
        faceWidth: Float,
        faceHeight: Float,
        faceCx: Float,
        faceCy: Float,
    ) {
        pushMediaPipeCorrection(
            rawUv, pointCount, timestampMs, cameraGen, lensFront,
            rotationDegrees, faceWidth, faceHeight, faceCx, faceCy,
        )
    }

    // --- filters / stats ---------------------------------------------------

    private fun applyAdaptiveStillFilterLocked(nowMs: Long, count: Int) {
        val floats = count * 2
        if (!hasFilter) {
            System.arraycopy(displayUv, 0, filterX, 0, floats)
            hasFilter = true
            return
        }
        // Motion energy from last visual step.
        val speed = hypot(lastVisTx, lastVisTy) / (lastVisDtMs / 1000f)
        val moving = speed > STILL_SPEED || lastVisConf >= 0.55f &&
            hypot(lastVisTx, lastVisTy) > 0.0025f
        if (moving) {
            // Near-identity: keep optical result; tiny blend kills single-pixel noise only.
            val a = 0.92f
            for (i in 0 until floats) {
                val x = displayUv[i]
                if (!x.isFinite()) continue
                val y = filterX[i]
                val hat = a * x + (1f - a) * y
                filterX[i] = hat
                displayUv[i] = hat
            }
        } else {
            // Stronger stabilize when parked.
            val a = 0.35f
            for (i in 0 until floats) {
                val x = displayUv[i]
                if (!x.isFinite()) continue
                val hat = a * x + (1f - a) * filterX[i]
                filterX[i] = hat
                displayUv[i] = hat
            }
        }
    }

    private val ageScratch = FloatArray(AGE_HIST)

    private fun noteAgeLocked(ageMs: Float) {
        ageHist[ageHistWrite] = ageMs
        ageHistWrite = (ageHistWrite + 1) % AGE_HIST
        if (ageHistN < AGE_HIST) ageHistN++
        if (ageHistN < 5) {
            lastMedianAge = ageMs
            lastP95Age = ageMs
            return
        }
        System.arraycopy(ageHist, 0, ageScratch, 0, ageHistN)
        ageScratch.sort(0, ageHistN)
        lastMedianAge = ageScratch[ageHistN / 2]
        lastP95Age = ageScratch[((ageHistN - 1) * 95) / 100]
    }

    private fun noteRenderLocked(displayTimeMs: Long) {
        if (renderWindowStartMs == 0L) renderWindowStartMs = displayTimeMs
        renderFramesInWindow++
        val elapsed = displayTimeMs - renderWindowStartMs
        if (elapsed >= 1_000L) {
            lastRenderFps = renderFramesInWindow * 1000f / elapsed.coerceAtLeast(1L)
            renderFramesInWindow = 0
            renderWindowStartMs = displayTimeMs
        }
    }

    private fun logDiagLocked(ageMs: Float) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastDiagMs < 1_000L) return
        lastDiagMs = now
        val analysisFps = V3FaceLandmarkState.snapshotMeta().analysisFps
        Log.i(
            TAG,
            "renderFps=${"%.1f".format(lastRenderFps)} " +
                "analysisFps=${"%.1f".format(analysisFps)} " +
                "visualFps=${"%.1f".format(V3SparseFaceTracker.trackerFps)} " +
                "visConf=${"%.2f".format(lastVisConf)} " +
                "geomAgeMs=${"%.1f".format(ageMs)} " +
                "medianAgeMs=${"%.1f".format(lastMedianAge)} " +
                "p95AgeMs=${"%.1f".format(lastP95Age)} " +
                "correctMag=${"%.4f".format(lastCorrectMag)}",
        )
    }

    private fun mark(mask: BooleanArray, indices: IntArray) {
        for (i in indices) if (i in mask.indices) mask[i] = true
    }

    private const val MAX_CENTER_JUMP_UV = 0.12f
    private const val CORRECT_ALPHA_SLOW = 0.28f
    private const val CORRECT_ALPHA_MED = 0.45f
    private const val CORRECT_ALPHA_FAST = 0.62f
    private const val MAX_BRIDGE_MS = 45f
    private const val MAX_BRIDGE_RATIO = 0.85f
    private const val MAX_BRIDGE_UV = 0.04f
    private const val STILL_SPEED = 0.15f // UV units / second
    private const val AGE_HIST = 64
    private const val TAG = "V3_TRACK"
}
