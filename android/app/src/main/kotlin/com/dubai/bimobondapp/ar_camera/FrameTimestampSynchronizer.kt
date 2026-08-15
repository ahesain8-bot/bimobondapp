package com.dubai.bimobondapp.ar_camera

import android.os.SystemClock

/**
 * Manages monotonic presentation timestamp calculations for aligning live camera
 * frames with MP4 video overlay playback timelines and MediaCodec H.264 recording timestamps.
 */
class FrameTimestampSynchronizer {

    private var recordingStartNanos: Long = 0L
    private var isRecording: Boolean = false
    private var pausedDurationNanos: Long = 0L
    private var pauseStartNanos: Long = 0L

    fun startRecording() {
        recordingStartNanos = SystemClock.elapsedRealtimeNanos()
        pausedDurationNanos = 0L
        isRecording = true
    }

    fun pauseRecording() {
        if (isRecording && pauseStartNanos == 0L) {
            pauseStartNanos = SystemClock.elapsedRealtimeNanos()
        }
    }

    fun resumeRecording() {
        if (isRecording && pauseStartNanos != 0L) {
            pausedDurationNanos += SystemClock.elapsedRealtimeNanos() - pauseStartNanos
            pauseStartNanos = 0L
        }
    }

    fun getRecordingPresentationTimeUs(): Long {
        if (!isRecording) return 0L
        val now = if (pauseStartNanos != 0L) pauseStartNanos else SystemClock.elapsedRealtimeNanos()
        val elapsedNanos = now - recordingStartNanos - pausedDurationNanos
        return (elapsedNanos / 1000L).coerceAtLeast(0L)
    }

    fun calculateOverlaySeekPositionMs(effect: EffectDefinition): Long {
        val presentationMs = getRecordingPresentationTimeUs() / 1000L
        val overlayTimeMs = presentationMs - effect.startTimeMs
        if (overlayTimeMs < 0) return 0L

        if (effect.durationMs > 0 && overlayTimeMs > effect.durationMs) {
            return if (effect.loop) {
                overlayTimeMs % effect.durationMs
            } else {
                effect.durationMs
            }
        }
        return overlayTimeMs
    }

    fun reset() {
        recordingStartNanos = 0L
        isRecording = false
        pausedDurationNanos = 0L
        pauseStartNanos = 0L
    }
}
