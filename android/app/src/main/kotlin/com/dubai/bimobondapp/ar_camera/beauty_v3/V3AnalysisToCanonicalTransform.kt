package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.RectF
import android.os.SystemClock
import android.util.Log
import androidx.camera.core.impl.utils.TransformUtils
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.max

/**
 * Explicit analysis → V3 canonical UV transform with generation ownership.
 *
 * **Never** maps with identity when analysis FOV ≠ preview FOV.
 * Mapped landmarks may publish only when [sensorMappingReady] is true for the
 * **same** [cameraGeneration] on both preview and analysis sides.
 */
object V3AnalysisToCanonicalTransform {
    private val lock = Any()

    private val cameraGeneration = AtomicLong(0L)
    private var previewTransformGeneration = 0L
    private var analysisGeneration = 0L

    private var previewTransformReady = false
    private var analysisTransformReady = false
    private var sensorMappingReady = false

    private var lensFront = true
    private var previewBufW = 0
    private var previewBufH = 0
    private val previewCrop = Rect()
    private var previewRotation = 0
    private val previewSensorToBuffer = Matrix()
    private var previewIsMirroring = false
    private var previewCameraGen = -1L

    private var analysisProxyW = 0
    private var analysisProxyH = 0
    private val analysisCrop = Rect()
    private var analysisRotation = 0
    private var mediaPipeW = 0
    private var mediaPipeH = 0
    private var analysisMaxEdge = 0
    private var mirrorX = false
    private var analysisLensFront = true
    private var analysisCameraGen = -1L
    private val analysisSensorToBuffer = Matrix()
    private val mediaPipeToAnalysisBuffer = Matrix()
    private val analysisBufferToSensor = Matrix()
    private val previewCropToCanonical = Matrix()

    private var mapReason = Reason.WAITING_PREVIEW_TRANSFORM
    private var lastLoggedReason: Reason? = null
    private var lastGeomDiagMs = 0L
    private var droppedMapCount = 0

    private val scratch = FloatArray(2)

    enum class Reason {
        WAITING_PREVIEW_TRANSFORM,
        WAITING_ANALYSIS_TRANSFORM,
        GENERATION_MISMATCH,
        LENS_MISMATCH,
        ROTATION_MISMATCH,
        SENSOR_MATRIX_INVALID,
        SENSOR_PROBE_FAILED,
        ORIENT_INVERT_FAIL,
        SENSOR_READY,
        INVALIDATED_ON_FLIP,
        INVALIDATED_ON_REBIND,
        INVALIDATED_ON_RESUME,
        INVALIDATED_ON_DETECTION_ENABLE,
        INVALIDATED_ON_DETECTION_DISABLE,
        INVALIDATED_ON_PATH_CHANGE,
        INVALIDATED_ON_EGL,
    }

    /** Bumps camera generation and clears transform readiness (flip / rebind / resume). */
    fun invalidateCamera(reason: Reason, lensFront: Boolean? = null) {
        synchronized(lock) {
            cameraGeneration.incrementAndGet()
            previewTransformReady = false
            analysisTransformReady = false
            sensorMappingReady = false
            previewCameraGen = -1L
            analysisCameraGen = -1L
            if (lensFront != null) this.lensFront = lensFront
            mapReason = reason
            logStateLocked(force = true)
        }
        V3FaceLandmarkState.invalidateMapped(
            reason = reason.name,
            cameraGen = cameraGeneration.get(),
            holdLastValid = false,
        )
    }

    /** Soft invalidate: drop drawable landmarks; keep last preview if still same gen. */
    fun invalidateLandmarksOnly(reason: Reason) {
        synchronized(lock) {
            analysisTransformReady = false
            sensorMappingReady = false
            analysisCameraGen = -1L
            mapReason = reason
            logStateLocked(force = true)
        }
        V3FaceLandmarkState.invalidateMapped(
            reason = reason.name,
            cameraGen = cameraGeneration.get(),
            holdLastValid = false,
        )
    }

    fun currentCameraGeneration(): Long = cameraGeneration.get()

    fun isSensorMappingReady(): Boolean = synchronized(lock) { sensorMappingReady }

    fun updatePreview(
        bufferWidth: Int,
        bufferHeight: Int,
        cropRect: Rect,
        rotationDegrees: Int,
        sensorToBuffer: Matrix,
        isMirroring: Boolean,
        lensFront: Boolean,
    ) {
        synchronized(lock) {
            val gen = cameraGeneration.get()
            previewBufW = bufferWidth.coerceAtLeast(1)
            previewBufH = bufferHeight.coerceAtLeast(1)
            previewCrop.set(cropRect)
            if (previewCrop.isEmpty) {
                previewCrop.set(0, 0, previewBufW, previewBufH)
            }
            previewRotation = ((rotationDegrees % 360) + 360) % 360
            previewSensorToBuffer.set(sensorToBuffer)
            previewIsMirroring = isMirroring
            this.lensFront = lensFront
            previewCameraGen = gen
            previewTransformGeneration = gen
            previewTransformReady = previewBufW >= 2 && previewBufH >= 2 &&
                !isEffectivelyIdentity(previewSensorToBuffer)
            rebuildLocked()
            logStateLocked(force = true)
            logGeomLocked()
        }
    }

    fun updateAnalysis(
        proxyWidth: Int,
        proxyHeight: Int,
        cropRect: Rect,
        rotationDegrees: Int,
        sensorToBuffer: Matrix,
        mediaPipeWidth: Int,
        mediaPipeHeight: Int,
        maxEdge: Int,
        mirrorX: Boolean,
        lensFront: Boolean,
    ): Boolean {
        synchronized(lock) {
            val gen = cameraGeneration.get()
            analysisProxyW = proxyWidth.coerceAtLeast(1)
            analysisProxyH = proxyHeight.coerceAtLeast(1)
            analysisCrop.set(cropRect)
            if (analysisCrop.isEmpty) {
                analysisCrop.set(0, 0, analysisProxyW, analysisProxyH)
            }
            analysisRotation = ((rotationDegrees % 360) + 360) % 360
            analysisSensorToBuffer.set(sensorToBuffer)
            mediaPipeW = mediaPipeWidth.coerceAtLeast(1)
            mediaPipeH = mediaPipeHeight.coerceAtLeast(1)
            analysisMaxEdge = maxEdge
            this.mirrorX = mirrorX
            analysisLensFront = lensFront
            analysisCameraGen = gen
            analysisGeneration = gen
            analysisTransformReady = true
            rebuildLocked()
            logGeomLocked()
            return sensorMappingReady
        }
    }

    /**
     * MediaPipe / analysis-normalized UV → canonical UV.
     * Returns false unless [sensorMappingReady] (never identity / aspect fabricate).
     */
    fun mapNormToCanonical(u: Float, v: Float, out: FloatArray, outOffset: Int = 0): Boolean {
        synchronized(lock) {
            if (!sensorMappingReady) {
                droppedMapCount++
                return false
            }
            return mapSensorLocked(u, v, out, outOffset)
        }
    }

    fun snapshot(): Snapshot = synchronized(lock) {
        val (oriW, oriH) = orientedSize(previewBufW, previewBufH, previewRotation)
        Snapshot(
            mode = if (sensorMappingReady) "sensor" else mapReason.name.lowercase(),
            reason = mapReason.name,
            cameraGen = cameraGeneration.get(),
            previewGen = previewTransformGeneration,
            analysisGen = analysisGeneration,
            lensFront = lensFront,
            previewTransformReady = previewTransformReady,
            analysisTransformReady = analysisTransformReady,
            sensorMappingReady = sensorMappingReady,
            analysisProxyWxH = "${analysisProxyW}x${analysisProxyH}",
            analysisCrop = Rect(analysisCrop).flattenToString(),
            analysisRotation = analysisRotation,
            mediaPipeWxH = "${mediaPipeW}x${mediaPipeH}",
            previewBufWxH = "${previewBufW}x${previewBufH}",
            previewCrop = Rect(previewCrop).flattenToString(),
            previewRotation = previewRotation,
            previewOrientedWxH = "${oriW}x${oriH}",
            previewMirror = previewIsMirroring,
            mirrorX = mirrorX,
            droppedMapCount = droppedMapCount,
        )
    }

    private fun rebuildLocked() {
        sensorMappingReady = false

        if (!previewTransformReady) {
            mapReason = Reason.WAITING_PREVIEW_TRANSFORM
            logStateLocked()
            return
        }
        if (!analysisTransformReady) {
            mapReason = Reason.WAITING_ANALYSIS_TRANSFORM
            logStateLocked()
            return
        }

        val gen = cameraGeneration.get()
        if (previewCameraGen != gen || analysisCameraGen != gen) {
            mapReason = Reason.GENERATION_MISMATCH
            logStateLocked()
            return
        }
        if (analysisLensFront != lensFront) {
            mapReason = Reason.LENS_MISMATCH
            logStateLocked()
            return
        }
        if (analysisRotation != previewRotation) {
            mapReason = Reason.ROTATION_MISMATCH
            logStateLocked()
            return
        }

        val orient = buildOrientScaledEffectiveMatrix(
            analysisProxyW,
            analysisProxyH,
            analysisRotation,
            analysisMaxEdge,
        )
        if (!orient.invert(mediaPipeToAnalysisBuffer)) {
            mediaPipeToAnalysisBuffer.reset()
            mapReason = Reason.ORIENT_INVERT_FAIL
            logStateLocked()
            return
        }

        if (!analysisSensorToBuffer.invert(analysisBufferToSensor) ||
            isEffectivelyIdentity(analysisSensorToBuffer) ||
            isEffectivelyIdentity(previewSensorToBuffer)
        ) {
            mapReason = Reason.SENSOR_MATRIX_INVALID
            logStateLocked()
            return
        }

        previewCropToCanonical.set(
            TransformUtils.getRectToRect(
                RectF(previewCrop),
                RectF(0f, 0f, 1f, 1f),
                previewRotation,
                /* mirroring= */ false,
            ),
        )

        val probe = FloatArray(2)
        if (!mapSensorLocked(0.5f, 0.5f, probe, 0) ||
            probe[0] !in 0.35f..0.65f ||
            probe[1] !in 0.35f..0.65f
        ) {
            mapReason = Reason.SENSOR_PROBE_FAILED
            logStateLocked()
            return
        }

        sensorMappingReady = true
        mapReason = Reason.SENSOR_READY
        logStateLocked()
    }

    private fun mapSensorLocked(u: Float, v: Float, out: FloatArray, outOffset: Int): Boolean {
        scratch[0] = u * mediaPipeW
        scratch[1] = v * mediaPipeH
        mediaPipeToAnalysisBuffer.mapPoints(scratch)
        analysisBufferToSensor.mapPoints(scratch)
        previewSensorToBuffer.mapPoints(scratch)
        previewCropToCanonical.mapPoints(scratch)
        var uc = scratch[0]
        var vc = scratch[1]
        if (!uc.isFinite() || !vc.isFinite()) return false
        if (mirrorX) uc = 1f - uc
        out[outOffset] = uc
        out[outOffset + 1] = vc
        return true
    }

    private fun logStateLocked(force: Boolean = false) {
        if (!force && mapReason == lastLoggedReason) return
        if (droppedMapCount > 0 && mapReason != lastLoggedReason) {
            Log.i(TAG_MAP, "droppedMappedLandmarks=$droppedMapCount reason=${mapReason.name}")
            droppedMapCount = 0
        }
        lastLoggedReason = mapReason
        Log.i(
            TAG_MAP,
            "cameraGen=${cameraGeneration.get()} " +
                "previewGen=$previewTransformGeneration " +
                "analysisGen=$analysisGeneration " +
                "lens=${if (lensFront) "FRONT" else "BACK"} " +
                "rotation=$previewRotation " +
                "sensorReady=$sensorMappingReady " +
                "previewReady=$previewTransformReady " +
                "analysisReady=$analysisTransformReady " +
                "reason=${mapReason.name}",
        )
    }

    private fun logGeomLocked() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastGeomDiagMs < 1_000L) return
        lastGeomDiagMs = now
        val s = snapshot()
        Log.i(
            TAG_FACE,
            "mode=${s.mode} reason=${s.reason} " +
                "sensorReady=${s.sensorMappingReady} " +
                "cameraGen=${s.cameraGen} " +
                "analysisProxy=${s.analysisProxyWxH} crop=${s.analysisCrop} rot=${s.analysisRotation} " +
                "mediaPipe=${s.mediaPipeWxH} " +
                "previewBuf=${s.previewBufWxH} crop=${s.previewCrop} rot=${s.previewRotation} " +
                "previewOriented=${s.previewOrientedWxH} " +
                "mirrorX=${s.mirrorX}",
        )
    }

    data class Snapshot(
        val mode: String,
        val reason: String,
        val cameraGen: Long,
        val previewGen: Long,
        val analysisGen: Long,
        val lensFront: Boolean,
        val previewTransformReady: Boolean,
        val analysisTransformReady: Boolean,
        val sensorMappingReady: Boolean,
        val analysisProxyWxH: String,
        val analysisCrop: String,
        val analysisRotation: Int,
        val mediaPipeWxH: String,
        val previewBufWxH: String,
        val previewCrop: String,
        val previewRotation: Int,
        val previewOrientedWxH: String,
        val previewMirror: Boolean,
        val mirrorX: Boolean,
        val droppedMapCount: Int,
    )

    internal fun buildOrientScaledEffectiveMatrix(
        width: Int,
        height: Int,
        rotationDegrees: Int,
        maxEdge: Int,
    ): Matrix {
        val largest = max(width, height)
        val scale = if (largest > maxEdge && maxEdge > 0) maxEdge.toFloat() / largest else 1f
        val m = Matrix()
        val rot = ((rotationDegrees % 360) + 360) % 360
        if (rot != 0) m.postRotate(rot.toFloat())
        if (scale != 1f) m.postScale(scale, scale)
        val bounds = RectF(0f, 0f, width.toFloat(), height.toFloat())
        m.mapRect(bounds)
        m.postTranslate(-bounds.left, -bounds.top)
        return m
    }

    private fun orientedSize(w: Int, h: Int, rotation: Int): Pair<Int, Int> {
        val r = ((rotation % 360) + 360) % 360
        return if (r == 90 || r == 270) h to w else w to h
    }

    private fun isEffectivelyIdentity(m: Matrix): Boolean {
        val v = FloatArray(9)
        m.getValues(v)
        fun near(a: Float, b: Float) = kotlin.math.abs(a - b) < 1e-4f
        return near(v[0], 1f) && near(v[1], 0f) && near(v[2], 0f) &&
            near(v[3], 0f) && near(v[4], 1f) && near(v[5], 0f) &&
            near(v[6], 0f) && near(v[7], 0f) && near(v[8], 1f)
    }

    private const val TAG_MAP = "V3_MAP_STATE"
    private const val TAG_FACE = "V3_FACE"
}
