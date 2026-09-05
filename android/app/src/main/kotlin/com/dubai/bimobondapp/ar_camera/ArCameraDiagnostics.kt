package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log

/**
 * Lightweight debug-build counters for the production POST camera (former B / RAW_OES).
 * Visible preview always runs the B OES path; filters layer on conditionally.
 */
object ArCameraDiagnostics {
    const val TAG = "ArCameraDiag"

    @Volatile
    private var enabled = false

    fun configure(context: Context) {
        enabled = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (enabled) {
            Log.i(
                TAG,
                "STATE mode=PRODUCTION_RAW_OES raw=true " +
                    "sceneGrainCleanBypassed=conditional renderCapBypassed=true",
            )
        }
    }

    private var glWindowStartNs = System.nanoTime()
    private var analysisWindowStartNs = System.nanoTime()
    private var oesCallbacks = 0L
    private var renderedFrames = 0L
    private var analysisFrames = 0L
    private var analysisProcessed = 0L
    private var analysisDropped = 0L
    private var analysisTotalNs = 0L
    private var mediaPipeTotalNs = 0L

    @Synchronized
    fun onOesCallback() {
        if (enabled) oesCallbacks++
    }

    @Synchronized
    fun onAnalysisFrame() {
        if (enabled) analysisFrames++
    }

    @Synchronized
    fun onAnalysisDropped() {
        if (enabled) analysisDropped++
    }

    @Synchronized
    fun onAnalysisProcessed(totalNs: Long, mediaPipeNs: Long) {
        if (!enabled) return
        analysisProcessed++
        analysisTotalNs += totalNs
        mediaPipeTotalNs += mediaPipeNs
        val now = System.nanoTime()
        val elapsedNs = now - analysisWindowStartNs
        if (elapsedNs >= 2_000_000_000L) {
            val seconds = elapsedNs / 1_000_000_000.0
            val analysisMs = analysisTotalNs / analysisProcessed / 1_000_000.0
            val mediaPipeMs = mediaPipeTotalNs / analysisProcessed / 1_000_000.0
            Log.i(
                TAG,
                "ANALYSIS fps=${"%.1f".format(analysisFrames / seconds)} " +
                    "processed=$analysisProcessed dropped=$analysisDropped " +
                    "processingMs=${"%.2f".format(analysisMs)} " +
                    "mediaPipeMs=${"%.2f".format(mediaPipeMs)}",
            )
            analysisWindowStartNs = now
            analysisFrames = 0
            analysisProcessed = 0
            analysisDropped = 0
            analysisTotalNs = 0
            mediaPipeTotalNs = 0
        }
    }

    @Synchronized
    fun onGlDraw(
        drawNs: Long,
        bufferW: Int,
        bufferH: Int,
        viewW: Int,
        viewH: Int,
        surfaceW: Int,
        surfaceH: Int,
        viewport: IntArray,
        fbos: String,
        sharpen: Float,
        blemish: Float,
        passThrough: Boolean,
        sceneGrainCleanActive: Boolean,
    ) {
        if (!enabled) return
        renderedFrames++
        val now = System.nanoTime()
        val elapsedNs = now - glWindowStartNs
        if (elapsedNs < 2_000_000_000L) return
        val seconds = elapsedNs / 1_000_000_000.0
        val renderedFps = renderedFrames / seconds
        val callbackFps = oesCallbacks / seconds
        val skipped = (oesCallbacks - renderedFrames).coerceAtLeast(0)
        val beauty = LiveBeautyState.adjustments
        val retouch = LiveRetouchState.adjustments
        Log.i(
            TAG,
            "GL mode=PRODUCTION_RAW_OES buffer=${bufferW}x$bufferH view=${viewW}x$viewH " +
                "surface=${surfaceW}x$surfaceH viewport=${viewport.joinToString("x")} " +
                "render=${viewport[2]}x${viewport[3]} drawMs=${"%.2f".format(drawNs / 1_000_000.0)} " +
                "oesCallbackFps=${"%.1f".format(callbackFps)} rendererFps=${"%.1f".format(renderedFps)} " +
                "skipped=$skipped passThrough=$passThrough fbos={$fbos}",
        )
        Log.i(
            TAG,
            "STATE mode=PRODUCTION_RAW_OES Magic=${LiveBeautyState.magicOn} " +
                "magicStrength=${LiveBeautyState.magicStrength} " +
                "smooth=${beauty.smooth} whiten=${beauty.whiten} brighten=${beauty.brighten} " +
                "blemish=$blemish sharpen=$sharpen retouch=$retouch makeup=${LiveBeautyState.needsAnyMakeup()} " +
                "sceneGrainCleanBypassed=${!sceneGrainCleanActive} renderCapBypassed=true",
        )
        glWindowStartNs = now
        oesCallbacks = 0
        renderedFrames = 0
    }
}
