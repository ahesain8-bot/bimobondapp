package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.util.Log
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Process-wide face landmarker kept warm so AR camera opens quickly. */
object FaceLandmarkerHolder {

    private const val TAG = "FaceLandmarkerHolder"

    @Volatile
    private var helper: FaceLandmarkerHelper? = null

    private val warmupStarted = AtomicBoolean(false)
    private val ready = AtomicBoolean(false)
    private var warmupExecutor: ExecutorService? = null

    fun warmup(context: Context) {
        if (ready.get()) return
        if (!warmupStarted.compareAndSet(false, true)) return

        val appContext = context.applicationContext
        val executor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "ar-face-landmarker-warmup").apply { isDaemon = true }
        }
        warmupExecutor = executor

        executor.execute {
            try {
                val instance = FaceLandmarkerHelper(appContext).also { it.setup() }
                helper = instance
                ready.set(true)
                Log.i(TAG, "Face landmarker ready")
            } catch (e: Exception) {
                Log.e(TAG, "Face landmarker warmup failed", e)
                warmupStarted.set(false)
            }
        }
    }

    fun get(): FaceLandmarkerHelper? = helper

    fun release() {
        helper?.close()
        helper = null
        ready.set(false)
        warmupStarted.set(false)
        warmupExecutor?.shutdownNow()
        warmupExecutor = null
    }
}
