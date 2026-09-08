package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.util.Log
import org.opencv.android.OpenCVLoader
import java.util.concurrent.atomic.AtomicBoolean

/**
 * One-time, thread-safe OpenCV native load for V3 sparse tracking.
 *
 * Dependency: `org.opencv:opencv:4.9.0` (Maven Central Android SDK).
 * Load API: [OpenCVLoader.initLocal] → packs/loads `libopencv_java4.so`.
 *
 * Must succeed before any `Mat` / `MatOf*` / native `Point` construction.
 * Failure is soft: visual OF stays off; MediaPipe + predictor path continues.
 */
object V3OpenCvRuntime {
    private val lock = Any()
    private val loaded = AtomicBoolean(false)
    private val loadAttempted = AtomicBoolean(false)

    @Volatile
    private var lastError: String? = null

    /** True only after a successful native load. */
    fun isAvailable(): Boolean = loaded.get()

    /**
     * Idempotent. Safe from any thread. Retries are suppressed after first failure
     * so bindCamera / GL / analysis never spam or crash.
     */
    fun ensureLoaded(): Boolean {
        if (loaded.get()) return true
        if (loadAttempted.get() && !loaded.get()) return false
        synchronized(lock) {
            if (loaded.get()) return true
            if (loadAttempted.get()) return false
            loadAttempted.set(true)
            val ok = try {
                OpenCVLoader.initLocal()
            } catch (t: Throwable) {
                lastError = t.javaClass.simpleName + ": " + (t.message ?: "unknown")
                Log.e(TAG, "V3_OPENCV unavailable initLocal threw: $lastError", t)
                false
            }
            if (ok) {
                loaded.set(true)
                lastError = null
                Log.i(TAG, "V3_OPENCV loaded via OpenCVLoader.initLocal (org.opencv:opencv:4.9.0)")
            } else {
                if (lastError == null) lastError = "OpenCVLoader.initLocal returned false"
                Log.e(TAG, "V3_OPENCV unavailable $lastError — sparse visual tracking disabled")
            }
            return ok
        }
    }

    fun lastErrorMessage(): String? = lastError

    private const val TAG = "V3_OPENCV"
}
