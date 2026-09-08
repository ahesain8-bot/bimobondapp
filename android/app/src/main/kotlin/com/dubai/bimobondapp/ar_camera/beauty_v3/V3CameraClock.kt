package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.os.SystemClock
import android.util.Log

/**
 * Single monotonic time base for V3 face tracking.
 *
 * CameraX [ImageProxy] timestamps and [android.graphics.SurfaceTexture] timestamps
 * are treated as [SystemClock.elapsedRealtimeNanos]-compatible boottime ns.
 * All tracking ages are computed in elapsedRealtime milliseconds derived from those.
 */
object V3CameraClock {
    /** Converts camera/ST nanoseconds → elapsedRealtime ms. */
    fun nsToElapsedMs(timestampNs: Long): Long {
        if (timestampNs <= 0L) return SystemClock.elapsedRealtime()
        return timestampNs / 1_000_000L
    }

    fun nowElapsedMs(): Long = SystemClock.elapsedRealtime()

    fun nowElapsedNs(): Long = SystemClock.elapsedRealtimeNanos()

    /**
     * Latency diagnostics (1 Hz). Call from analysis + GL paths.
     */
    object Latency {
        @Volatile var lastSurfaceTsMs: Long = 0L
        @Volatile var lastAnalysisInputTsMs: Long = 0L
        @Volatile var lastMpInputTsMs: Long = 0L
        @Volatile var lastMpCallbackMs: Long = 0L
        @Volatile var lastGeometryTsMs: Long = 0L
        @Volatile var lastRenderTsMs: Long = 0L
        @Volatile var lastGeometryAgeMs: Float = 0f
        @Volatile var lastMpInferLagMs: Float = 0f

        private var lastLogMs = 0L

        fun noteAnalysisInput(frameTsNs: Long, arrivalMs: Long = nowElapsedMs()) {
            lastAnalysisInputTsMs = nsToElapsedMs(frameTsNs)
            val lag = (arrivalMs - lastAnalysisInputTsMs).toFloat()
            // Keep latest; detailed log in flush
            if (lastMpInferLagMs == 0f) lastMpInferLagMs = lag
        }

        fun noteMediaPipe(frameTsNs: Long, callbackMs: Long = nowElapsedMs()) {
            lastMpInputTsMs = nsToElapsedMs(frameTsNs)
            lastMpCallbackMs = callbackMs
            lastMpInferLagMs = (callbackMs - lastMpInputTsMs).toFloat().coerceAtLeast(0f)
        }

        fun noteGeometry(geometryTsMs: Long) {
            lastGeometryTsMs = geometryTsMs
        }

        fun noteRender(surfaceTsNs: Long, geometryTsMs: Long) {
            lastSurfaceTsMs = nsToElapsedMs(surfaceTsNs)
            lastRenderTsMs = lastSurfaceTsMs
            lastGeometryAgeMs = (lastRenderTsMs - geometryTsMs).toFloat()
            maybeLog()
        }

        private fun maybeLog() {
            val now = nowElapsedMs()
            if (now - lastLogMs < 1_000L) return
            lastLogMs = now
            Log.i(
                TAG,
                "surfaceTsMs=$lastSurfaceTsMs " +
                    "analysisInputTsMs=$lastAnalysisInputTsMs " +
                    "mpInputTsMs=$lastMpInputTsMs " +
                    "mpCallbackMs=$lastMpCallbackMs " +
                    "mpInferLagMs=${"%.1f".format(lastMpInferLagMs)} " +
                    "geometryTsMs=$lastGeometryTsMs " +
                    "renderTsMs=$lastRenderTsMs " +
                    "geometryAgeMs=${"%.1f".format(lastGeometryAgeMs)}",
            )
        }

        private const val TAG = "V3_TIME"
    }
}
