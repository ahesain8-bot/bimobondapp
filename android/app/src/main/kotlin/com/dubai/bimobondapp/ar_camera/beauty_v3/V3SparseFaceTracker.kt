package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.graphics.Bitmap
import android.util.Log
import com.dubai.bimobondapp.ar_camera.MediaPipeLandmarkIndices
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.MatOfByte
import org.opencv.core.MatOfFloat
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Size
import org.opencv.core.TermCriteria
import org.opencv.video.Video
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

private val V3_TRACK_INDICES = intArrayOf(
    // Global stable
    MediaPipeLandmarkIndices.NOSE_TIP,
    MediaPipeLandmarkIndices.NOSE_BRIDGE,
    33, 133,
    263, 362,
    MediaPipeLandmarkIndices.LEFT_CHEEK,
    MediaPipeLandmarkIndices.RIGHT_CHEEK,
    MediaPipeLandmarkIndices.FOREHEAD,
    MediaPipeLandmarkIndices.CHIN,
    // Mouth local
    MediaPipeLandmarkIndices.MOUTH_LEFT,
    MediaPipeLandmarkIndices.MOUTH_RIGHT,
    MediaPipeLandmarkIndices.MOUTH_TOP,
    MediaPipeLandmarkIndices.MOUTH_BOTTOM,
    MediaPipeLandmarkIndices.MOUTH_INNER_TOP,
    MediaPipeLandmarkIndices.MOUTH_INNER_BOTTOM,
    MediaPipeLandmarkIndices.MOUTH_INNER_LEFT,
    MediaPipeLandmarkIndices.MOUTH_INNER_RIGHT,
    37, 267,
    84, 314,
    // Eye lids
    159, 145, 386, 374,
    // Brows
    70, 105, 334, 300,
)

private val V3_GLOBAL_SET = setOf(
    MediaPipeLandmarkIndices.NOSE_TIP,
    MediaPipeLandmarkIndices.NOSE_BRIDGE,
    33, 133, 263, 362,
    MediaPipeLandmarkIndices.LEFT_CHEEK,
    MediaPipeLandmarkIndices.RIGHT_CHEEK,
    MediaPipeLandmarkIndices.FOREHEAD,
    MediaPipeLandmarkIndices.CHIN,
)
private val V3_MOUTH_SET = setOf(
    MediaPipeLandmarkIndices.MOUTH_LEFT,
    MediaPipeLandmarkIndices.MOUTH_RIGHT,
    MediaPipeLandmarkIndices.MOUTH_TOP,
    MediaPipeLandmarkIndices.MOUTH_BOTTOM,
    MediaPipeLandmarkIndices.MOUTH_INNER_TOP,
    MediaPipeLandmarkIndices.MOUTH_INNER_BOTTOM,
    MediaPipeLandmarkIndices.MOUTH_INNER_LEFT,
    MediaPipeLandmarkIndices.MOUTH_INNER_RIGHT,
    37, 267, 84, 314,
)
private val V3_EYE_SET = setOf(159, 145, 386, 374)
private val V3_BROW_SET = setOf(70, 105, 334, 300)

/**
 * Sparse pyramidal LK face tracker on the small oriented analysis ROI.
 *
 * Tracks a fixed set of MediaPipe landmark patches between ML results.
 * Produces global similarity + local mouth/eye/brow residuals in **canonical UV**.
 * No full-frame dense flow, no glReadPixels, no per-frame Bitmap alloc beyond the
 * shared analysis bitmap already produced by the camera path.
 *
 * OpenCV native objects are allocated only after [V3OpenCvRuntime.ensureLoaded]
 * succeeds — never during `<clinit>`.
 */
object V3SparseFaceTracker {
    private val lock = Any()

    private var nativesReady = false
    private var seeded = false
    private var prevGray: Mat? = null
    private var currGray: Mat? = null
    private var prevPts: MatOfPoint2f? = null
    private var nextPts: MatOfPoint2f? = null
    private var status: MatOfByte? = null
    private var err: MatOfFloat? = null
    private var pointScratch: Array<Point>? = null

    // Size / TermCriteria are pure-Java (no JNI in ctor).
    private val criteria = TermCriteria(
        TermCriteria.COUNT + TermCriteria.EPS,
        10,
        0.03,
    )
    private val winSize = Size(7.0, 7.0)

    /** Parallel to tracked points. */
    private val indices = V3_TRACK_INDICES
    private val nPoints = indices.size
    private val prevPx = FloatArray(nPoints * 2)
    private val currPx = FloatArray(nPoints * 2)
    private val alive = BooleanArray(nPoints)
    private val isGlobal = BooleanArray(nPoints)
    private val isMouth = BooleanArray(nPoints)
    private val isEye = BooleanArray(nPoints)
    private val isBrow = BooleanArray(nPoints)

    private val gpU0 = FloatArray(nPoints)
    private val gpV0 = FloatArray(nPoints)
    private val gpU1 = FloatArray(nPoints)
    private val gpV1 = FloatArray(nPoints)
    private val localIdxBuf = IntArray(nPoints)
    private val localDuBuf = FloatArray(nPoints)
    private val localDvBuf = FloatArray(nPoints)

    private val mapScratch = FloatArray(2)
    private var pixelBuf = IntArray(0)
    private var grayBuf = ByteArray(0)

    private var lastFrameTsMs = 0L
    private var lastW = 0
    private var lastH = 0

    private var framesInWindow = 0
    private var windowStartMs = 0L
    @Volatile var trackerFps: Float = 0f
        private set
    @Volatile var lastConfidence: Float = 0f
        private set
    @Volatile var lastTrackedCount: Int = 0
        private set

    private var lastDiagMs = 0L

    init {
        for (i in indices.indices) {
            val id = indices[i]
            when {
                id in V3_GLOBAL_SET -> isGlobal[i] = true
                id in V3_MOUTH_SET -> isMouth[i] = true
                id in V3_EYE_SET -> isEye[i] = true
                id in V3_BROW_SET -> isBrow[i] = true
            }
        }
    }

    fun reset(reason: String) {
        synchronized(lock) {
            seeded = false
            lastConfidence = 0f
            lastTrackedCount = 0
            alive.fill(false)
            Log.i(TAG, "reset reason=$reason available=${V3OpenCvRuntime.isAvailable()}")
        }
    }

    /**
     * Ensures OpenCV JNI is loaded and native Mat wrappers exist.
     * Soft-fails forever after first load failure (no per-frame retry spam).
     */
    private fun ensureNativesLocked(): Boolean {
        if (nativesReady) return true
        if (!V3OpenCvRuntime.ensureLoaded()) return false
        return try {
            if (prevPts == null) prevPts = MatOfPoint2f()
            if (nextPts == null) nextPts = MatOfPoint2f()
            if (status == null) status = MatOfByte()
            if (err == null) err = MatOfFloat()
            if (pointScratch == null) {
                pointScratch = Array(nPoints) { Point() }
            }
            nativesReady = true
            true
        } catch (t: Throwable) {
            Log.e(TAG, "native Mat alloc failed after OpenCV load", t)
            nativesReady = false
            false
        }
    }

    /** Public entry used by analysis path — never throws. */
    fun ensureOpenCv(): Boolean {
        if (nativesReady && V3OpenCvRuntime.isAvailable()) return true
        synchronized(lock) {
            return ensureNativesLocked()
        }
    }

    /**
     * Reseed sparse points from MediaPipe landmarks in oriented analysis space.
     * [landmarks] MediaPipe normalized x/y in oriented bitmap (NOT mirrored).
     */
    fun seedFromMediaPipe(
        landmarks: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>,
        bitmapW: Int,
        bitmapH: Int,
        frameTsMs: Long,
        graySource: Bitmap,
    ) {
        if (landmarks.size < 300 || bitmapW < 8 || bitmapH < 8) return
        synchronized(lock) {
            if (!ensureNativesLocked()) return
            val pts = pointScratch ?: return
            val prev = prevPts ?: return
            ensureGrayLocked(graySource)
            currGray ?: return
            // Seed points in pixel coords of oriented analysis image.
            for (i in indices.indices) {
                val id = indices[i]
                alive[i] = false
                if (id < 0 || id >= landmarks.size) {
                    pts[i].x = 0.0
                    pts[i].y = 0.0
                    continue
                }
                val lm = landmarks[id]
                val x = (lm.x() * bitmapW).toDouble().coerceIn(1.0, (bitmapW - 2).toDouble())
                val y = (lm.y() * bitmapH).toDouble().coerceIn(1.0, (bitmapH - 2).toDouble())
                pts[i].x = x
                pts[i].y = y
                prevPx[i * 2] = x.toFloat()
                prevPx[i * 2 + 1] = y.toFloat()
                currPx[i * 2] = prevPx[i * 2]
                currPx[i * 2 + 1] = prevPx[i * 2 + 1]
                alive[i] = true
            }
            prev.fromArray(*pts)
            // Swap: current gray becomes previous for next track.
            val tmp = prevGray
            prevGray = currGray
            currGray = tmp
            if (currGray == null) {
                currGray = Mat(bitmapH, bitmapW, CvType.CV_8UC1)
            }
            lastW = bitmapW
            lastH = bitmapH
            lastFrameTsMs = frameTsMs
            seeded = alive.count { it } >= MIN_SEED_ALIVE
            lastConfidence = if (seeded) 1f else 0f
            lastTrackedCount = alive.count { it }
        }
    }

    /**
     * Track from previous analysis gray → [oriented] frame.
     * Applies observed motion into [V3TrackedFaceState].
     * @return true if a usable visual update was applied
     */
    fun trackFrame(oriented: Bitmap, frameTsMs: Long): Boolean {
        synchronized(lock) {
            if (!ensureNativesLocked()) return false
            val prevP = prevPts ?: return false
            val nextP = nextPts ?: return false
            val stMat = status ?: return false
            val errMat = err ?: return false
            if (!seeded || prevGray == null || prevGray!!.empty()) return false
            if (oriented.width != lastW || oriented.height != lastH) {
                seeded = false
                return false
            }
            val dt = (frameTsMs - lastFrameTsMs).toFloat()
            if (dt < 1f) return false
            if (dt > MAX_TRACK_DT_MS) {
                seeded = false
                lastConfidence = 0f
                return false
            }

            ensureGrayLocked(oriented)
            val prev = prevGray ?: return false
            val curr = currGray ?: return false

            Video.calcOpticalFlowPyrLK(
                prev,
                curr,
                prevP,
                nextP,
                stMat,
                errMat,
                winSize,
                2,
                criteria,
                0,
                0.001,
            )

            val st = stMat.toArray()
            val nxt = nextP.toArray()
            val prv = prevP.toArray()
            val errs = errMat.toArray()
            if (st == null || nxt == null || prv == null || st.size < nPoints) {
                seeded = false
                return false
            }

            var okGlobal = 0
            var okMouth = 0
            var okTotal = 0
            for (i in 0 until nPoints) {
                val e = errs?.getOrNull(i) ?: 0f
                val good = st[i].toInt() != 0 &&
                    nxt[i].x in 1.0..(lastW - 2.0) &&
                    nxt[i].y in 1.0..(lastH - 2.0) &&
                    e < MAX_LK_ERR
                alive[i] = good
                if (!good) continue
                okTotal++
                prevPx[i * 2] = prv[i].x.toFloat()
                prevPx[i * 2 + 1] = prv[i].y.toFloat()
                currPx[i * 2] = nxt[i].x.toFloat()
                currPx[i * 2 + 1] = nxt[i].y.toFloat()
                if (isGlobal[i]) okGlobal++
                if (isMouth[i]) okMouth++
            }

            val conf = when {
                okGlobal >= MIN_GLOBAL_OK && okTotal >= MIN_TOTAL_OK ->
                    (okTotal.toFloat() / nPoints).coerceIn(0.35f, 1f)
                okGlobal >= 3 -> 0.25f
                else -> 0f
            }
            lastConfidence = conf
            lastTrackedCount = okTotal
            noteFpsLocked(frameTsMs)

            if (conf < MIN_CONFIDENCE) {
                // Keep seed but do not apply explosive motion.
                promoteGrayLocked()
                updatePrevPtsFromCurrLocked()
                lastFrameTsMs = frameTsMs
                logDiagLocked(applied = false)
                return false
            }

            val applied = applyMotionToTrackedStateLocked(frameTsMs, dt)
            promoteGrayLocked()
            updatePrevPtsFromCurrLocked()
            lastFrameTsMs = frameTsMs
            logDiagLocked(applied = applied)
            return applied
        }
    }

    private fun applyMotionToTrackedStateLocked(frameTsMs: Long, dtMs: Float): Boolean {
        // Map tracked points prev/curr → canonical UV, estimate global similarity
        // from stable features, then local residuals for mouth/eyes/brows.
        var gPrevCx = 0f
        var gPrevCy = 0f
        var gCurrCx = 0f
        var gCurrCy = 0f
        var gN = 0

        for (i in 0 until nPoints) {
            if (!alive[i] || !isGlobal[i]) continue
            if (!toCanonical(prevPx[i * 2], prevPx[i * 2 + 1], lastW, lastH, mapScratch)) continue
            val u0 = mapScratch[0]
            val v0 = mapScratch[1]
            if (!toCanonical(currPx[i * 2], currPx[i * 2 + 1], lastW, lastH, mapScratch)) continue
            val u1 = mapScratch[0]
            val v1 = mapScratch[1]
            gpU0[gN] = u0
            gpV0[gN] = v0
            gpU1[gN] = u1
            gpV1[gN] = v1
            gPrevCx += u0
            gPrevCy += v0
            gCurrCx += u1
            gCurrCy += v1
            gN++
        }
        if (gN < MIN_GLOBAL_OK) return false
        gPrevCx /= gN
        gPrevCy /= gN
        gCurrCx /= gN
        gCurrCy /= gN

        // Rotation + scale from covariance of centered point sets (Umeyama 2D).
        var sxx = 0f
        var sxy = 0f
        var syx = 0f
        var syy = 0f
        var varPrev = 0f
        for (i in 0 until gN) {
            val x0 = gpU0[i] - gPrevCx
            val y0 = gpV0[i] - gPrevCy
            val x1 = gpU1[i] - gCurrCx
            val y1 = gpV1[i] - gCurrCy
            sxx += x0 * x1
            sxy += x0 * y1
            syx += y0 * x1
            syy += y0 * y1
            varPrev += x0 * x0 + y0 * y0
        }
        if (varPrev < 1e-8f) return false
        val ang = atan2(sxy - syx, sxx + syy)
        val cosA = cos(ang)
        val sinA = sin(ang)
        var num = 0f
        for (i in 0 until gN) {
            val x0 = gpU0[i] - gPrevCx
            val y0 = gpV0[i] - gPrevCy
            val rx = cosA * x0 - sinA * y0
            val ry = sinA * x0 + cosA * y0
            val x1 = gpU1[i] - gCurrCx
            val y1 = gpV1[i] - gCurrCy
            num += rx * x1 + ry * y1
        }
        val scale = (num / varPrev).coerceIn(0.92f, 1.08f)
        val tx = (gCurrCx - gPrevCx).coerceIn(-MAX_STEP_UV, MAX_STEP_UV)
        val ty = (gCurrCy - gPrevCy).coerceIn(-MAX_STEP_UV, MAX_STEP_UV)
        val rot = ang.coerceIn(-MAX_STEP_ROT, MAX_STEP_ROT)
        val cosR = cos(rot)
        val sinR = sin(rot)

        var localN = 0
        fun addLocal(i: Int) {
            if (!alive[i]) return
            if (!toCanonical(prevPx[i * 2], prevPx[i * 2 + 1], lastW, lastH, mapScratch)) return
            val u0 = mapScratch[0]
            val v0 = mapScratch[1]
            if (!toCanonical(currPx[i * 2], currPx[i * 2 + 1], lastW, lastH, mapScratch)) return
            val u1 = mapScratch[0]
            val v1 = mapScratch[1]
            val dx = u0 - gPrevCx
            val dy = v0 - gPrevCy
            val predU = gPrevCx + (cosR * dx - sinR * dy) * scale + tx
            val predV = gPrevCy + (sinR * dx + cosR * dy) * scale + ty
            localIdxBuf[localN] = indices[i]
            localDuBuf[localN] = (u1 - predU).coerceIn(-MAX_LOCAL_STEP_UV, MAX_LOCAL_STEP_UV)
            localDvBuf[localN] = (v1 - predV).coerceIn(-MAX_LOCAL_STEP_UV, MAX_LOCAL_STEP_UV)
            localN++
        }
        for (i in 0 until nPoints) {
            if (isMouth[i] || isEye[i] || isBrow[i]) addLocal(i)
        }

        return V3TrackedFaceState.applyVisualMotion(
            frameTsMs = frameTsMs,
            sampleDtMs = dtMs,
            cx = gPrevCx,
            cy = gPrevCy,
            cosR = cosR,
            sinR = sinR,
            scale = scale,
            tx = tx,
            ty = ty,
            localIdx = localIdxBuf,
            localDu = localDuBuf,
            localDv = localDvBuf,
            localN = localN,
            confidence = lastConfidence,
        )
    }

    private fun toCanonical(px: Float, py: Float, w: Int, h: Int, out: FloatArray): Boolean {
        val nx = (px / w.toFloat()).coerceIn(0f, 1f)
        val ny = (py / h.toFloat()).coerceIn(0f, 1f)
        return V3AnalysisToCanonicalTransform.mapNormToCanonical(nx, ny, out, 0)
    }

    private fun ensureGrayLocked(bmp: Bitmap) {
        val w = bmp.width
        val h = bmp.height
        if (currGray == null || currGray!!.cols() != w || currGray!!.rows() != h) {
            currGray?.release()
            currGray = Mat(h, w, CvType.CV_8UC1)
        }
        if (prevGray == null || prevGray!!.cols() != w || prevGray!!.rows() != h) {
            prevGray?.release()
            prevGray = Mat(h, w, CvType.CV_8UC1)
        }
        val n = w * h
        if (pixelBuf.size < n) pixelBuf = IntArray(n)
        if (grayBuf.size < n) grayBuf = ByteArray(n)
        bmp.getPixels(pixelBuf, 0, w, 0, 0, w, h)
        var i = 0
        while (i < n) {
            val c = pixelBuf[i]
            val r = (c shr 16) and 0xff
            val g = (c shr 8) and 0xff
            val b = c and 0xff
            grayBuf[i] = ((r * 77 + g * 150 + b * 29) shr 8).toByte()
            i++
        }
        currGray!!.put(0, 0, grayBuf)
        lastW = w
        lastH = h
    }

    private fun promoteGrayLocked() {
        val tmp = prevGray
        prevGray = currGray
        currGray = tmp
    }

    private fun updatePrevPtsFromCurrLocked() {
        val pts = pointScratch ?: return
        val prev = prevPts ?: return
        for (i in 0 until nPoints) {
            if (alive[i]) {
                pts[i].x = currPx[i * 2].toDouble()
                pts[i].y = currPx[i * 2 + 1].toDouble()
            } else {
                pts[i].x = prevPx[i * 2].toDouble()
                pts[i].y = prevPx[i * 2 + 1].toDouble()
            }
        }
        prev.fromArray(*pts)
    }

    private fun noteFpsLocked(frameTsMs: Long) {
        if (windowStartMs == 0L) windowStartMs = frameTsMs
        framesInWindow++
        val elapsed = frameTsMs - windowStartMs
        if (elapsed >= 1_000L) {
            trackerFps = framesInWindow * 1000f / elapsed.coerceAtLeast(1L)
            framesInWindow = 0
            windowStartMs = frameTsMs
        }
    }

    private fun logDiagLocked(applied: Boolean) {
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastDiagMs < 1_000L) return
        lastDiagMs = now
        Log.i(
            TAG,
            "fps=${"%.1f".format(trackerFps)} " +
                "tracked=$lastTrackedCount/$nPoints " +
                "conf=${"%.2f".format(lastConfidence)} " +
                "applied=$applied seeded=$seeded",
        )
    }

    private const val MIN_SEED_ALIVE = 8
    private const val MIN_GLOBAL_OK = 4
    private const val MIN_TOTAL_OK = 8
    private const val MIN_CONFIDENCE = 0.30f
    private const val MAX_TRACK_DT_MS = 120f
    private const val MAX_LK_ERR = 12f
    private const val MAX_STEP_UV = 0.085f
    private const val MAX_STEP_ROT = 0.18f
    private const val MAX_LOCAL_STEP_UV = 0.055f
    private const val TAG = "V3_VISUAL"
}
