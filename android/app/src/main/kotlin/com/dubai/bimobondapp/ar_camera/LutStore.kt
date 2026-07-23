package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.net.HttpURLConnection
import java.net.URL

object LutStore {

    private const val DIM = 512
    private const val TILES = 8
    private const val LEVELS = 64

    private const val ASSET_PREFIX = "flutter_assets/assets/luts/"

    private val bitmapCache = HashMap<String, Bitmap?>()
    private val pixelCache = HashMap<String, IntArray?>()

    @Synchronized
    fun bitmap(context: Context, asset: String): Bitmap? {
        if (bitmapCache.containsKey(asset)) return bitmapCache[asset]
        val loaded = try {
            context.assets.open(ASSET_PREFIX + asset).use { input ->
                BitmapFactory.decodeStream(input)?.let {
                    if (it.config == Bitmap.Config.ARGB_8888) it
                    else it.copy(Bitmap.Config.ARGB_8888, false)
                }
            }
        } catch (_: Throwable) {
            null
        }
        bitmapCache[asset] = loaded
        return loaded
    }

    /** Downloads a 512×512 LUT PNG from [url] (cached by URL). */
    @Synchronized
    fun bitmapFromUrl(url: String): Bitmap? {
        val key = url.trim()
        if (key.isEmpty()) return null
        if (bitmapCache.containsKey(key)) return bitmapCache[key]
        val loaded = try {
            val conn = (URL(key).openConnection() as HttpURLConnection).apply {
                connectTimeout = 10_000
                readTimeout = 15_000
                instanceFollowRedirects = true
            }
            conn.inputStream.use { input ->
                BitmapFactory.decodeStream(input)?.let {
                    if (it.config == Bitmap.Config.ARGB_8888) it
                    else it.copy(Bitmap.Config.ARGB_8888, false)
                }
            }
        } catch (_: Throwable) {
            null
        }
        bitmapCache[key] = loaded
        return loaded
    }

    @Synchronized
    private fun pixels(context: Context, asset: String): IntArray? {
        if (pixelCache.containsKey(asset)) return pixelCache[asset]
        val bmp = bitmap(context, asset)
        val out = pixelsFromBitmap(bmp)
        pixelCache[asset] = out
        return out
    }

    @Synchronized
    private fun pixelsFromUrl(url: String): IntArray? {
        val key = "px:$url"
        if (pixelCache.containsKey(key)) return pixelCache[key]
        val out = pixelsFromBitmap(bitmapFromUrl(url))
        pixelCache[key] = out
        return out
    }

    private fun pixelsFromBitmap(bmp: Bitmap?): IntArray? {
        return if (bmp != null && bmp.width == DIM && bmp.height == DIM) {
            IntArray(DIM * DIM).also { bmp.getPixels(it, 0, DIM, 0, 0, DIM, DIM) }
        } else {
            null
        }
    }

    fun apply(
        context: Context,
        source: Bitmap,
        asset: String,
        intensity: Float,
    ): Bitmap {
        val t = intensity.coerceIn(0f, 1f)
        if (t <= 0.001f || source.isRecycled) return source
        val lut = pixels(context, asset) ?: return source
        return applyPixels(source, lut, t)
    }

    fun applyFromUrl(
        source: Bitmap,
        url: String,
        intensity: Float,
    ): Bitmap {
        val t = intensity.coerceIn(0f, 1f)
        if (t <= 0.001f || source.isRecycled) return source
        val lut = pixelsFromUrl(url) ?: return source
        return applyPixels(source, lut, t)
    }

    private fun applyPixels(source: Bitmap, lut: IntArray, t: Float): Bitmap {
        val w = source.width
        val h = source.height
        val px = IntArray(w * h)
        source.getPixels(px, 0, w, 0, 0, w, h)

        for (i in px.indices) {
            val c = px[i]
            val a = c ushr 24 and 0xFF
            val r = (c ushr 16 and 0xFF) / 255f
            val g = (c ushr 8 and 0xFF) / 255f
            val b = (c and 0xFF) / 255f

            val graded = sample(lut, r, g, b)
            var nr = (graded ushr 16 and 0xFF)
            var ng = (graded ushr 8 and 0xFF)
            var nb = (graded and 0xFF)

            if (t < 0.999f) {
                nr = ((c ushr 16 and 0xFF) + (nr - (c ushr 16 and 0xFF)) * t).toInt()
                ng = ((c ushr 8 and 0xFF) + (ng - (c ushr 8 and 0xFF)) * t).toInt()
                nb = ((c and 0xFF) + (nb - (c and 0xFF)) * t).toInt()
            }

            px[i] = (a shl 24) or (nr.coerceIn(0, 255) shl 16) or
                (ng.coerceIn(0, 255) shl 8) or nb.coerceIn(0, 255)
        }

        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        out.setPixels(px, 0, w, 0, 0, w, h)
        return out
    }

    private fun sample(lut: IntArray, r: Float, g: Float, b: Float): Int {
        val rr = r.coerceIn(0f, 1f)
        val gg = g.coerceIn(0f, 1f)
        val bb = b.coerceIn(0f, 1f)

        val blue = bb * (LEVELS - 1)
        val b0 = blue.toInt().coerceIn(0, LEVELS - 1)
        val b1 = (b0 + 1).coerceIn(0, LEVELS - 1)
        val bf = blue - b0

        val c0 = sliceSample(lut, b0, rr, gg)
        if (bf <= 0.0001f) return c0
        val c1 = sliceSample(lut, b1, rr, gg)

        val r0 = c0 ushr 16 and 0xFF; val r1 = c1 ushr 16 and 0xFF
        val g0 = c0 ushr 8 and 0xFF; val g1 = c1 ushr 8 and 0xFF
        val bl0 = c0 and 0xFF; val bl1 = c1 and 0xFF
        val nr = (r0 + (r1 - r0) * bf).toInt().coerceIn(0, 255)
        val ng = (g0 + (g1 - g0) * bf).toInt().coerceIn(0, 255)
        val nb = (bl0 + (bl1 - bl0) * bf).toInt().coerceIn(0, 255)
        return (nr shl 16) or (ng shl 8) or nb
    }

    private fun sliceSample(lut: IntArray, slice: Int, r: Float, g: Float): Int {
        val tileX = slice % TILES
        val tileY = slice / TILES
        val fx = tileX * LEVELS + r * (LEVELS - 1)
        val fy = tileY * LEVELS + g * (LEVELS - 1)

        val x0 = fx.toInt().coerceIn(0, DIM - 1)
        val y0 = fy.toInt().coerceIn(0, DIM - 1)
        val x1 = (x0 + 1).coerceAtMost((tileX + 1) * LEVELS - 1).coerceIn(0, DIM - 1)
        val y1 = (y0 + 1).coerceAtMost((tileY + 1) * LEVELS - 1).coerceIn(0, DIM - 1)
        val ax = fx - x0
        val ay = fy - y0

        val c00 = lut[y0 * DIM + x0]
        val c10 = lut[y0 * DIM + x1]
        val c01 = lut[y1 * DIM + x0]
        val c11 = lut[y1 * DIM + x1]

        val r0 = lerp(c00 ushr 16 and 0xFF, c10 ushr 16 and 0xFF, ax)
        val r1 = lerp(c01 ushr 16 and 0xFF, c11 ushr 16 and 0xFF, ax)
        val g0 = lerp(c00 ushr 8 and 0xFF, c10 ushr 8 and 0xFF, ax)
        val g1 = lerp(c01 ushr 8 and 0xFF, c11 ushr 8 and 0xFF, ax)
        val b0 = lerp(c00 and 0xFF, c10 and 0xFF, ax)
        val b1 = lerp(c01 and 0xFF, c11 and 0xFF, ax)

        val nr = lerp2(r0, r1, ay)
        val ng = lerp2(g0, g1, ay)
        val nb = lerp2(b0, b1, ay)
        return (nr shl 16) or (ng shl 8) or nb
    }

    private fun lerp(a: Int, b: Int, t: Float): Float = a + (b - a) * t
    private fun lerp2(a: Float, b: Float, t: Float): Int =
        (a + (b - a) * t).toInt().coerceIn(0, 255)
}
