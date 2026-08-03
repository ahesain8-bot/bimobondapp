package com.dubai.bimobondapp.ar_camera

import android.os.SystemClock
import android.util.Log
import kotlin.math.abs
import kotlin.math.max

/**
 * Back-camera person look (stepped).
 * Step 1: detect person in/out (this object).
 * Step 2: natural skin bright when present — empty-frame grade untouched.
 *
 * **Back camera only.** Front camera must never update or log here.
 *
 * Presence uses enter/exit hysteresis so brief landmark drops do not flicker
 * the person look on/off every few hundred ms.
 *
 * Important: [presentWeight] stays ~0 until [isPresent] — partial fill must not
 * half-apply the −47 remap (that reads yellow/muddy with no real brighten).
 */
object BackPersonPresence {
    private const val TAG = "BackPersonPresence"

    /**
     * Extra [uBrighten] on skin while a person is in the back-camera frame.
     * Scaled by [presentWeight]; empty frame keeps 0 extra.
     */
    const val STEP2_SKIN_BRIGHTEN = 0.45f

    /**
     * Mild skin open while person is present (replaces live −47 crush).
     * Kept soft so face opens without going chalky white.
     */
    const val STEP2_SKIN_RETOUCH_BRIGHT = 0.18f

    /**
     * Typical back-camera face fill sits ~0.05–0.09 at arm's length; face
     * fill drops roughly with distance², so reaching ~1m needed a much
     * lower floor than the arm's-length-tuned 0.040.
     */
    private const val ENTER_FILL = 0.012f

    /** Face fill must stay below this to leave present. */
    private const val EXIT_FILL = 0.005f

    /** Confirm enter after this many ms above [ENTER_FILL]. */
    private const val ENTER_HOLD_MS = 30L

    /**
     * Confirm exit after this many ms below [EXIT_FILL]. Long enough that a
     * quick head turn / motion blur (landmark tracker losing lock for a few
     * frames) does not flip present→false at all — that flicker was what
     * read as "values disappear when the face moves a little."
     */
    private const val EXIT_HOLD_MS = 900L

    /** 0 = empty frame, 1 = face clearly in frame (back camera only). */
    @Volatile
    var presentWeight: Float = 0f
        private set

    @Volatile
    var isPresent: Boolean = false
        private set

    private var lastLoggedPresent: Boolean? = null
    private var logCounter = 0
    private var applyLogCounter = 0

    /** Lightly smoothed fill — reduces one-frame spikes. */
    private var smoothedFill = 0f

    private var enterCandidateSinceMs = 0L
    private var exitCandidateSinceMs = 0L

    fun reset() {
        presentWeight = 0f
        isPresent = false
        lastLoggedPresent = null
        logCounter = 0
        applyLogCounter = 0
        smoothedFill = 0f
        enterCandidateSinceMs = 0L
        exitCandidateSinceMs = 0L
    }

    /** Front camera / teardown — clear with no spam logs. */
    fun clearForFrontCamera() {
        val had = isPresent || presentWeight > 0.01f
        presentWeight = 0f
        isPresent = false
        smoothedFill = 0f
        enterCandidateSinceMs = 0L
        exitCandidateSinceMs = 0L
        if (had && lastLoggedPresent != false) {
            lastLoggedPresent = false
            Log.i(TAG, "ignored — front camera (back-only feature)")
        }
    }

    /**
     * Back camera only. Caller must not invoke this while the front lens is active.
     */
    fun updateFromBackCamera(faceFill: Float) {
        val fill = faceFill.coerceIn(0f, 1f)
        smoothedFill += (fill - smoothedFill) * 0.40f
        val now = SystemClock.elapsedRealtime()

        if (!isPresent) {
            if (smoothedFill >= ENTER_FILL) {
                if (enterCandidateSinceMs == 0L) enterCandidateSinceMs = now
                if (now - enterCandidateSinceMs >= ENTER_HOLD_MS) {
                    isPresent = true
                    exitCandidateSinceMs = 0L
                    enterCandidateSinceMs = 0L
                    logTransition(present = true, reason = "face_enter")
                }
            } else {
                enterCandidateSinceMs = 0L
            }
        } else {
            if (smoothedFill < EXIT_FILL) {
                if (exitCandidateSinceMs == 0L) exitCandidateSinceMs = now
                if (now - exitCandidateSinceMs >= EXIT_HOLD_MS) {
                    isPresent = false
                    enterCandidateSinceMs = 0L
                    exitCandidateSinceMs = 0L
                    logTransition(present = false, reason = "face_exit")
                }
            } else {
                exitCandidateSinceMs = 0L
            }
        }

        // Only drive weight when fully present — no partial −47 remap.
        val targetW = if (isPresent) {
            max(0.85f, smoothstep(EXIT_FILL, 0.12f, smoothedFill))
        } else {
            0f
        }
        val ease = if (isPresent) 0.70f else 0.55f
        presentWeight += (targetW - presentWeight) * ease

        logCounter++
        if (logCounter % 30 == 0) {
            Log.i(
                TAG,
                "BACK fill=${"%.3f".format(fill)} " +
                    "smoothFill=${"%.3f".format(smoothedFill)} " +
                    "weight=${"%.3f".format(presentWeight)} present=$isPresent " +
                    "step2Bright=${"%.2f".format(STEP2_SKIN_BRIGHTEN * presentWeight)}",
            )
        }
    }

    /**
     * Called from GL with the eased brighten actually sent to the shader.
     * Same tag so `adb logcat -s BackPersonPresence` shows detect + apply.
     */
    fun logStep2Apply(
        targetBright: Float,
        smoothedBright: Float,
        totalUBrighten: Float,
    ) {
        if (ArCameraBridge.isFrontCamera) return
        applyLogCounter++
        if (applyLogCounter % 20 != 0) return
        Log.i(
            TAG,
            "STEP2_APPLY present=$isPresent " +
                "weight=${"%.3f".format(presentWeight)} " +
                "targetBright=${"%.3f".format(targetBright)} " +
                "smoothedBright=${"%.3f".format(smoothedBright)} " +
                "uBrighten=${"%.3f".format(totalUBrighten)} " +
                if (isPresent) {
                    "(soft bright −47→+${"%.2f".format(STEP2_SKIN_RETOUCH_BRIGHT)})"
                } else {
                    "(idle empty grade)"
                },
        )
    }

    private fun logTransition(present: Boolean, reason: String) {
        if (lastLoggedPresent == present) return
        lastLoggedPresent = present
        Log.i(
            TAG,
            if (present) {
                "PERSON_IN_FRAME ($reason) — natural bright ON " +
                    "(+${"%.2f".format(STEP2_SKIN_BRIGHTEN)}, " +
                    "retouch→+${"%.2f".format(STEP2_SKIN_RETOUCH_BRIGHT)})"
            } else {
                "EMPTY_FRAME ($reason) — person look OFF, empty −47 / max contrast"
            },
        )
    }

    private fun smoothstep(edge0: Float, edge1: Float, x: Float): Float {
        if (abs(edge1 - edge0) < 1e-5f) return if (x >= edge1) 1f else 0f
        val t = ((x - edge0) / (edge1 - edge0)).coerceIn(0f, 1f)
        return t * t * (3f - 2f * t)
    }
}
