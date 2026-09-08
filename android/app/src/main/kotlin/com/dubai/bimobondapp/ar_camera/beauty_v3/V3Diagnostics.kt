package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.os.SystemClock
import android.util.Log

/**
 * V3-only diagnostics. Logs at most once per second. Tracks whether any
 * texture/FBO allocation happened after warmup (must stay false in steady state).
 */
object V3Diagnostics {
    private const val TAG = "V3_FRAME"
    private const val ACTIVE_TAG = "V3_ACTIVE_RENDER"

    @Volatile
    private var warmedUp = false

    private var framesInWindow = 0
    private var windowStartMs = 0L
    private var lastLogMs = 0L
    private var allocAfterWarmup = false
    private var lastContract: V3FrameContract? = null
    private var lastFrameTimeMs = 0f

    private var lastActivePathLogMs = 0L
    private var lastActivePathLogged: String? = null

    fun markWarmupComplete() {
        warmedUp = true
    }

    fun noteTextureOrFboAllocation(where: String) {
        if (warmedUp) {
            allocAfterWarmup = true
            Log.w(TAG, "ALLOC_AFTER_WARMUP where=$where")
        }
    }

    /** Once per second: which preview render branch actually ran. */
    fun logActiveRenderPath(path: String) {
        val now = SystemClock.elapsedRealtime()
        if (path == lastActivePathLogged && now - lastActivePathLogMs < 1_000L) return
        lastActivePathLogMs = now
        lastActivePathLogged = path
        Log.i(ACTIVE_TAG, "path=$path")
    }

    fun onFrame(contract: V3FrameContract, frameTimeMs: Float) {
        lastContract = contract
        lastFrameTimeMs = frameTimeMs
        val now = SystemClock.elapsedRealtime()
        if (windowStartMs == 0L) {
            windowStartMs = now
            lastLogMs = now
        }
        framesInWindow++
        if (now - lastLogMs < 1_000L) return
        val elapsed = (now - windowStartMs).coerceAtLeast(1L)
        val fps = framesInWindow * 1000f / elapsed
        val c = contract
        Log.i(
            TAG,
            "source=${c.sourceWidth}x${c.sourceHeight} " +
                "oriented=${c.orientedWidth}x${c.orientedHeight} " +
                "canonical=${c.canonicalWidth}x${c.canonicalHeight} " +
                "rotation=${c.rotationDegrees} " +
                "mirror=${c.mirrorX} " +
                "generation=${c.frameGeneration} " +
                "fps=${"%.1f".format(fps)} " +
                "frameTimeMs=${"%.2f".format(frameTimeMs)} " +
                "glReadPixels=false Bitmap=false " +
                "allocAfterWarmup=$allocAfterWarmup",
        )
        framesInWindow = 0
        windowStartMs = now
        lastLogMs = now
    }

    fun reset() {
        warmedUp = false
        framesInWindow = 0
        windowStartMs = 0L
        lastLogMs = 0L
        allocAfterWarmup = false
        lastContract = null
        lastFrameTimeMs = 0f
        lastActivePathLogMs = 0L
        lastActivePathLogged = null
    }
}
