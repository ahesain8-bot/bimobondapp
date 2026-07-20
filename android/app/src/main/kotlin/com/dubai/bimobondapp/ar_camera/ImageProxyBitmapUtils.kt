package com.dubai.bimobondapp.ar_camera

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import androidx.camera.core.ImageProxy

object ImageProxyBitmapUtils {

    fun toBitmap(imageProxy: ImageProxy): Bitmap? {
        return when (imageProxy.format) {
            ImageFormat.JPEG -> jpegToBitmap(imageProxy)
            ImageFormat.YUV_420_888 -> yuv420888ToBitmap(imageProxy)
            else -> rgbaToBitmap(imageProxy)
        }
    }

    private fun jpegToBitmap(imageProxy: ImageProxy): Bitmap? {
        if (imageProxy.planes.isEmpty()) return null
        val buffer = imageProxy.planes[0].buffer
        val bytes = ByteArray(buffer.remaining())
        buffer.rewind()
        buffer.get(bytes)
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    private fun rgbaToBitmap(imageProxy: ImageProxy): Bitmap? {
        if (imageProxy.planes.isEmpty()) return null

        val plane = imageProxy.planes[0]
        val buffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        val width = imageProxy.width
        val height = imageProxy.height

        buffer.rewind()

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)

        // Fast path: tightly packed RGBA — a single native buffer copy.
        if (rowStride == pixelStride * width && pixelStride == 4) {
            bitmap.copyPixelsFromBuffer(buffer)
            return bitmap
        }

        // Padded RGBA (rowStride > width*4, common on many devices): copy row by row
        // into a tightly packed buffer with bulk gets, then one native upload. This
        // replaces the old per-pixel ByteBuffer.get() loop (4 reads + repack per
        // pixel = ~6M calls per 1080x1440 frame) that could dominate frame time and
        // stutter both preview and recording.
        if (pixelStride == 4) {
            val rowBytes = width * 4
            val packed = java.nio.ByteBuffer
                .allocateDirect(rowBytes * height)
                .order(java.nio.ByteOrder.nativeOrder())
            val rowBuf = ByteArray(rowBytes)
            for (row in 0 until height) {
                buffer.position(row * rowStride)
                buffer.get(rowBuf, 0, rowBytes)
                packed.put(rowBuf)
            }
            packed.rewind()
            bitmap.copyPixelsFromBuffer(packed)
            return bitmap
        }

        // Rare fallback: unusual pixel stride — general per-pixel repack.
        val pixels = IntArray(width * height)
        var outputIndex = 0
        for (row in 0 until height) {
            var inputIndex = row * rowStride
            for (col in 0 until width) {
                val r = buffer.get(inputIndex).toInt() and 0xFF
                val g = buffer.get(inputIndex + 1).toInt() and 0xFF
                val b = buffer.get(inputIndex + 2).toInt() and 0xFF
                val a = buffer.get(inputIndex + 3).toInt() and 0xFF
                pixels[outputIndex++] = (a shl 24) or (r shl 16) or (g shl 8) or b
                inputIndex += pixelStride
            }
        }
        bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
        return bitmap
    }

    private fun yuv420888ToBitmap(imageProxy: ImageProxy): Bitmap? {
        val nv21 = yuv420888ToNv21(imageProxy) ?: return null
        val width = imageProxy.width
        val height = imageProxy.height
        val argb = nv21ToArgb(nv21, width, height)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.setPixels(argb, 0, width, 0, 0, width, height)
        return bitmap
    }

    private fun nv21ToArgb(nv21: ByteArray, width: Int, height: Int): IntArray {
        val argb = IntArray(width * height)
        val frameSize = width * height
        var yp = 0
        for (j in 0 until height) {
            var uvp = frameSize + (j shr 1) * width
            var u = 0
            var v = 0
            for (i in 0 until width) {
                val y = (nv21[yp].toInt() and 0xFF) - 16
                if ((i and 1) == 0) {
                    v = (nv21[uvp++].toInt() and 0xFF) - 128
                    u = (nv21[uvp++].toInt() and 0xFF) - 128
                }
                val y1192 = 1192 * y
                var r = y1192 + 1634 * v
                var g = y1192 - 833 * v - 400 * u
                var b = y1192 + 2066 * u
                r = r.coerceIn(0, 262143)
                g = g.coerceIn(0, 262143)
                b = b.coerceIn(0, 262143)
                argb[yp] =
                    -0x1000000 or ((r shl 6) and 0xFF0000) or ((g shr 2) and 0xFF00) or ((b shr 10) and 0xFF)
                yp++
            }
        }
        return argb
    }

    private fun yuv420888ToNv21(imageProxy: ImageProxy): ByteArray? {
        if (imageProxy.planes.size < 3) return null

        val width = imageProxy.width
        val height = imageProxy.height
        val ySize = width * height
        val uvSize = width * height / 2
        val nv21 = ByteArray(ySize + uvSize)

        val yPlane = imageProxy.planes[0]
        val uPlane = imageProxy.planes[1]
        val vPlane = imageProxy.planes[2]

        val yBuffer = yPlane.buffer
        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer

        yBuffer.rewind()
        uBuffer.rewind()
        vBuffer.rewind()

        var outputIndex = 0
        val yRowStride = yPlane.rowStride
        val yPixelStride = yPlane.pixelStride
        for (row in 0 until height) {
            var inputIndex = row * yRowStride
            for (col in 0 until width) {
                nv21[outputIndex++] = yBuffer.get(inputIndex)
                inputIndex += yPixelStride
            }
        }

        val uvRowStride = uPlane.rowStride
        val uvPixelStride = uPlane.pixelStride
        val uvHeight = height / 2
        val uvWidth = width / 2
        var uvIndex = ySize

        for (row in 0 until uvHeight) {
            var inputIndex = row * uvRowStride
            for (col in 0 until uvWidth) {
                nv21[uvIndex++] = vBuffer.get(inputIndex)
                nv21[uvIndex++] = uBuffer.get(inputIndex)
                inputIndex += uvPixelStride
            }
        }

        return nv21
    }

    fun rotate(bitmap: Bitmap, rotationDegrees: Int): Bitmap {
        if (rotationDegrees == 0) return bitmap
        val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, false)
    }

    /**
     * Applies rotation and (optionally) a horizontal mirror in a SINGLE matrix pass,
     * producing `mirror(rotate(src))`. This replaces the previous rotate-then-mirror
     * sequence (two full-frame allocations + copies) with one, which is a real
     * per-frame saving on the analysis thread while recording. Only use this when the
     * unmirrored `oriented` frame is NOT needed separately (e.g. no face detection),
     * since detection must run on the un-mirrored image.
     */
    fun orient(bitmap: Bitmap, rotationDegrees: Int, mirror: Boolean): Bitmap {
        if (rotationDegrees == 0 && !mirror) return bitmap
        val matrix = Matrix()
        if (rotationDegrees != 0) matrix.postRotate(rotationDegrees.toFloat())
        if (mirror) matrix.postScale(-1f, 1f)
        // These are all axis-aligned transforms (90°/180°/270° + horizontal flip) so
        // bilinear filtering can't change the output; keep it off when we're only
        // rotating (cheaper, matches the old `rotate`) and on when mirroring (matches
        // the old `mirrorHorizontally`).
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, mirror)
    }

    /**
     * Rotate + (optional) mirror + downscale-to-[maxEdge] in a SINGLE matrix pass.
     * Produces `scale(mirror(rotate(src)))`. This collapses what used to be three
     * separate full-frame allocations (rotate, mirror, scale) into one, which is a
     * big reduction in per-frame garbage — fewer/shorter GC pauses mean a smoother
     * preview AND more even encoder frame timing. Only use when no un-mirrored /
     * full-resolution frame is needed separately (i.e. no face detection).
     */
    fun orientScaled(
        bitmap: Bitmap,
        rotationDegrees: Int,
        mirror: Boolean,
        maxEdge: Int,
    ): Bitmap {
        val largest = maxOf(bitmap.width, bitmap.height)
        val scale = if (largest > maxEdge && maxEdge > 0) maxEdge.toFloat() / largest else 1f
        if (rotationDegrees == 0 && !mirror && scale == 1f) return bitmap
        val matrix = Matrix()
        if (rotationDegrees != 0) matrix.postRotate(rotationDegrees.toFloat())
        if (mirror) matrix.postScale(-1f, 1f)
        if (scale != 1f) matrix.postScale(scale, scale)
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    fun mirrorHorizontally(bitmap: Bitmap): Bitmap {
        val matrix = Matrix().apply {
            preScale(-1f, 1f, bitmap.width / 2f, bitmap.height / 2f)
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    fun toUprightCapture(imageProxy: ImageProxy, mirrorFront: Boolean): Bitmap? {
        val raw = toBitmap(imageProxy) ?: return null
        val rotation = imageProxy.imageInfo.rotationDegrees
        val oriented = rotate(raw, rotation)
        if (oriented !== raw) raw.recycle()
        if (!mirrorFront) return oriented
        val mirrored = mirrorHorizontally(oriented)
        if (mirrored !== oriented) oriented.recycle()
        return mirrored
    }

    fun scaleToMaxDimension(bitmap: Bitmap, maxDimension: Int, filter: Boolean = false): Bitmap {
        val largest = maxOf(bitmap.width, bitmap.height)
        if (largest <= maxDimension) return bitmap

        val scale = maxDimension.toFloat() / largest
        val targetWidth = (bitmap.width * scale).toInt().coerceAtLeast(1)
        val targetHeight = (bitmap.height * scale).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, filter)
    }

    /**
     * Crops [bitmap] to the FILL_CENTER region shown in a viewport of [viewW]x[viewH]
     * (same mapping as PreviewView.ScaleType.FILL_CENTER).
     */
    fun cropFillCenterToViewport(bitmap: Bitmap, viewW: Int, viewH: Int): Bitmap {
        if (viewW <= 0 || viewH <= 0) return bitmap
        val imgW = bitmap.width.toFloat()
        val imgH = bitmap.height.toFloat()
        if (imgW <= 0f || imgH <= 0f) return bitmap

        val scale = maxOf(viewW / imgW, viewH / imgH)
        val displayW = imgW * scale
        val displayH = imgH * scale
        val offsetX = (viewW - displayW) / 2f
        val offsetY = (viewH - displayH) / 2f

        var left = ((0f - offsetX) / scale).toInt()
        var top = ((0f - offsetY) / scale).toInt()
        var right = ((viewW - offsetX) / scale).toInt()
        var bottom = ((viewH - offsetY) / scale).toInt()

        left = left.coerceIn(0, bitmap.width - 1)
        top = top.coerceIn(0, bitmap.height - 1)
        right = right.coerceIn(left + 1, bitmap.width)
        bottom = bottom.coerceIn(top + 1, bitmap.height)

        if (left == 0 && top == 0 && right == bitmap.width && bottom == bitmap.height) {
            return bitmap
        }
        return Bitmap.createBitmap(bitmap, left, top, right - left, bottom - top)
    }

    /**
     * WYSIWYG letterbox: full [outW]x[outH] canvas with black bars and the same
     * FILL_CENTER camera content TikTok shows in the mid band.
     */
    fun composeLetterboxedCapture(
        source: Bitmap,
        outW: Int,
        outH: Int,
        topBarPx: Int,
        bottomBarPx: Int,
    ): Bitmap {
        val top = topBarPx.coerceAtLeast(0)
        val bottom = bottomBarPx.coerceAtLeast(0)
        val midH = (outH - top - bottom).coerceAtLeast(1)
        val mid = cropFillCenterToViewport(source, outW, midH)
        val out = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(out)
        canvas.drawColor(android.graphics.Color.BLACK)
        val paint = android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG)
        val dst = android.graphics.Rect(0, top, outW, top + midH)
        canvas.drawBitmap(
            mid,
            android.graphics.Rect(0, 0, mid.width, mid.height),
            dst,
            paint,
        )
        if (mid !== source && !mid.isRecycled) {
            mid.recycle()
        }
        return out
    }
}
