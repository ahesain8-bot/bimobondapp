package com.dubai.bimobondapp.ar_camera

import android.graphics.PointF
import android.graphics.RectF
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult

object FaceLandmarkMapper {

    fun fromResult(
        result: FaceLandmarkerResult,
        imageWidth: Int,
        imageHeight: Int,
    ): FaceLandmarkSnapshot? {
        if (result.faceLandmarks().isEmpty()) return null

        val landmarkList = result.faceLandmarks()[0]
        val points = landmarkList.map { landmark -> toPoint(landmark, imageWidth, imageHeight) }
        if (points.size < 300) return null

        val leftEye = averagePoint(points, MediaPipeLandmarkIndices.LEFT_EYE)
        val rightEye = averagePoint(points, MediaPipeLandmarkIndices.RIGHT_EYE)
        val leftEyeBulge = averagePoint(points, MediaPipeLandmarkIndices.LEFT_EYE_BULGE)
        val rightEyeBulge = averagePoint(points, MediaPipeLandmarkIndices.RIGHT_EYE_BULGE)
        val topHead = computeTopHead(points)
        val boundingBox = computeBoundingBox(points)

        val pose = extractHeadPose(result)

        return FaceLandmarkSnapshot(
            imageWidth = imageWidth,
            imageHeight = imageHeight,
            boundingBox = boundingBox,
            leftEye = leftEye,
            rightEye = rightEye,
            leftEyeBulge = leftEyeBulge,
            rightEyeBulge = rightEyeBulge,
            noseTip = points[MediaPipeLandmarkIndices.NOSE_TIP],
            noseBridge = points[MediaPipeLandmarkIndices.NOSE_BRIDGE],
            mouthLeft = points[MediaPipeLandmarkIndices.MOUTH_LEFT],
            mouthRight = points[MediaPipeLandmarkIndices.MOUTH_RIGHT],
            mouthBottom = points[MediaPipeLandmarkIndices.MOUTH_BOTTOM],
            topHead = topHead,
            landmarks = points,
            hasHeadPose = pose != null,
            pitchDeg = pose?.get(0) ?: 0f,
            yawDeg = pose?.get(1) ?: 0f,
            rollDeg = pose?.get(2) ?: 0f,
        )
    }

    private fun extractHeadPose(result: FaceLandmarkerResult): FloatArray? {
        val matrices = try {
            result.facialTransformationMatrixes()
                .orElse(null)
                ?.firstOrNull()
        } catch (_: Throwable) {
            null
        } ?: return null
        if (matrices.size < 16) return null

        val r00 = matrices[0]
        val r10 = matrices[1]
        val r20 = matrices[2]
        val r21 = matrices[6]
        val r22 = matrices[10]
        val pitch = Math.toDegrees(kotlin.math.atan2(-r21.toDouble(), r22.toDouble())).toFloat()
        val yaw = Math.toDegrees(
            kotlin.math.atan2(
                r20.toDouble(),
                kotlin.math.sqrt((r00 * r00 + r10 * r10).toDouble()),
            ),
        ).toFloat()
        val roll = Math.toDegrees(kotlin.math.atan2(r10.toDouble(), r00.toDouble())).toFloat()
        return floatArrayOf(pitch, yaw, roll)
    }

    private fun toPoint(landmark: NormalizedLandmark, width: Int, height: Int): PointF {
        return PointF(landmark.x() * width, landmark.y() * height)
    }

    private fun averagePoint(points: List<PointF>, indices: IntArray): PointF {
        var sumX = 0f
        var sumY = 0f
        for (index in indices) {
            val point = points[index]
            sumX += point.x
            sumY += point.y
        }
        val count = indices.size.coerceAtLeast(1)
        return PointF(sumX / count, sumY / count)
    }

    private fun computeTopHead(points: List<PointF>): PointF {
        var minY = Float.MAX_VALUE
        var sumX = 0f
        var count = 0
        for (index in MediaPipeLandmarkIndices.TOP_HEAD) {
            val point = points.getOrNull(index) ?: continue
            minY = minOf(minY, point.y)
            sumX += point.x
            count++
        }
        if (count == 0) {
            return points.getOrElse(MediaPipeLandmarkIndices.FOREHEAD) { PointF(0f, 0f) }
        }
        return PointF(sumX / count, minY)
    }

    private fun computeBoundingBox(points: List<PointF>): RectF {
        var minX = Float.MAX_VALUE
        var minY = Float.MAX_VALUE
        var maxX = Float.MIN_VALUE
        var maxY = Float.MIN_VALUE

        for (point in points) {
            minX = minOf(minX, point.x)
            minY = minOf(minY, point.y)
            maxX = maxOf(maxX, point.x)
            maxY = maxOf(maxY, point.y)
        }

        return RectF(minX, minY, maxX, maxY)
    }

    fun scaleSnapshot(
        snapshot: FaceLandmarkSnapshot,
        targetWidth: Int,
        targetHeight: Int,
    ): FaceLandmarkSnapshot {
        if (snapshot.imageWidth == targetWidth && snapshot.imageHeight == targetHeight) {
            return snapshot
        }
        val scaleX = targetWidth.toFloat() / snapshot.imageWidth
        val scaleY = targetHeight.toFloat() / snapshot.imageHeight

        fun scalePoint(point: PointF): PointF = PointF(point.x * scaleX, point.y * scaleY)

        return snapshot.copy(
            imageWidth = targetWidth,
            imageHeight = targetHeight,
            boundingBox = RectF(
                snapshot.boundingBox.left * scaleX,
                snapshot.boundingBox.top * scaleY,
                snapshot.boundingBox.right * scaleX,
                snapshot.boundingBox.bottom * scaleY,
            ),
            leftEye = scalePoint(snapshot.leftEye),
            rightEye = scalePoint(snapshot.rightEye),
            leftEyeBulge = scalePoint(snapshot.leftEyeBulge),
            rightEyeBulge = scalePoint(snapshot.rightEyeBulge),
            noseTip = scalePoint(snapshot.noseTip),
            noseBridge = scalePoint(snapshot.noseBridge),
            mouthLeft = scalePoint(snapshot.mouthLeft),
            mouthRight = scalePoint(snapshot.mouthRight),
            mouthBottom = scalePoint(snapshot.mouthBottom),
            topHead = scalePoint(snapshot.topHead),
            landmarks = snapshot.landmarks.map(::scalePoint),
        )
    }
}
