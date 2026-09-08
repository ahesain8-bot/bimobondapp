package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.os.SystemClock
import android.util.Log
import com.dubai.bimobondapp.ar_camera.MediaPipeLandmarkIndices
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/**
 * Lightweight render-time **global** head-motion compensation.
 *
 * Keeps local expression from the latest MediaPipe landmark set; predicts only a
 * 2D similarity (tx, ty, small rotation, uniform scale) between analysis updates.
 *
 * Separate extrapolation caps: translation 75 ms, rotation 55 ms, scale 50 ms.
 * Stop-damping cuts extrapolation on sharp velocity drop / reverse (no laggy smoother).
 */
object V3HeadMotionPredictor {
    private val lock = Any()

    @Volatile
    var enabled: Boolean = true

    private var hasPrev = false
    private var hasCurr = false

    private var prevTsMs = 0L
    private var currTsMs = 0L
    private var prevCameraGen = -1L
    private var currCameraGen = -1L
    private var prevLensFront = true
    private var currLensFront = true
    private var prevRotation = 0
    private var currRotation = 0

    // [lx,ly, rx,ry, noseTipX,Y, noseBridgeX,Y, mouthX,Y]
    private val prevAnchors = FloatArray(ANCHOR_FLOATS)
    private val currAnchors = FloatArray(ANCHOR_FLOATS)
    private val anchorScratch = FloatArray(ANCHOR_FLOATS)
    private val mapScratch = FloatArray(2)

    /** Last interval translation velocity (UV / ms) for stop-damping. */
    private var hasVel = false
    private var velX = 0f
    private var velY = 0f
    /** 0..1 — applied to extrapolation horizon (1 = full predict). */
    private var stopDamp = 1f

    private var lastEnabled = false
    private var lastResultAgeMs = 0f
    private var lastPredictMs = 0f
    private var lastTx = 0f
    private var lastTy = 0f
    private var lastRotDeg = 0f
    private var lastScale = 1f
    private var lastClamped = false
    private var lastDiagMs = 0L

    fun reset(reason: String) {
        synchronized(lock) {
            hasPrev = false
            hasCurr = false
            hasVel = false
            velX = 0f
            velY = 0f
            stopDamp = 1f
            lastEnabled = false
            lastPredictMs = 0f
            lastTx = 0f
            lastTy = 0f
            lastRotDeg = 0f
            lastScale = 1f
            lastClamped = false
            Log.i(TAG, "reset reason=$reason")
        }
    }

    /**
     * Pushes a new valid sensor-mapped sample. Call only after a successful publish.
     */
    fun pushFromMediaPipe(
        landmarks: List<NormalizedLandmark>,
        timestampMs: Long,
        cameraGen: Long,
        lensFront: Boolean,
        rotationDegrees: Int,
    ) {
        if (!enabled) return
        synchronized(lock) {
            if (hasCurr &&
                (cameraGen != currCameraGen ||
                    lensFront != currLensFront ||
                    rotationDegrees != currRotation)
            ) {
                hasPrev = false
                hasCurr = false
                hasVel = false
                stopDamp = 1f
            }

            if (!extractAnchors(landmarks, anchorScratch)) {
                hasPrev = false
                hasCurr = false
                hasVel = false
                stopDamp = 1f
                return
            }

            if (hasCurr) {
                val oldCx = (currAnchors[0] + currAnchors[2]) * 0.5f
                val oldCy = (currAnchors[1] + currAnchors[3]) * 0.5f
                val newCx = (anchorScratch[0] + anchorScratch[2]) * 0.5f
                val newCy = (anchorScratch[1] + anchorScratch[3]) * 0.5f
                val sampleDt = (timestampMs - currTsMs).toFloat()
                if (hypot(newCx - oldCx, newCy - oldCy) > MAX_CENTER_JUMP_UV) {
                    hasPrev = false
                    hasVel = false
                    stopDamp = 1f
                } else {
                    if (sampleDt >= MIN_SAMPLE_DT_MS && sampleDt <= MAX_SAMPLE_DT_MS) {
                        val nVx = (newCx - oldCx) / sampleDt
                        val nVy = (newCy - oldCy) / sampleDt
                        if (hasVel) {
                            val oldSp = hypot(velX, velY)
                            val newSp = hypot(nVx, nVy)
                            val dot = velX * nVx + velY * nVy
                            stopDamp = when {
                                // Direction reverse → cut extrapolation hard.
                                oldSp > MIN_VEL_FOR_DAMP && dot < 0f -> 0.12f
                                // Sharp slowdown → reduce immediately (no laggy filter).
                                oldSp > MIN_VEL_FOR_DAMP && newSp < oldSp * SPEED_DROP_RATIO -> 0.22f
                                else -> 1f
                            }
                        } else {
                            stopDamp = 1f
                        }
                        velX = nVx
                        velY = nVy
                        hasVel = true
                    }
                    System.arraycopy(currAnchors, 0, prevAnchors, 0, ANCHOR_FLOATS)
                    prevTsMs = currTsMs
                    prevCameraGen = currCameraGen
                    prevLensFront = currLensFront
                    prevRotation = currRotation
                    hasPrev = true
                }
            }

            System.arraycopy(anchorScratch, 0, currAnchors, 0, ANCHOR_FLOATS)
            currTsMs = timestampMs
            currCameraGen = cameraGen
            currLensFront = lensFront
            currRotation = rotationDegrees
            hasCurr = true
        }
    }

    /**
     * Applies predicted global similarity in-place to packed `u,v,r,g,b`.
     * Unstable / unavailable → leaves [packed] unchanged (latest raw landmarks).
     */
    fun applyInPlace(
        packed: FloatArray,
        floatCount: Int,
        nowMs: Long,
        cameraGen: Long,
        lensFront: Boolean,
        rotationDegrees: Int,
    ) {
        synchronized(lock) {
            if (!resolveTransformLocked(nowMs, cameraGen, lensFront, rotationDegrees)) return
            val stride = V3FaceLandmarkState.STRIDE
            var i = 0
            while (i + 1 < floatCount) {
                applyPointLocked(packed, i)
                i += stride
            }
            logDiagLocked()
        }
    }

    /**
     * Same global prediction for interleaved canonical UV pairs `u,v` (stride 2).
     * Used by V3-1.5 region builder. Skips non-finite points.
     */
    fun applyToUvPairs(
        uv: FloatArray,
        pointCount: Int,
        nowMs: Long,
        cameraGen: Long,
        lensFront: Boolean,
        rotationDegrees: Int,
    ) {
        synchronized(lock) {
            if (!resolveTransformLocked(nowMs, cameraGen, lensFront, rotationDegrees)) return
            for (i in 0 until pointCount) {
                val o = i * 2
                if (o + 1 >= uv.size) break
                if (!uv[o].isFinite() || !uv[o + 1].isFinite()) continue
                applyPointLocked(uv, o)
            }
            logDiagLocked()
        }
    }

    private var xformCx = 0f
    private var xformCy = 0f
    private var xformCos = 1f
    private var xformSin = 0f
    private var xformScale = 1f
    private var xformTx = 0f
    private var xformTy = 0f

    private fun applyPointLocked(buf: FloatArray, offset: Int) {
        val u = buf[offset]
        val v = buf[offset + 1]
        val dx = u - xformCx
        val dy = v - xformCy
        buf[offset] = xformCx + (xformCos * dx - xformSin * dy) * xformScale + xformTx
        buf[offset + 1] = xformCy + (xformSin * dx + xformCos * dy) * xformScale + xformTy
    }

    /** Computes transform into xform*; updates diag fields. */
    private fun resolveTransformLocked(
        nowMs: Long,
        cameraGen: Long,
        lensFront: Boolean,
        rotationDegrees: Int,
    ): Boolean {
        if (!enabled || !hasCurr) {
            lastEnabled = false
            return false
        }
        if (cameraGen != currCameraGen ||
            lensFront != currLensFront ||
            rotationDegrees != currRotation
        ) {
            lastEnabled = false
            return false
        }

        val resultAge = (nowMs - currTsMs).toFloat().coerceAtLeast(0f)
        lastResultAgeMs = resultAge

        if (!hasPrev) {
            lastEnabled = false
            lastPredictMs = 0f
            lastTx = 0f
            lastTy = 0f
            lastRotDeg = 0f
            lastScale = 1f
            lastClamped = false
            return false
        }

        val dt = (currTsMs - prevTsMs).toFloat()
        if (dt < MIN_SAMPLE_DT_MS || dt > MAX_SAMPLE_DT_MS) {
            lastEnabled = false
            lastPredictMs = 0f
            return false
        }

        val prevCx = (prevAnchors[0] + prevAnchors[2]) * 0.5f
        val prevCy = (prevAnchors[1] + prevAnchors[3]) * 0.5f
        val currCx = (currAnchors[0] + currAnchors[2]) * 0.5f
        val currCy = (currAnchors[1] + currAnchors[3]) * 0.5f

        val prevAngle = atan2(prevAnchors[3] - prevAnchors[1], prevAnchors[2] - prevAnchors[0])
        val currAngle = atan2(currAnchors[3] - currAnchors[1], currAnchors[2] - currAnchors[0])
        var dAngle = currAngle - prevAngle
        while (dAngle > Math.PI) dAngle -= (2.0 * Math.PI).toFloat()
        while (dAngle < -Math.PI) dAngle += (2.0 * Math.PI).toFloat()

        val prevSpan = hypot(prevAnchors[2] - prevAnchors[0], prevAnchors[3] - prevAnchors[1])
            .coerceAtLeast(1e-4f)
        val currSpan = hypot(currAnchors[2] - currAnchors[0], currAnchors[3] - currAnchors[1])
            .coerceAtLeast(1e-4f)
        val scaleRatio = currSpan / prevSpan

        val speed = hypot(currCx - prevCx, currCy - prevCy) / dt
        if (speed > MAX_SPEED_UV_PER_MS ||
            kotlin.math.abs(dAngle) / dt > MAX_ANG_SPEED_RAD_PER_MS ||
            scaleRatio !in MIN_SCALE_RATIO..MAX_SCALE_RATIO
        ) {
            lastEnabled = false
            lastPredictMs = 0f
            lastClamped = true
            return false
        }

        val damp = stopDamp.coerceIn(0f, 1f)
        val predTrans = resultAge.coerceAtMost(MAX_EXTRAPOLATE_TRANS_MS) * damp
        val predRot = resultAge.coerceAtMost(MAX_EXTRAPOLATE_ROT_MS) * damp
        val predScale = resultAge.coerceAtMost(MAX_EXTRAPOLATE_SCALE_MS) * damp

        if (predTrans < 1f && predRot < 1f && predScale < 1f) {
            lastEnabled = false
            lastPredictMs = 0f
            lastTx = 0f
            lastTy = 0f
            lastRotDeg = 0f
            lastScale = 1f
            lastClamped = damp < 0.99f
            return false
        }

        var tx = (currCx - prevCx) * (predTrans / dt)
        var ty = (currCy - prevCy) * (predTrans / dt)
        var dRot = dAngle * (predRot / dt)
        var dScale = 1f + (scaleRatio - 1f) * (predScale / dt)

        var clamped = resultAge > MAX_EXTRAPOLATE_TRANS_MS - 0.5f || damp < 0.99f
        if (kotlin.math.abs(tx) > MAX_TX_UV) {
            tx = tx.coerceIn(-MAX_TX_UV, MAX_TX_UV)
            clamped = true
        }
        if (kotlin.math.abs(ty) > MAX_TY_UV) {
            ty = ty.coerceIn(-MAX_TY_UV, MAX_TY_UV)
            clamped = true
        }
        if (kotlin.math.abs(dRot) > MAX_ROT_RAD) {
            dRot = dRot.coerceIn(-MAX_ROT_RAD, MAX_ROT_RAD)
            clamped = true
        }
        if (dScale !in (1f - MAX_SCALE_DELTA)..(1f + MAX_SCALE_DELTA)) {
            dScale = dScale.coerceIn(1f - MAX_SCALE_DELTA, 1f + MAX_SCALE_DELTA)
            clamped = true
        }

        xformCx = currCx
        xformCy = currCy
        xformCos = cos(dRot)
        xformSin = sin(dRot)
        xformScale = dScale
        xformTx = tx
        xformTy = ty

        lastEnabled = true
        lastPredictMs = predTrans
        lastTx = tx
        lastTy = ty
        lastRotDeg = Math.toDegrees(dRot.toDouble()).toFloat()
        lastScale = dScale
        lastClamped = clamped
        return true
    }

    private fun extractAnchors(
        landmarks: List<NormalizedLandmark>,
        dest: FloatArray,
    ): Boolean {
        if (!avgMapped(landmarks, MediaPipeLandmarkIndices.LEFT_EYE, dest, 0)) return false
        if (!avgMapped(landmarks, MediaPipeLandmarkIndices.RIGHT_EYE, dest, 2)) return false
        if (!mapOne(landmarks, MediaPipeLandmarkIndices.NOSE_TIP, dest, 4)) return false
        if (!mapOne(landmarks, MediaPipeLandmarkIndices.NOSE_BRIDGE, dest, 6)) return false

        var sx = 0f
        var sy = 0f
        var n = 0
        fun addMouth(idx: Int) {
            if (idx < 0 || idx >= landmarks.size) return
            if (!V3AnalysisToCanonicalTransform.mapNormToCanonical(
                    landmarks[idx].x(),
                    landmarks[idx].y(),
                    mapScratch,
                    0,
                )
            ) {
                return
            }
            sx += mapScratch[0]
            sy += mapScratch[1]
            n++
        }
        addMouth(MediaPipeLandmarkIndices.MOUTH_LEFT)
        addMouth(MediaPipeLandmarkIndices.MOUTH_RIGHT)
        addMouth(MediaPipeLandmarkIndices.MOUTH_TOP)
        addMouth(MediaPipeLandmarkIndices.MOUTH_BOTTOM)
        if (n < 2) return false
        dest[8] = sx / n
        dest[9] = sy / n
        return true
    }

    private fun avgMapped(
        landmarks: List<NormalizedLandmark>,
        indices: IntArray,
        dest: FloatArray,
        destOffset: Int,
    ): Boolean {
        var sx = 0f
        var sy = 0f
        var n = 0
        for (idx in indices) {
            if (idx < 0 || idx >= landmarks.size) continue
            if (!V3AnalysisToCanonicalTransform.mapNormToCanonical(
                    landmarks[idx].x(),
                    landmarks[idx].y(),
                    mapScratch,
                    0,
                )
            ) {
                continue
            }
            sx += mapScratch[0]
            sy += mapScratch[1]
            n++
        }
        if (n < 3) return false
        dest[destOffset] = sx / n
        dest[destOffset + 1] = sy / n
        return true
    }

    private fun mapOne(
        landmarks: List<NormalizedLandmark>,
        index: Int,
        dest: FloatArray,
        destOffset: Int,
    ): Boolean {
        if (index < 0 || index >= landmarks.size) return false
        if (!V3AnalysisToCanonicalTransform.mapNormToCanonical(
                landmarks[index].x(),
                landmarks[index].y(),
                mapScratch,
                0,
            )
        ) {
            return false
        }
        dest[destOffset] = mapScratch[0]
        dest[destOffset + 1] = mapScratch[1]
        return true
    }

    private fun logDiagLocked() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastDiagMs < 1_000L) return
        lastDiagMs = now
        Log.i(
            TAG,
            "enabled=$lastEnabled " +
                "resultAgeMs=${"%.1f".format(lastResultAgeMs)} " +
                "predictMs=${"%.1f".format(lastPredictMs)} " +
                "translationPx=${"%.4f,%.4f".format(lastTx, lastTy)} " +
                "rotationDeg=${"%.2f".format(lastRotDeg)} " +
                "scale=${"%.4f".format(lastScale)} " +
                "clamped=$lastClamped",
        )
    }

    private const val ANCHOR_FLOATS = 10
    /** Translation may cover more of resultAge (fast pan lag). */
    private const val MAX_EXTRAPOLATE_TRANS_MS = 75f
    private const val MAX_EXTRAPOLATE_ROT_MS = 55f
    private const val MAX_EXTRAPOLATE_SCALE_MS = 50f
    private const val MIN_SAMPLE_DT_MS = 12f
    private const val MAX_SAMPLE_DT_MS = 180f
    private const val MAX_CENTER_JUMP_UV = 0.12f
    private const val MAX_SPEED_UV_PER_MS = 0.0045f
    private const val MAX_ANG_SPEED_RAD_PER_MS = 0.003f
    private const val MIN_SCALE_RATIO = 0.85f
    private const val MAX_SCALE_RATIO = 1.18f
    private const val MAX_TX_UV = 0.07f
    private const val MAX_TY_UV = 0.07f
    private const val MAX_ROT_RAD = 0.12f
    private const val MAX_SCALE_DELTA = 0.06f
    private const val MIN_VEL_FOR_DAMP = 0.00015f
    private const val SPEED_DROP_RATIO = 0.35f
    private const val TAG = "V3_FACE_PREDICT"
}
