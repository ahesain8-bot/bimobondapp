package com.dubai.bimobondapp.ar_camera

import android.os.SystemClock
import kotlin.math.hypot

/**
 * Keeps stickers stuck to the face by extrapolating pose to "now + pipeline lag".
 * PreviewView is ahead of ImageAnalysis→MediaPipe; without this, stickers trail.
 *
 * [sampleGen] must only change when landmarks are updated (not every onDraw).
 */
object StickerPoseSmoother {
    /** Extra lead vs live preview (ms). Higher = tighter stick, more overshoot risk. */
    private const val PIPELINE_LAG_MS = 95f
    private const val MAX_PREDICT_FRAC = 0.55f
    private const val VEL_EMA = 0.55f

    private data class State(
        var measured: StickerPose,
        var measuredAtMs: Long,
        var sampleGen: Long,
        var vx: Float = 0f,
        var vy: Float = 0f,
        var vRoll: Float = 0f,
        var vW: Float = 0f,
        var vH: Float = 0f,
    )

    private val states = HashMap<String, State>()

    fun reset() {
        states.clear()
    }

    fun smooth(id: String, current: StickerPose, sampleGen: Long): StickerPose {
        val now = SystemClock.elapsedRealtime()
        var state = states[id]

        if (state == null) {
            state = State(current, now, sampleGen)
            states[id] = state
            return current
        }

        if (state.sampleGen != sampleGen) {
            val dt = (now - state.measuredAtMs).toFloat().coerceAtLeast(8f)
            if (dt < 160f) {
                val nvx = (current.centerX - state.measured.centerX) / dt
                val nvy = (current.centerY - state.measured.centerY) / dt
                state.vx = state.vx * (1f - VEL_EMA) + nvx * VEL_EMA
                state.vy = state.vy * (1f - VEL_EMA) + nvy * VEL_EMA

                var dRoll = current.rollDeg - state.measured.rollDeg
                while (dRoll > 180f) dRoll -= 360f
                while (dRoll < -180f) dRoll += 360f
                state.vRoll = state.vRoll * (1f - VEL_EMA) + (dRoll / dt) * VEL_EMA
                state.vW = state.vW * (1f - VEL_EMA) +
                    ((current.width - state.measured.width) / dt) * VEL_EMA
                state.vH = state.vH * (1f - VEL_EMA) +
                    ((current.height - state.measured.height) / dt) * VEL_EMA
            } else {
                state.vx = 0f
                state.vy = 0f
                state.vRoll = 0f
                state.vW = 0f
                state.vH = 0f
            }
            state.measured = current
            state.measuredAtMs = now
            state.sampleGen = sampleGen
        }

        // Age since measure + fixed pipeline lag → stick to live preview, not trail it.
        val age = (now - state.measuredAtMs).toFloat().coerceAtLeast(0f)
        val predictMs = PIPELINE_LAG_MS + age

        var dx = state.vx * predictMs
        var dy = state.vy * predictMs
        val maxJump = (state.measured.width * MAX_PREDICT_FRAC).coerceAtLeast(10f)
        val mag = hypot(dx.toDouble(), dy.toDouble()).toFloat()
        if (mag > maxJump && mag > 0.001f) {
            val s = maxJump / mag
            dx *= s
            dy *= s
        }

        val m = state.measured
        return StickerPose(
            centerX = m.centerX + dx,
            centerY = m.centerY + dy,
            width = (m.width + state.vW * predictMs).coerceAtLeast(1f),
            height = (m.height + state.vH * predictMs).coerceAtLeast(0f),
            rollDeg = m.rollDeg + (state.vRoll * predictMs).coerceIn(-14f, 14f),
            yawScaleX = m.yawScaleX,
            pivotU = m.pivotU,
            pivotV = m.pivotV,
        )
    }
}
