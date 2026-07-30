package com.dubai.bimobondapp.ar_camera

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log

/**
 * Last line of defence against a camera pipeline that has stopped producing
 * frames on a device we've never seen.
 *
 * Everything else in this module is *predictive*: it asks the device what it
 * supports (encoder capabilities, camera hardware level, EGL configs) and stays
 * inside those limits. That covers a lot, but not everything — a vendor driver
 * can accept a configuration and then simply fail to deliver, which is what the
 * EGL_BAD_MATCH bug did: the config was legal, `eglMakeCurrent` was legal, and
 * the GL thread still died every frame. No capability query would have predicted
 * that.
 *
 * It does two separate things, and the difference matters:
 *
 * - [reportGlFailure] is **deterministic**. The pipeline has said outright that
 *   it cannot work — a shader that won't compile, an EGL surface the driver
 *   refuses. That degrades the camera to the plain preview immediately.
 * - The frame-stall check is a **heuristic**, and it only logs. Missing frames
 *   cannot distinguish a dead pipeline from a path that simply doesn't report
 *   frames, and acting on that guess tore down a camera that was working fine.
 *   It stays because "no frames for 3s" is a useful thing to see in logcat.
 *
 * Degrading is one-way within a session: a device that genuinely failed will
 * fail again, and retrying the heavy pipeline would just loop.
 */
object ArCameraWatchdog {

    private const val TAG = "ArCameraWatchdog"

    /** No frames for this long while live = the pipeline is considered stuck. */
    private const val STALL_TIMEOUT_MS = 3_000L

    /**
     * Grace period after a bind before stall detection arms. Binding, the OES
     * transition and the first sensor frames can legitimately take a while on
     * slow devices — firing during that would degrade a camera that was about to
     * work fine.
     */
    private const val BIND_GRACE_MS = 4_000L

    private const val CHECK_INTERVAL_MS = 1_000L

    private val handler = Handler(Looper.getMainLooper())

    @Volatile
    private var lastFrameMs = 0L

    @Volatile
    private var armedAtMs = 0L

    @Volatile
    private var running = false

    /** One stall log per bind — this is a hint, not a stream of noise. */
    @Volatile
    private var stallReported = false

    /**
     * True once the watchdog has forced the fallback. Everything that builds a
     * camera configuration checks this, and it never resets within a session —
     * a device that failed once will fail again, and retrying the same heavy
     * pipeline would just produce a freeze/rebind loop.
     */
    @Volatile
    var degraded = false
        private set

    /** Notified when the fallback trips, so the camera can rebind plainly. */
    @Volatile
    var onDegrade: (() -> Unit)? = null

    /**
     * Returns true while frames are legitimately expected to stop arriving, so
     * the stall check stands down instead of misreading a deliberate pause as a
     * dead pipeline.
     *
     * Both known cases do exactly that: GL-surface recording detaches the
     * frame-presented callback for the duration, and suspending the preview for
     * the editor pauses the GL view outright.
     */
    @Volatile
    var isPaused: (() -> Boolean)? = null

    /**
     * Immediate degrade path for a failure we can detect directly rather than
     * inferring from missing frames — a shader that won't compile, or an EGL
     * surface the driver refuses. No point waiting out the stall timeout when
     * the pipeline has already told us it can't work.
     */
    fun reportGlFailure() {
        if (degraded) return
        Log.e(TAG, "GL pipeline reported unusable — falling back immediately")
        degraded = true
        running = false
        handler.post {
            try {
                onDegrade?.invoke()
            } catch (t: Throwable) {
                Log.e(TAG, "degrade handler failed", t)
            }
        }
    }

    /**
     * Called from every bind.
     *
     * [hasPerFrameSignal] must only be true when something actually reports every
     * frame — today that means the OES/GL path, whose renderer calls [onFrame] on
     * each presented frame. The plain PreviewView path has no such callback:
     * CameraX hands over a Surface once and the view renders on its own, so stall
     * detection there would be measuring nothing and would eventually fire on a
     * perfectly healthy camera. It did exactly that, which is why this parameter
     * exists.
     *
     * Direct failure reports ([reportGlFailure]) still work either way.
     */
    fun onCameraBound(hasPerFrameSignal: Boolean) {
        val now = SystemClock.elapsedRealtime()
        armedAtMs = now
        lastFrameMs = now
        stallReported = false
        if (!hasPerFrameSignal) {
            // Nothing to watch — stop rather than count down against silence.
            running = false
            handler.removeCallbacks(checkRunnable)
            return
        }
        if (!running) {
            running = true
            handler.postDelayed(checkRunnable, CHECK_INTERVAL_MS)
        }
    }

    /** Called whenever a preview/GL frame reaches the screen. */
    fun onFrame() {
        lastFrameMs = SystemClock.elapsedRealtime()
    }

    fun stop() {
        running = false
        handler.removeCallbacks(checkRunnable)
        armedAtMs = 0L
        lastFrameMs = 0L
    }

    /** Session reset — only for a full teardown, not between binds. */
    fun reset() {
        stop()
        degraded = false
    }

    private val checkRunnable = object : Runnable {
        override fun run() {
            if (!running) return
            if (!degraded) {
                val now = SystemClock.elapsedRealtime()
                if (isPaused?.invoke() == true) {
                    // Keep the clock fresh so the pause doesn't count against the
                    // pipeline once frames are expected again.
                    lastFrameMs = now
                    armedAtMs = now
                    handler.postDelayed(this, CHECK_INTERVAL_MS)
                    return
                }
                val armed = armedAtMs
                val sinceFrame = now - lastFrameMs
                if (armed > 0L &&
                    now - armed > BIND_GRACE_MS &&
                    sinceFrame > STALL_TIMEOUT_MS &&
                    !stallReported
                ) {
                    // Reported, not acted on. A missing-frame heuristic cannot
                    // tell a genuinely dead pipeline apart from a path that
                    // simply doesn't report frames, and getting that wrong tears
                    // down a camera that was working perfectly — which is exactly
                    // what happened when this drove the fallback directly. The
                    // fallback now only fires on failures the pipeline states
                    // outright (see [reportGlFailure]); this stays as the signal
                    // that something is worth looking at in logcat.
                    stallReported = true
                    Log.w(TAG, "no camera frames for ${sinceFrame}ms")
                }
            }
            handler.postDelayed(this, CHECK_INTERVAL_MS)
        }
    }
}
