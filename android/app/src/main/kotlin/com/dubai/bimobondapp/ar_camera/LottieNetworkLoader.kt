package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.util.Log
import com.airbnb.lottie.LottieComposition
import com.airbnb.lottie.LottieCompositionFactory
import com.airbnb.lottie.LottieResult
import com.airbnb.lottie.LottieTask
import java.io.BufferedInputStream
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.GZIPInputStream
import java.util.zip.ZipInputStream

/**
 * Bulletproof network loader for backend Lottie animations (.json, .lottie, .dotlottie).
 *
 * Solves common Android Lottie network load failures:
 * 1. CDN / S3 403 Forbidden blocks due to missing User-Agent header.
 * 2. GZIP compressed responses from web servers.
 * 3. Cross-protocol (http -> https) redirects.
 * 4. Automatic DotLottie (.lottie / .zip) archive magic byte detection.
 */
object LottieNetworkLoader {

    private const val TAG = "LottieNetworkLoader"
    private const val USER_AGENT = "Mozilla/5.0 (Linux; Android 10; Mobile) LottieFetcher/1.0"

    fun loadFromUrl(context: Context, urlString: String, cacheKey: String = urlString): LottieTask<LottieComposition> {
        val cached = com.airbnb.lottie.model.LottieCompositionCache.getInstance().get(cacheKey)
        if (cached != null) {
            return LottieTask { LottieResult(cached) }
        }
        return LottieTask {
            try {
                val composition = fetchCompositionDirect(urlString, cacheKey)
                com.airbnb.lottie.model.LottieCompositionCache.getInstance().put(cacheKey, composition)
                LottieResult(composition)
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to load Lottie overlay from URL: $urlString", t)
                LottieResult(t)
            }
        }
    }

    private fun fetchCompositionDirect(urlString: String, cacheKey: String): LottieComposition {
        var connection: HttpURLConnection? = null
        try {
            var currentUrl = urlString
            var redirects = 0
            while (redirects < 5) {
                val url = URL(currentUrl)
                connection = url.openConnection() as HttpURLConnection
                connection.connectTimeout = 15_000
                connection.readTimeout = 15_000
                connection.instanceFollowRedirects = true
                connection.setRequestProperty("User-Agent", USER_AGENT)
                connection.setRequestProperty("Accept", "application/json, application/zip, text/plain, */*")
                connection.setRequestProperty("Accept-Encoding", "gzip, deflate")

                val status = connection.responseCode
                if (status == HttpURLConnection.HTTP_MOVED_PERM ||
                    status == HttpURLConnection.HTTP_MOVED_TEMP ||
                    status == HttpURLConnection.HTTP_SEE_OTHER ||
                    status == 307 || status == 308
                ) {
                    val loc = connection.getHeaderField("Location")
                    if (!loc.isNullOrBlank()) {
                        currentUrl = loc
                        redirects++
                        connection.disconnect()
                        continue
                    }
                }

                if (status !in 200..299) {
                    throw IllegalArgumentException("HTTP error $status when downloading overlay: $currentUrl")
                }
                break
            }

            val conn = connection ?: throw IllegalStateException("Connection null for $urlString")
            val encoding = conn.contentEncoding
            var rawStream: InputStream = conn.inputStream
            if ("gzip".equals(encoding, ignoreCase = true)) {
                rawStream = GZIPInputStream(rawStream)
            }

            val buffered = BufferedInputStream(rawStream)
            val bytes = readBytes(buffered)
            if (bytes.isEmpty()) {
                throw IllegalArgumentException("Downloaded 0 bytes for overlay: $urlString")
            }

            val isZip = isZipHeader(bytes) || urlString.substringBefore('?').lowercase().let {
                it.endsWith(".lottie") || it.endsWith(".zip") || it.endsWith(".dotlottie")
            }

            val stream = ByteArrayInputStream(bytes)
            val result = if (isZip) {
                LottieCompositionFactory.fromZipStreamSync(ZipInputStream(stream), cacheKey)
            } else {
                LottieCompositionFactory.fromJsonInputStreamSync(stream, cacheKey)
            }

            return result.value ?: throw (result.exception ?: IllegalStateException("Lottie parsing returned null composition"))
        } finally {
            try {
                connection?.disconnect()
            } catch (_: Throwable) {
            }
        }
    }

    private fun isZipHeader(bytes: ByteArray): Boolean {
        return bytes.size >= 4 &&
            bytes[0] == 0x50.toByte() && // 'P'
            bytes[1] == 0x4B.toByte() && // 'K'
            bytes[2] == 0x03.toByte() &&
            bytes[3] == 0x04.toByte()
    }

    private fun readBytes(stream: InputStream): ByteArray {
        val buffer = ByteArrayOutputStream()
        val data = ByteArray(8192)
        var count: Int
        while (stream.read(data, 0, data.size).also { count = it } != -1) {
            buffer.write(data, 0, count)
        }
        return buffer.toByteArray()
    }
}
