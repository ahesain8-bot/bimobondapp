package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.Matrix
import android.media.ExifInterface
import android.util.Log
import com.dubai.bimobondapp.beauty.BeautyFilterProcessor
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import org.opencv.android.Utils
import org.opencv.core.Core
import org.opencv.core.Mat
import org.opencv.imgproc.Imgproc
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Still-image Soft Glow bake (gallery / media studio).
 * Uses IMAGE-mode MediaPipe (sync) so lips/blush actually apply.
 */
object SoftGlowBaker {

    private const val TAG = "SoftGlowBaker"
    private const val MODEL_ASSET = "face_landmarker.task"

    private val landmarkerRef = AtomicReference<FaceLandmarker?>(null)
    private val landmarkerLock = Any()

    fun applyToFile(
        context: Context,
        inputPath: String,
        intensity: Float,
        maxEdge: Int? = null,
        smooth: Float = BeautyPresetState.smooth,
        whiten: Float = BeautyPresetState.whiten,
        brighten: Float = BeautyPresetState.brighten,
        blush: Float = BeautyPresetState.blush,
        lipTintHex: String? = null,
        lipStrength: Float = BeautyPresetState.lipStrength,
    ): String? {
        val t = intensity.coerceIn(0f, 1f)
        if (t <= 0.001f) return null
        if (!BeautyFilterProcessor.ensureOpenCv()) return null

        val decoded = decodeOrientedBitmap(inputPath) ?: return null
        var source = decoded
        try {
            if (maxEdge != null && maxEdge > 0) {
                source = downscale(decoded, maxEdge)
            }
            val tint = parseHex(lipTintHex)
            val outBmp = process(
                context = context.applicationContext,
                src = source,
                intensity = t,
                smooth = smooth.coerceIn(0f, 1f),
                whiten = whiten.coerceIn(0f, 1f),
                brighten = brighten.coerceIn(0f, 1f),
                blush = blush.coerceIn(0f, 1f),
                lipR = tint[0],
                lipG = tint[1],
                lipB = tint[2],
                lipStrength = lipStrength.coerceIn(0f, 1f),
            )
            val out = File(context.cacheDir, "soft_glow_${System.currentTimeMillis()}.jpg")
            FileOutputStream(out).use { stream ->
                outBmp.compress(Bitmap.CompressFormat.JPEG, 95, stream)
            }
            if (outBmp !== source && !outBmp.isRecycled) outBmp.recycle()
            return out.absolutePath
        } catch (t: Throwable) {
            Log.e(TAG, "applyToFile failed", t)
            return null
        } finally {
            if (source !== decoded && !source.isRecycled) source.recycle()
            if (!decoded.isRecycled) decoded.recycle()
        }
    }

    private fun process(
        context: Context,
        src: Bitmap,
        intensity: Float,
        smooth: Float,
        whiten: Float,
        brighten: Float,
        blush: Float,
        lipR: Float,
        lipG: Float,
        lipB: Float,
        lipStrength: Float,
    ): Bitmap {
        val rgba = Mat()
        val bgr = Mat()
        val blurred = Mat()
        try {
            Utils.bitmapToMat(src, rgba)
            Imgproc.cvtColor(rgba, bgr, Imgproc.COLOR_RGBA2BGR)

            // Stronger skin smooth (noticeable on still photos).
            val sm = (smooth * intensity).coerceIn(0f, 1f)
            if (sm > 0.02f) {
                val k = (max(5, (sm * 28).roundToInt()) or 1).coerceAtMost(15)
                Imgproc.bilateralFilter(bgr, blurred, k, 40.0 + sm * 80.0, 40.0 + sm * 80.0)
                Core.addWeighted(blurred, sm.toDouble(), bgr, 1.0 - sm, 0.0, bgr)
            }

            // Whiten (neutral) + brighten — avoid pink cast.
            val w = (whiten * intensity).coerceIn(0f, 1f)
            val br = (brighten * intensity).coerceIn(0f, 1f)
            if (w > 0.01f || br > 0.01f) {
                bgr.convertTo(bgr, -1, 1.0 + br * 0.16, br * 14.0)
                if (w > 0.01f) {
                    val lab = Mat()
                    Imgproc.cvtColor(bgr, lab, Imgproc.COLOR_BGR2Lab)
                    val ch = ArrayList<Mat>(3)
                    Core.split(lab, ch)
                    ch[0].convertTo(ch[0], -1, 1.0, w * 16.0)
                    ch[1].convertTo(ch[1], -1, 1.0 - w * 0.12, 128.0 * w * 0.12)
                    ch[2].convertTo(ch[2], -1, 1.0 - w * 0.12, 128.0 * w * 0.12)
                    Core.merge(ch, lab)
                    Imgproc.cvtColor(lab, bgr, Imgproc.COLOR_Lab2BGR)
                    lab.release()
                    ch.forEach { it.release() }
                }
            }

            Imgproc.cvtColor(bgr, rgba, Imgproc.COLOR_BGR2RGBA)
            val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
            Utils.matToBitmap(rgba, out)

            val landmarks = detectLandmarksImage(context, src)
            Log.i(TAG, "landmarks=${landmarks?.size ?: 0} size=${src.width}x${src.height}")
            if (landmarks != null && landmarks.size >= 468) {
                val canvas = Canvas(out)
                val bl = (blush * intensity).coerceIn(0f, 1f)
                if (bl > 0.01f) {
                    drawCheekBlush(canvas, landmarks, src.width, src.height, bl)
                }
                val ls = (lipStrength * intensity).coerceIn(0f, 1f)
                if (ls > 0.01f) {
                    drawLipTint(canvas, landmarks, ls, lipR, lipG, lipB)
                }
            }
            return out
        } finally {
            rgba.release()
            bgr.release()
            blurred.release()
        }
    }

    private fun detectLandmarksImage(context: Context, bitmap: Bitmap): List<PointF>? {
        synchronized(landmarkerLock) {
            val landmarker = landmarkerRef.get() ?: createImageLandmarker(context).also {
                landmarkerRef.set(it)
            }
            return try {
                val mpImage = BitmapImageBuilder(bitmap).build()
                val result = landmarker.detect(mpImage)
                val list = result.faceLandmarks().firstOrNull() ?: return null
                if (list.size < 468) return null
                list.map { PointF(it.x() * bitmap.width, it.y() * bitmap.height) }
            } catch (t: Throwable) {
                Log.w(TAG, "face detect failed", t)
                null
            }
        }
    }

    private fun createImageLandmarker(context: Context): FaceLandmarker {
        val base = BaseOptions.builder()
            .setDelegate(Delegate.CPU)
            .setModelAssetPath(MODEL_ASSET)
            .build()
        val options = FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(base)
            .setRunningMode(RunningMode.IMAGE)
            .setNumFaces(1)
            .setMinFaceDetectionConfidence(0.4f)
            .setMinFacePresenceConfidence(0.4f)
            .build()
        return FaceLandmarker.createFromOptions(context.applicationContext, options)
    }

    private fun drawCheekBlush(
        canvas: Canvas,
        landmarks: List<PointF>,
        w: Int,
        h: Int,
        amount: Float,
    ) {
        val left = landmarks.getOrNull(MediaPipeLandmarkIndices.LEFT_CHEEK) ?: return
        val right = landmarks.getOrNull(MediaPipeLandmarkIndices.RIGHT_CHEEK) ?: return
        val faceW = (right.x - left.x).coerceAtLeast(w * 0.2f)
        val radius = faceW * 0.42f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_OVER)
        }
        // Soft natural blush (not lip tint).
        val a = (amount * 90).roundToInt().coerceIn(0, 140)
        fun stamp(c: PointF) {
            paint.shader = RadialGradient(
                c.x,
                c.y,
                radius,
                Color.argb(a, 232, 100, 120),
                Color.TRANSPARENT,
                Shader.TileMode.CLAMP,
            )
            canvas.drawCircle(c.x, c.y, radius, paint)
        }
        stamp(left)
        stamp(right)
        paint.shader = null
    }

    private fun drawLipTint(
        canvas: Canvas,
        landmarks: List<PointF>,
        amount: Float,
        r: Float,
        g: Float,
        b: Float,
    ) {
        val path = Path()
        var started = false
        val ring = MediaPipeLandmarkIndices.LIPS_OUTER
        if (ring.isNotEmpty()) {
            for (idx in ring) {
                val p = landmarks.getOrNull(idx) ?: continue
                if (!started) {
                    path.moveTo(p.x, p.y)
                    started = true
                } else {
                    path.lineTo(p.x, p.y)
                }
            }
        } else {
            for (idx in MediaPipeLandmarkIndices.UPPER_LIP) {
                val p = landmarks.getOrNull(idx) ?: continue
                if (!started) {
                    path.moveTo(p.x, p.y)
                    started = true
                } else {
                    path.lineTo(p.x, p.y)
                }
            }
            for (i in MediaPipeLandmarkIndices.LOWER_LIP.indices.reversed()) {
                val p = landmarks.getOrNull(MediaPipeLandmarkIndices.LOWER_LIP[i]) ?: continue
                path.lineTo(p.x, p.y)
            }
        }
        if (!started) return
        path.close()

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            isAntiAlias = true
            color = Color.argb(
                (amount * 150).roundToInt().coerceIn(70, 190),
                (r * 255).roundToInt().coerceIn(0, 255),
                (g * 255).roundToInt().coerceIn(0, 255),
                (b * 255).roundToInt().coerceIn(0, 255),
            )
            xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_OVER)
        }
        canvas.drawPath(path, paint)
    }

    private fun parseHex(hex: String?): FloatArray {
        val raw = hex?.trim().orEmpty()
        val h = if (raw.startsWith("#")) raw.substring(1) else raw
        if (h.length != 6) {
            return floatArrayOf(0xE8 / 255f, 0x52 / 255f, 0x7A / 255f)
        }
        return try {
            floatArrayOf(
                h.substring(0, 2).toInt(16) / 255f,
                h.substring(2, 4).toInt(16) / 255f,
                h.substring(4, 6).toInt(16) / 255f,
            )
        } catch (_: Throwable) {
            floatArrayOf(0xE8 / 255f, 0x52 / 255f, 0x7A / 255f)
        }
    }

    private fun downscale(src: Bitmap, maxEdge: Int): Bitmap {
        val longest = max(src.width, src.height)
        if (longest <= maxEdge) return src
        val scale = maxEdge.toFloat() / longest
        val m = Matrix().apply { postScale(scale, scale) }
        return Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
    }

    private fun decodeOrientedBitmap(path: String): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        val bmp = BitmapFactory.decodeFile(path) ?: return null
        return try {
            val exif = ExifInterface(path)
            val orient = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
            val degrees = when (orient) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
            if (degrees == 0f) bmp
            else {
                val m = Matrix().apply { postRotate(degrees) }
                val rotated = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
                if (rotated !== bmp) bmp.recycle()
                rotated
            }
        } catch (_: Throwable) {
            bmp
        }
    }
}
