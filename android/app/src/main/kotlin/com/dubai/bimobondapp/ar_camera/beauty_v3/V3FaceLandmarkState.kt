package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import java.util.concurrent.atomic.AtomicLong

/**
 * Thread-safe V3 landmark store.
 *
 * Publishes face regions **only** when sensor mapping is ready.
 * Otherwise holds the last valid same-generation frame briefly, or hides.
 * Never fabricates identity-mapped coordinates.
 */
object V3FaceLandmarkState {
    private val lock = Any()
    private val mappingGeneration = AtomicLong(0L)

    @Volatile
    private var detected = false

    @Volatile
    private var landmarkCount = 0

    @Volatile
    private var analysisWidth = 0

    @Volatile
    private var analysisHeight = 0

    @Volatile
    private var rotationDegrees = 0

    @Volatile
    private var mirrorX = false

    private var publishCameraGen = -1L
    private var publishLensFront = true
    private var publishRotation = 0
    private var publishValidAtMs = 0L
    private var holdingStale = false

    private var analysisFramesInWindow = 0
    private var analysisWindowStartMs = 0L
    private var lastDiagMs = 0L
    private var lastAnalysisFps = 0f
    private var droppedPublishCount = 0

    fun clear() {
        invalidateMapped("clear", cameraGen = -1L, holdLastValid = false)
    }

    /**
     * Invalidates published landmarks.
     * @param holdLastValid if true, keeps last publish until [HOLD_TIMEOUT_MS] if gens match
     */
    fun invalidateMapped(reason: String, cameraGen: Long, holdLastValid: Boolean) {
        synchronized(lock) {
            if (!holdLastValid) {
                detected = false
                landmarkCount = 0
                holdingStale = false
                publishCameraGen = -1L
                publishValidAtMs = 0L
                V3HeadMotionPredictor.reset(reason)
                V3TrackedFaceState.reset(reason)
                V3FaceRegionState.clear()
            } else if (detected && publishCameraGen == cameraGen) {
                holdingStale = true
            } else {
                detected = false
                landmarkCount = 0
                holdingStale = false
                publishCameraGen = -1L
                publishValidAtMs = 0L
                V3HeadMotionPredictor.reset(reason)
                V3TrackedFaceState.reset(reason)
                V3FaceRegionState.clear()
            }
            Log.i(TAG_MAP, "landmarksInvalidated reason=$reason hold=$holdLastValid cameraGen=$cameraGen")
        }
    }

    fun updateAnalysisGeometry(
        proxyWidth: Int,
        proxyHeight: Int,
        cropLeft: Int,
        cropTop: Int,
        cropRight: Int,
        cropBottom: Int,
        rotationDegrees: Int,
        sensorToBufferValues: FloatArray,
        mediaPipeWidth: Int,
        mediaPipeHeight: Int,
        maxEdge: Int,
        mirrorX: Boolean,
        lensFront: Boolean,
    ): Boolean {
        val crop = android.graphics.Rect(cropLeft, cropTop, cropRight, cropBottom)
        val sensor = android.graphics.Matrix().also { it.setValues(sensorToBufferValues) }
        val ready = V3AnalysisToCanonicalTransform.updateAnalysis(
            proxyWidth = proxyWidth,
            proxyHeight = proxyHeight,
            cropRect = crop,
            rotationDegrees = rotationDegrees,
            sensorToBuffer = sensor,
            mediaPipeWidth = mediaPipeWidth,
            mediaPipeHeight = mediaPipeHeight,
            maxEdge = maxEdge,
            mirrorX = mirrorX,
            lensFront = lensFront,
        )
        synchronized(lock) {
            this.analysisWidth = mediaPipeWidth
            this.analysisHeight = mediaPipeHeight
            this.rotationDegrees = rotationDegrees
            this.mirrorX = mirrorX
        }
        return ready
    }

    fun publishFromMediaPipe(
        result: FaceLandmarkerResult?,
        analysisWidth: Int,
        analysisHeight: Int,
        mirrorX: Boolean,
        analysisRotation: Int,
        lensFront: Boolean,
        frameTimestampNs: Long = 0L,
    ) {
        noteAnalysisFrame()
        val cameraGen = V3AnalysisToCanonicalTransform.currentCameraGeneration()
        val sensorReady = V3AnalysisToCanonicalTransform.isSensorMappingReady()
        val callbackMs = SystemClock.elapsedRealtime()
        val frameTsMs = if (frameTimestampNs > 0L) {
            V3CameraClock.nsToElapsedMs(frameTimestampNs)
        } else {
            callbackMs
        }
        if (frameTimestampNs > 0L) {
            V3CameraClock.Latency.noteMediaPipe(frameTimestampNs, callbackMs)
        }

        if (!sensorReady) {
            synchronized(lock) {
                droppedPublishCount++
                this.analysisWidth = analysisWidth
                this.analysisHeight = analysisHeight
                this.mirrorX = mirrorX
                this.rotationDegrees = analysisRotation
                val now = SystemClock.elapsedRealtime()
                val holdOk = detected &&
                    publishCameraGen == cameraGen &&
                    publishLensFront == lensFront &&
                    publishRotation == analysisRotation &&
                    (now - publishValidAtMs) <= HOLD_TIMEOUT_MS
                if (holdOk) {
                    holdingStale = true
                } else {
                    detected = false
                    landmarkCount = 0
                    holdingStale = false
                }
            }
            logFaceDiag(dropped = true)
            return
        }

        if (result == null || result.faceLandmarks().isEmpty()) {
            val lostTransition: Boolean
            synchronized(lock) {
                lostTransition = detected
                detected = false
                landmarkCount = 0
                holdingStale = false
                publishValidAtMs = 0L
                this.analysisWidth = analysisWidth
                this.analysisHeight = analysisHeight
                this.mirrorX = mirrorX
                this.rotationDegrees = analysisRotation
            }
            if (lostTransition) {
                V3HeadMotionPredictor.reset("face_loss")
                V3TrackedFaceState.reset("face_loss")
                V3FaceRegionState.clear()
            }
            logFaceDiag()
            return
        }
        val list = result.faceLandmarks()[0]
        if (list.size < 300) {
            val lostTransition: Boolean
            synchronized(lock) {
                lostTransition = detected
                detected = false
                landmarkCount = 0
                holdingStale = false
                this.analysisWidth = analysisWidth
                this.analysisHeight = analysisHeight
                this.mirrorX = mirrorX
                this.rotationDegrees = analysisRotation
            }
            if (lostTransition) {
                V3HeadMotionPredictor.reset("landmarks_short")
                V3TrackedFaceState.reset("landmarks_short")
                V3FaceRegionState.clear()
            }
            logFaceDiag()
            return
        }

        mappingGeneration.incrementAndGet()
        val scratchUv = FloatArray(2)
        val probe = list[1]
        val mappedOk = V3AnalysisToCanonicalTransform.mapNormToCanonical(
            probe.x(),
            probe.y(),
            scratchUv,
            0,
        )
        var pushOk = false
        var pushTs = 0L
        synchronized(lock) {
            if (!mappedOk) {
                droppedPublishCount++
                val now = SystemClock.elapsedRealtime()
                val holdOk = detected &&
                    publishCameraGen == cameraGen &&
                    publishLensFront == lensFront &&
                    publishRotation == analysisRotation &&
                    (now - publishValidAtMs) <= HOLD_TIMEOUT_MS
                if (!holdOk) {
                    detected = false
                    landmarkCount = 0
                    holdingStale = false
                } else {
                    holdingStale = true
                }
            } else {
                detected = true
                landmarkCount = list.size
                publishCameraGen = cameraGen
                publishLensFront = lensFront
                publishRotation = analysisRotation
                publishValidAtMs = SystemClock.elapsedRealtime()
                holdingStale = false
                pushOk = true
                pushTs = frameTsMs
            }
            this.analysisWidth = analysisWidth
            this.analysisHeight = analysisHeight
            this.mirrorX = mirrorX
            this.rotationDegrees = analysisRotation
        }
        if (pushOk) {
            V3HeadMotionPredictor.pushFromMediaPipe(
                landmarks = list,
                timestampMs = pushTs,
                cameraGen = cameraGen,
                lensFront = lensFront,
                rotationDegrees = analysisRotation,
            )
            V3FaceRegionState.publishFromMediaPipe(
                landmarks = list,
                cameraGen = cameraGen,
                lensFront = lensFront,
                rotationDegrees = analysisRotation,
                timestampMs = pushTs,
            )
        }
        logFaceDiag()
    }

    fun mappingGeneration(): Long = mappingGeneration.get()

    fun snapshotMeta(): Meta = synchronized(lock) {
        expireHoldLocked()
        val geom = V3AnalysisToCanonicalTransform.snapshot()
        Meta(
            detected = detected,
            landmarkCount = landmarkCount,
            analysisWidth = analysisWidth,
            analysisHeight = analysisHeight,
            rotationDegrees = rotationDegrees,
            mirrorX = mirrorX,
            mappingGeneration = mappingGeneration.get(),
            analysisFps = lastAnalysisFps,
            transformMode = geom.mode,
            transformReason = geom.reason,
            sensorReady = geom.sensorMappingReady,
            cameraGen = geom.cameraGen,
            holdingStale = holdingStale,
            analysisProxyWxH = geom.analysisProxyWxH,
            analysisCrop = geom.analysisCrop,
            mediaPipeWxH = geom.mediaPipeWxH,
            previewBufWxH = geom.previewBufWxH,
            previewCrop = geom.previewCrop,
            previewOrientedWxH = geom.previewOrientedWxH,
        )
    }

    private fun expireHoldLocked() {
        if (!holdingStale) return
        val now = SystemClock.elapsedRealtime()
        val gen = V3AnalysisToCanonicalTransform.currentCameraGeneration()
        if (publishCameraGen != gen || (now - publishValidAtMs) > HOLD_TIMEOUT_MS) {
            detected = false
            landmarkCount = 0
            holdingStale = false
        }
    }

    private fun noteAnalysisFrame() {
        val now = SystemClock.elapsedRealtime()
        if (analysisWindowStartMs == 0L) analysisWindowStartMs = now
        analysisFramesInWindow++
        val elapsed = now - analysisWindowStartMs
        if (elapsed >= 1_000L) {
            lastAnalysisFps = analysisFramesInWindow * 1000f / elapsed.coerceAtLeast(1L)
            analysisFramesInWindow = 0
            analysisWindowStartMs = now
        }
    }

    private fun logFaceDiag(dropped: Boolean = false) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastDiagMs < 1_000L) return
        lastDiagMs = now
        val m = snapshotMeta()
        if (dropped && droppedPublishCount > 0) {
            Log.i(TAG_MAP, "droppedPublish=$droppedPublishCount reason=${m.transformReason}")
            droppedPublishCount = 0
        }
        Log.i(
            TAG,
            "detected=${m.detected} " +
                "landmarkCount=${m.landmarkCount} " +
                "analysisWxH=${m.analysisWidth}x${m.analysisHeight} " +
                "rotation=${m.rotationDegrees} " +
                "mirror=${m.mirrorX} " +
                "mappingGeneration=${m.mappingGeneration} " +
                "analysisFps=${"%.1f".format(m.analysisFps)} " +
                "mode=${m.transformMode} reason=${m.transformReason} " +
                "sensorReady=${m.sensorReady} cameraGen=${m.cameraGen} hold=${m.holdingStale} " +
                "proxy=${m.analysisProxyWxH} mediaPipe=${m.mediaPipeWxH} " +
                "previewBuf=${m.previewBufWxH} previewOriented=${m.previewOrientedWxH}",
        )
    }

    data class Meta(
        val detected: Boolean,
        val landmarkCount: Int,
        val analysisWidth: Int,
        val analysisHeight: Int,
        val rotationDegrees: Int,
        val mirrorX: Boolean,
        val mappingGeneration: Long,
        val analysisFps: Float,
        val transformMode: String,
        val transformReason: String,
        val sensorReady: Boolean,
        val cameraGen: Long,
        val holdingStale: Boolean,
        val analysisProxyWxH: String,
        val analysisCrop: String,
        val mediaPipeWxH: String,
        val previewBufWxH: String,
        val previewCrop: String,
        val previewOrientedWxH: String,
    )

    /** Stride for legacy packed debug buffers (head motion predictor API). */
    const val STRIDE = 5
    private const val HOLD_TIMEOUT_MS = 350L
    private const val TAG = "V3_FACE"
    private const val TAG_MAP = "V3_MAP_STATE"
}
