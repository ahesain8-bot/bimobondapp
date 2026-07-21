package com.dubai.bimobondapp.beauty

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.PointF
import android.media.ExifInterface
import android.util.Log
import com.dubai.bimobondapp.ar_camera.MediaPipeLandmarkIndices
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Scalar
import org.opencv.imgproc.Imgproc
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Still-image tone/color adjustments + nose reshape via OpenCV (whole image).
 *
 * Saturation, Brightness, Contrast, Exposure, White balance, Highlights, Shadows,
 * and Nose width (slim / widen). All levels are -100..100 (0 = original).
 */
object BeautyFilterProcessor {

    private const val TAG = "BeautyFilterProcessor"
    private const val MODEL_ASSET = "face_landmarker.task"

    private val openCvReady = AtomicBoolean(false)
    private val initLock = Any()
    private val landmarkerLock = Any()

    @Volatile
    private var imageLandmarker: FaceLandmarker? = null

    fun ensureOpenCv(): Boolean {
        if (openCvReady.get()) return true
        synchronized(initLock) {
            if (openCvReady.get()) return true
            val ok = try {
                OpenCVLoader.initLocal()
            } catch (t: Throwable) {
                Log.e(TAG, "OpenCV init failed", t)
                false
            }
            if (ok) {
                openCvReady.set(true)
                Log.i(TAG, "OpenCV loaded")
            }
            return ok
        }
    }

    /** All slider levels, -100..100 (0 = original). */
    data class Adjustments(
        val saturation: Int = 0,
        val brightness: Int = 0,
        val contrast: Int = 0,
        val exposure: Int = 0,
        val whiteBalance: Int = 0,
        val highlights: Int = 0,
        val shadows: Int = 0,
        val nose: Int = 0,
    ) {
        val hasColor get() = saturation != 0 || brightness != 0 || contrast != 0 ||
            exposure != 0 || whiteBalance != 0 || highlights != 0 || shadows != 0
        val isNoop get() = !hasColor && nose == 0
    }

    fun apply(
        context: Context,
        inputPath: String,
        adjustments: Adjustments,
        maxEdge: Int? = null,
    ): String? {
        if (adjustments.isNoop) return null
        if (!ensureOpenCv()) {
            Log.e(TAG, "OpenCV not ready")
            return null
        }

        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            Log.e(TAG, "Input missing: $inputPath")
            return null
        }

        var bitmap = decodeOrientedBitmap(inputPath) ?: run {
            Log.e(TAG, "Decode failed: $inputPath")
            return null
        }
        try {
            // Live preview may pass maxEdge for speed; export omits it (full-res).
            if (maxEdge != null && maxEdge > 0) {
                bitmap = downscaleIfNeeded(bitmap, maxEdge)
            }

            Log.i(TAG, "apply $adjustments size=${bitmap.width}x${bitmap.height}")
            val resultBmp = processBitmap(context, bitmap, adjustments)
            val outFile = File(
                context.cacheDir,
                "beauty_${System.currentTimeMillis()}.jpg",
            )
            FileOutputStream(outFile).use { fos ->
                resultBmp.compress(Bitmap.CompressFormat.JPEG, 95, fos)
            }
            if (resultBmp !== bitmap) resultBmp.recycle()
            Log.i(TAG, "Wrote ${outFile.absolutePath}")
            return outFile.absolutePath
        } catch (t: Throwable) {
            Log.e(TAG, "apply failed", t)
            throw t
        } finally {
            if (!bitmap.isRecycled) bitmap.recycle()
        }
    }

    private fun downscaleIfNeeded(src: Bitmap, maxEdge: Int): Bitmap {
        val longest = max(src.width, src.height)
        if (longest <= maxEdge) return src
        val scale = maxEdge.toFloat() / longest
        val w = max(1, (src.width * scale).roundToInt())
        val h = max(1, (src.height * scale).roundToInt())
        val scaled = Bitmap.createScaledBitmap(src, w, h, true)
        if (scaled !== src) src.recycle()
        return scaled
    }

    private fun processBitmap(context: Context, srcBmp: Bitmap, adj: Adjustments): Bitmap {
        val rgba = Mat()
        val bgr = Mat()
        try {
            Utils.bitmapToMat(srcBmp, rgba)
            Imgproc.cvtColor(rgba, bgr, Imgproc.COLOR_RGBA2BGR)

            // Nose reshape (geometry) runs first, before color grading.
            if (adj.nose != 0) {
                val landmarks = try {
                    detectLandmarks(context, srcBmp)
                } catch (t: Throwable) {
                    Log.w(TAG, "Face detect skipped", t)
                    null
                }
                if (landmarks != null) {
                    applyNoseReshape(bgr, landmarks, adj.nose / 100f)
                }
            }

            // Global tone/color adjustments (whole image). Order matters:
            // exposure → white balance → contrast → brightness → highlights/shadows → saturation.
            applyGlobalAdjustments(bgr, adj)

            Imgproc.cvtColor(bgr, rgba, Imgproc.COLOR_BGR2RGBA)
            val out = Bitmap.createBitmap(srcBmp.width, srcBmp.height, Bitmap.Config.ARGB_8888)
            Utils.matToBitmap(rgba, out)
            return out
        } finally {
            rgba.release()
            bgr.release()
        }
    }

    /**
     * Global tone/color pipeline. Each slider level is -100..100 (0 = original).
     * Runs in-place on [bgr].
     */
    private fun applyGlobalAdjustments(bgr: Mat, adj: Adjustments) {
        // Exposure: multiply in stops (2^ev). -1 → -1 stop, +1 → +1 stop.
        // convertTo uses saturate_cast (clamps 0..255) — no abs() flipping.
        val ev = adj.exposure / 100f
        if (kotlin.math.abs(ev) > 0.01f) {
            val factor = Math.pow(2.0, ev.toDouble())
            bgr.convertTo(bgr, -1, factor, 0.0)
        }

        // White balance (temperature): + = warmer (more red, less blue).
        val wb = adj.whiteBalance / 100f
        if (kotlin.math.abs(wb) > 0.01f) {
            applyWhiteBalance(bgr, wb)
        }

        // Contrast: pivot around mid-gray (128). -1 → 0.5x, +1 → 1.5x.
        val c = adj.contrast / 100f
        if (kotlin.math.abs(c) > 0.01f) {
            val alpha = 1.0 + c * 0.5
            bgr.convertTo(bgr, -1, alpha, 128.0 * (1.0 - alpha))
        }

        // Brightness: linear offset. -1 → -60, +1 → +60.
        val b = adj.brightness / 100f
        if (kotlin.math.abs(b) > 0.01f) {
            bgr.convertTo(bgr, -1, 1.0, b * 60.0)
        }

        // Highlights / shadows: region-weighted lift on the L channel.
        val hl = adj.highlights / 100f
        val sh = adj.shadows / 100f
        if (kotlin.math.abs(hl) > 0.01f || kotlin.math.abs(sh) > 0.01f) {
            applyToneRegions(bgr, hl, sh)
        }

        // Saturation last so color scales the final tones.
        val sat = adj.saturation / 100f
        if (kotlin.math.abs(sat) > 0.01f) {
            applySaturation(bgr, bgr, sat)
        }
    }

    /**
     * Saturation slider: -1…+1
     *  0 = original
     * + = stronger colors
     * − = toward black & white
     */
    private fun applySaturation(src: Mat, dst: Mat, t: Float) {
        val amount = t.coerceIn(-1f, 1f)
        if (kotlin.math.abs(amount) <= 0.01f) {
            if (src !== dst) src.copyTo(dst)
            return
        }

        val hsv = Mat()
        val channels = ArrayList<Mat>(3)
        val sF = Mat()
        try {
            Imgproc.cvtColor(src, hsv, Imgproc.COLOR_BGR2HSV)
            Core.split(hsv, channels)
            val s = channels[1]

            // +1 → ~1.85x color; -1 → 0 (grayscale)
            val factor = if (amount >= 0f) {
                1.0 + amount * 0.85
            } else {
                (1.0 + amount).coerceAtLeast(0.0)
            }
            s.convertTo(sF, CvType.CV_32FC1)
            Core.multiply(sF, Scalar(factor), sF)
            Core.min(sF, Scalar(255.0), sF)
            val zero = Mat.zeros(sF.size(), CvType.CV_32FC1)
            Core.max(sF, zero, sF)
            zero.release()
            sF.convertTo(s, CvType.CV_8UC1)

            Core.merge(channels, hsv)
            if (src === dst) {
                val out = Mat()
                Imgproc.cvtColor(hsv, out, Imgproc.COLOR_HSV2BGR)
                out.copyTo(dst)
                out.release()
            } else {
                Imgproc.cvtColor(hsv, dst, Imgproc.COLOR_HSV2BGR)
            }
        } finally {
            hsv.release()
            channels.forEach { it.release() }
            sF.release()
        }
    }

    /** Temperature-style white balance. amount>0 = warmer. In-place. */
    private fun applyWhiteBalance(bgr: Mat, amount: Float) {
        val k = amount.toDouble() * 0.3
        val channels = ArrayList<Mat>(3)
        try {
            Core.split(bgr, channels) // BGR: 0=B, 1=G, 2=R
            channels[2].convertTo(channels[2], -1, 1.0 + k, 0.0)
            channels[0].convertTo(channels[0], -1, 1.0 - k, 0.0)
            Core.merge(channels, bgr)
        } finally {
            channels.forEach { it.release() }
        }
    }

    /**
     * Highlights & shadows recovery/lift using luminance-weighted curves on the
     * LAB L channel. highlights: + brightens bright areas, − recovers them.
     * shadows: + lifts dark areas, − deepens them. In-place on [bgr].
     */
    private fun applyToneRegions(bgr: Mat, highlights: Float, shadows: Float) {
        val lab = Mat()
        val channels = ArrayList<Mat>(3)
        val lf = Mat()
        val hlWeight = Mat()
        val shWeight = Mat()
        val delta = Mat()
        val tmp = Mat()
        try {
            Imgproc.cvtColor(bgr, lab, Imgproc.COLOR_BGR2Lab)
            Core.split(lab, channels)
            val l = channels[0]

            // Normalized luminance 0..1
            l.convertTo(lf, CvType.CV_32FC1, 1.0 / 255.0)

            // highlight weight = lf^2 (emphasize bright), shadow weight = (1-lf)^2
            Core.multiply(lf, lf, hlWeight)
            // tmp = 1 - lf  (Core has no Scalar - Mat overload, so negate then add)
            Core.multiply(lf, Scalar(-1.0), tmp)
            Core.add(tmp, Scalar(1.0), tmp)
            Core.multiply(tmp, tmp, shWeight)

            val scale = 70.0 // max L shift at full slider
            // delta = highlights*scale*hlWeight + shadows*scale*shWeight
            delta.create(lf.size(), CvType.CV_32FC1)
            delta.setTo(Scalar(0.0))
            if (kotlin.math.abs(highlights) > 0.01f) {
                Core.addWeighted(delta, 1.0, hlWeight, highlights.toDouble() * scale, 0.0, delta)
            }
            if (kotlin.math.abs(shadows) > 0.01f) {
                Core.addWeighted(delta, 1.0, shWeight, shadows.toDouble() * scale, 0.0, delta)
            }

            // L(float) + delta, clamp 0..255
            l.convertTo(tmp, CvType.CV_32FC1)
            Core.add(tmp, delta, tmp)
            Core.min(tmp, Scalar(255.0), tmp)
            Core.max(tmp, Scalar(0.0), tmp)
            tmp.convertTo(l, CvType.CV_8UC1)

            Core.merge(channels, lab)
            Imgproc.cvtColor(lab, bgr, Imgproc.COLOR_Lab2BGR)
        } finally {
            lab.release()
            channels.forEach { it.release() }
            lf.release()
            hlWeight.release()
            shWeight.release()
            delta.release()
            tmp.release()
        }
    }

    /**
     * Nose width reshape via localized "liquify" warp (OpenCV remap).
     * amount −1 = slimmer, +1 = wider. Only the nose region is remapped; the
     * rest of the image is untouched (identity map outside the wing circles).
     */
    private fun applyNoseReshape(bgr: Mat, landmarks: List<PointF>, amount: Float) {
        val s = amount.coerceIn(-1f, 1f)
        if (kotlin.math.abs(s) < 0.01f) return

        val tip = landmarks.getOrNull(MediaPipeLandmarkIndices.NOSE_TIP) ?: return

        // Pick the two most-lateral nose points as the wings.
        var leftWing: PointF? = null
        var rightWing: PointF? = null
        for (idx in MediaPipeLandmarkIndices.NOSE_WING_ZONE) {
            val p = landmarks.getOrNull(idx) ?: continue
            if (leftWing == null || p.x < leftWing!!.x) leftWing = p
            if (rightWing == null || p.x > rightWing!!.x) rightWing = p
        }
        val lw = leftWing ?: return
        val rw = rightWing ?: return

        val noseWidth = (rw.x - lw.x).toDouble()
        if (noseWidth < 4.0) return

        // Natural strength: max ~28% of the half-width shift per wing.
        val k = 0.28 * -s // −s so + slider widens, − slider slims
        val rmax = noseWidth * 0.80
        val rmax2 = rmax * rmax

        // Horizontal-only target shift for each wing (toward/away from tip x).
        val shiftL = (tip.x - lw.x) * k
        val shiftR = (tip.x - rw.x) * k
        if (kotlin.math.abs(shiftL) < 0.3 && kotlin.math.abs(shiftR) < 0.3) return

        // ROI covering both wing circles (+margin), clamped to image.
        val w = bgr.cols()
        val h = bgr.rows()
        val margin = 2
        val minX = (min(lw.x, rw.x) - rmax).toInt().coerceIn(0, w - 1) - margin
        val maxX = (max(lw.x, rw.x) + rmax).toInt().coerceIn(0, w - 1) + margin
        val minY = (min(lw.y, rw.y) - rmax).toInt().coerceIn(0, h - 1) - margin
        val maxY = (max(lw.y, rw.y) + rmax).toInt().coerceIn(0, h - 1) + margin
        val x0 = minX.coerceIn(0, w - 1)
        val y0 = minY.coerceIn(0, h - 1)
        val x1 = maxX.coerceIn(0, w - 1)
        val y1 = maxY.coerceIn(0, h - 1)
        val roiW = x1 - x0 + 1
        val roiH = y1 - y0 + 1
        if (roiW < 4 || roiH < 4) return

        val mapXArr = FloatArray(roiW * roiH)
        val mapYArr = FloatArray(roiW * roiH)
        for (yy in 0 until roiH) {
            val gy = (y0 + yy).toDouble()
            for (xx in 0 until roiW) {
                val gx = (x0 + xx).toDouble()
                var dispX = 0.0
                dispX += wingDisplacement(gx, gy, lw, shiftL, rmax2)
                dispX += wingDisplacement(gx, gy, rw, shiftR, rmax2)
                // Inverse map: sample source at (target − displacement), local coords.
                val i = yy * roiW + xx
                mapXArr[i] = (gx - dispX - x0).toFloat()
                mapYArr[i] = (gy - y0).toFloat()
            }
        }

        val src = bgr.submat(org.opencv.core.Rect(x0, y0, roiW, roiH))
        val warped = Mat()
        val mapX = Mat(roiH, roiW, CvType.CV_32FC1)
        val mapY = Mat(roiH, roiW, CvType.CV_32FC1)
        try {
            mapX.put(0, 0, mapXArr)
            mapY.put(0, 0, mapYArr)
            Imgproc.remap(
                src,
                warped,
                mapX,
                mapY,
                Imgproc.INTER_LINEAR,
                Core.BORDER_REPLICATE,
                Scalar(0.0),
            )
            warped.copyTo(src)
        } finally {
            src.release()
            warped.release()
            mapX.release()
            mapY.release()
        }
    }

    /** Gustafsson local translation warp — horizontal displacement at (gx,gy). */
    private fun wingDisplacement(
        gx: Double,
        gy: Double,
        wing: PointF,
        shiftX: Double,
        rmax2: Double,
    ): Double {
        val dx = gx - wing.x
        val dy = gy - wing.y
        val dist2 = dx * dx + dy * dy
        if (dist2 >= rmax2) return 0.0
        val d2 = shiftX * shiftX
        val f = (rmax2 - dist2) / (rmax2 - dist2 + d2)
        return f * f * shiftX
    }

    private fun detectLandmarks(context: Context, bitmap: Bitmap): List<PointF>? {
        synchronized(landmarkerLock) {
            val landmarker = imageLandmarker ?: createImageLandmarker(context).also {
                imageLandmarker = it
            }
            val mpImage = BitmapImageBuilder(bitmap).build()
            val result = try {
                landmarker.detect(mpImage)
            } catch (t: Throwable) {
                Log.w(TAG, "Face detect failed", t)
                null
            }
            return landmarksFromResult(result, bitmap.width, bitmap.height)
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
            .setMinFaceDetectionConfidence(0.5f)
            .setMinFacePresenceConfidence(0.5f)
            .build()
        return FaceLandmarker.createFromOptions(context.applicationContext, options)
    }

    private fun landmarksFromResult(
        result: FaceLandmarkerResult?,
        width: Int,
        height: Int,
    ): List<PointF>? {
        if (result == null || result.faceLandmarks().isEmpty()) return null
        val list = result.faceLandmarks()[0]
        if (list.size < 468) return null
        return list.map { lm ->
            PointF(lm.x() * width, lm.y() * height)
        }
    }

    private fun decodeOrientedBitmap(path: String): Bitmap? {
        val opts = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
        val raw = BitmapFactory.decodeFile(path, opts) ?: return null
        return try {
            val exif = ExifInterface(path)
            val orientation = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
            val degrees = when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
            if (degrees == 0f) {
                raw
            } else {
                val m = Matrix().apply { postRotate(degrees) }
                val rotated = Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, m, true)
                if (rotated !== raw) raw.recycle()
                rotated
            }
        } catch (_: Exception) {
            raw
        }
    }
}
