package com.dubai.bimobondapp.ar_camera

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Manages asynchronous downloading and LRU disk caching of MP4 video overlay assets.
 * Prevents redundant network downloads when selecting previously used effects.
 */
object EffectCacheManager {

    private const val MAX_CACHE_BYTES = 100 * 1024 * 1024L // 100 MB max LRU cache limit
    private val executor = Executors.newFixedThreadPool(2)

    private val memoryMap = ConcurrentHashMap<String, File>()

    fun getCacheDir(context: Context): File {
        return File(context.cacheDir, "ar_effect_cache").apply { if (!exists()) mkdirs() }
    }

    fun getOverlayFile(context: Context, urlStr: String, onResult: (File?) -> Unit) {
        val key = urlStr.hashCode().toString()
        val cachedInMemory = memoryMap[key]
        if (cachedInMemory != null && cachedInMemory.exists()) {
            onResult(cachedInMemory)
            return
        }

        val cacheDir = getCacheDir(context)
        val file = File(cacheDir, "effect_$key.mp4")
        if (file.exists() && file.length() > 0) {
            file.setLastModified(System.currentTimeMillis())
            memoryMap[key] = file
            onResult(file)
            return
        }

        executor.execute {
            val downloadedFile = downloadFile(urlStr, file)
            if (downloadedFile != null) {
                pruneLruCache(cacheDir)
                memoryMap[key] = downloadedFile
            }
            onResult(downloadedFile)
        }
    }

    private fun downloadFile(urlStr: String, targetFile: File): File? {
        return try {
            val url = URL(urlStr)
            val connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 10_000
            connection.readTimeout = 15_000
            connection.connect()

            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                return null
            }

            connection.inputStream.use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }
            targetFile
        } catch (_: Exception) {
            if (targetFile.exists()) targetFile.delete()
            null
        }
    }

    private fun pruneLruCache(cacheDir: File) {
        val files = cacheDir.listFiles() ?: return
        var totalSize = files.sumOf { it.length() }
        if (totalSize <= MAX_CACHE_BYTES) return

        val sortedFiles = files.sortedBy { it.lastModified() }
        for (f in sortedFiles) {
            if (totalSize <= MAX_CACHE_BYTES) break
            val size = f.length()
            if (f.delete()) {
                totalSize -= size
            }
        }
    }

    fun clearCache(context: Context) {
        memoryMap.clear()
        try {
            getCacheDir(context).deleteRecursively()
        } catch (_: Exception) {
        }
    }
}
