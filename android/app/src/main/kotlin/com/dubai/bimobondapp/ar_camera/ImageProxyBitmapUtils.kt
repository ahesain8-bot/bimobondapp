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
        if (rowStride == pixelStride * width && pixelStride == 4) {
            bitmap.copyPixelsFromBuffer(buffer)
            return bitmap
        }

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

    fun mirrorHorizontally(bitmap: Bitmap): Bitmap {
        val matrix = Matrix().apply {
            preScale(-1f, 1f, bitmap.width / 2f, bitmap.height / 2f)
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    /** Upright selfie bitmap matching the mirrored front-camera preview. */
    fun toUprightMirroredSelfie(imageProxy: ImageProxy): Bitmap? {
        val raw = toBitmap(imageProxy) ?: return null
        val rotation = imageProxy.imageInfo.rotationDegrees
        val oriented = rotate(raw, rotation)
        if (oriented !== raw) raw.recycle()
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
}
