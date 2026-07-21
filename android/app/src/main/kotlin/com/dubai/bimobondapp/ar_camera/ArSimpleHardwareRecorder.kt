package com.dubai.bimobondapp.ar_camera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.PendingRecording
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.core.content.ContextCompat
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

class ArSimpleHardwareRecorder {
    @Volatile
    private var videoCapture: VideoCapture<Recorder>? = null

    @Volatile
    private var active: Recording? = null

    private val recording = AtomicBoolean(false)
    private var outputFile: File? = null

    @Volatile
    private var stopCallback: ((File?, String?) -> Unit)? = null

    fun attach(capture: VideoCapture<Recorder>?) {
        videoCapture = capture
    }

    fun isAvailable(): Boolean = videoCapture != null

    fun isRecording(): Boolean = recording.get() || active != null

    fun start(context: Context, output: File, onStarted: (Boolean, String?) -> Unit) {
        if (recording.get() || active != null) {
            onStarted(false, "already_recording")
            return
        }
        val capture = videoCapture
        if (capture == null) {
            onStarted(false, "no_video_capture")
            return
        }

        outputFile = output
        val pending: PendingRecording = try {
            val opts = FileOutputOptions.Builder(output).build()
            var p = capture.output.prepareRecording(context, opts)
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED
            ) {
                p = p.withAudioEnabled()
            }
            p
        } catch (e: Exception) {
            Log.e(TAG, "prepareRecording failed", e)
            outputFile = null
            onStarted(false, e.message ?: "prepare_failed")
            return
        }

        try {
            active = pending.start(ContextCompat.getMainExecutor(context)) { event ->
                when (event) {
                    is VideoRecordEvent.Start -> {
                        recording.set(true)
                    }
                    is VideoRecordEvent.Finalize -> {
                        recording.set(false)
                        active = null
                        val cb = stopCallback
                        stopCallback = null
                        val file = outputFile
                        outputFile = null
                        if (cb == null) return@start
                        if (event.hasError()) {
                            file?.delete()
                            cb(
                                null,
                                event.cause?.message
                                    ?: "record_error_${event.error}",
                            )
                        } else if (file != null && file.exists() && file.length() > 0L) {
                            cb(file, null)
                        } else {
                            cb(null, "empty_video")
                        }
                    }
                    else -> Unit
                }
            }
            recording.set(true)
            onStarted(true, null)
        } catch (e: Exception) {
            Log.e(TAG, "startRecording failed", e)
            recording.set(false)
            active = null
            outputFile = null
            onStarted(false, e.message ?: "record_start_failed")
        }
    }

    fun stop(onResult: (File?, String?) -> Unit) {
        val session = active
        if (session == null) {
            recording.set(false)
            onResult(null, "not_recording")
            return
        }
        stopCallback = onResult
        try {
            session.stop()
        } catch (e: Exception) {
            stopCallback = null
            recording.set(false)
            active = null
            outputFile = null
            onResult(null, e.message ?: "record_stop_failed")
        }
    }

    fun abort() {
        stopCallback = null
        recording.set(false)
        try {
            active?.stop()
        } catch (_: Exception) {
        }
        active = null
        outputFile?.delete()
        outputFile = null
    }

    companion object {
        private const val TAG = "ArSimpleHwRecorder"
    }
}
