package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.util.Log
import java.io.File
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Disk cache for remote MP4 overlay files (prefetch + offline replay).
 */
object ScreenOverlayVideoCache {
    private const val TAG = "ArCameraOverlay"
    private val executor = Executors.newSingleThreadExecutor()
    /** In-flight downloads so we don't stampede the same URL. */
    private val inflight = ConcurrentHashMap<String, Boolean>()

    fun prefetch(context: Context, urls: List<String>) {
        val appContext = context.applicationContext
        for (url in urls) {
            if (url.isBlank()) continue
            requestDownload(appContext, url)
        }
    }

    /**
     * Returns the on-disk file only when it already exists and is non-empty.
     * Prefer this for playback so ExoPlayer hits local I/O instead of the network.
     */
    fun readyFile(context: Context, url: String): File? {
        if (url.isBlank()) return null
        val file = File(cacheDir(context), fileNameFor(url))
        return if (file.exists() && file.length() > 0L) file else null
    }

    /** Path used for a URL even before download completes. */
    fun localFile(context: Context, url: String): File? {
        if (url.isBlank()) return null
        return File(cacheDir(context), fileNameFor(url))
    }

    /**
     * Kick off a background download if missing. Safe to call repeatedly.
     * Playback can start from the network URL immediately; next open uses disk.
     */
    fun requestDownload(context: Context, url: String) {
        if (url.isBlank()) return
        val appContext = context.applicationContext
        if (readyFile(appContext, url) != null) return
        if (inflight.putIfAbsent(url, true) != null) return
        executor.execute {
            try {
                ensureDownloaded(appContext, url)
            } catch (t: Throwable) {
                Log.w(TAG, "video overlay download failed: $url", t)
            } finally {
                inflight.remove(url)
            }
        }
    }

    fun ensureDownloaded(context: Context, url: String): File? {
        val out = localFile(context, url) ?: return null
        if (out.exists() && out.length() > 0L) return out
        out.parentFile?.mkdirs()
        val tmp = File(out.parentFile, "${out.name}.part")
        try {
            URL(url).openStream().use { input ->
                tmp.outputStream().use { output -> input.copyTo(output) }
            }
            if (!tmp.renameTo(out)) {
                tmp.copyTo(out, overwrite = true)
                tmp.delete()
            }
        } catch (t: Throwable) {
            tmp.delete()
            throw t
        }
        return out
    }

    private fun cacheDir(context: Context): File =
        File(context.cacheDir, "ar_overlay_video").apply { mkdirs() }

    private fun fileNameFor(url: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(url.toByteArray())
            .joinToString("") { "%02x".format(it) }
        val ext = url.substringBefore('?').substringAfterLast('.', "mp4")
        return "$hash.$ext"
    }
}
