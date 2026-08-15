package com.dubai.bimobondapp.effect360

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

class Effect360Cache(private val context: Context) {
    companion object {
        private const val TAG = "Effect360Cache"
    }

    private val cacheDir = File(context.cacheDir, "effects_360").apply {
        if (!exists()) mkdirs()
    }

    suspend fun getOrFetchAsset(urlStr: String): File? = withContext(Dispatchers.IO) {
        if (urlStr.isEmpty()) return@withContext null

        // Asset file check
        if (urlStr.startsWith("asset://") || urlStr.startsWith("assets/")) {
            val assetName = urlStr.replace("asset://", "").replace("assets/", "")
            val assetFile = File(cacheDir, assetName)
            if (!assetFile.exists() || assetFile.length() == 0L) {
                try {
                    context.assets.open(assetName).use { input ->
                        FileOutputStream(assetFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to copy asset $assetName", e)
                    return@withContext null
                }
            }
            return@withContext assetFile
        }

        // Local file path check
        if (urlStr.startsWith("/") || urlStr.startsWith("file://")) {
            val localFile = File(urlStr.replace("file://", ""))
            return@withContext if (localFile.exists()) localFile else null
        }

        val fileHash = md5(urlStr)
        val cachedFile = File(cacheDir, "$fileHash.mp4")

        if (cachedFile.exists() && cachedFile.length() > 0) {
            cachedFile.setLastModified(System.currentTimeMillis())
            Log.i(TAG, "Serving 360 asset from LRU cache: ${cachedFile.name}")
            return@withContext cachedFile
        }

        // Fetch asset from network
        try {
            Log.i(TAG, "Downloading 360 asset from: $urlStr")
            val conn = URL(urlStr).openConnection() as HttpURLConnection
            conn.connectTimeout = 10000
            conn.readTimeout = 15000
            conn.connect()

            if (conn.responseCode != HttpURLConnection.HTTP_OK) {
                Log.e(TAG, "HTTP error downloading 360 asset: ${conn.responseCode}")
                return@withContext null
            }

            val tempFile = File(cacheDir, "$fileHash.tmp")
            conn.inputStream.use { input ->
                FileOutputStream(tempFile).use { output ->
                    input.copyTo(output)
                }
            }

            if (tempFile.renameTo(cachedFile)) {
                Log.i(TAG, "Successfully cached 360 asset: ${cachedFile.name}")
                return@withContext cachedFile
            } else {
                return@withContext tempFile
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error downloading 360 asset", e)
            return@withContext null
        }
    }

    private fun md5(str: String): String {
        val digest = MessageDigest.getInstance("MD5")
        digest.update(str.toByteArray())
        val messageDigest = digest.digest()
        val hexString = StringBuilder()
        for (b in messageDigest) {
            val hex = Integer.toHexString(0xFF and b.toInt())
            if (hex.length < 2) hexString.append("0")
            hexString.append(hex)
        }
        return hexString.toString()
    }
}
