package com.dubai.bimobondapp.ar_camera

import android.graphics.PointF
import android.graphics.RectF

data class FaceLandmarkSnapshot(
    val imageWidth: Int,
    val imageHeight: Int,
    val boundingBox: RectF,
    val leftEye: PointF,
    val rightEye: PointF,

    val leftEyeBulge: PointF,
    val rightEyeBulge: PointF,
    val noseTip: PointF,
    val noseBridge: PointF,
    val mouthLeft: PointF,
    val mouthRight: PointF,
    val mouthBottom: PointF,
    val topHead: PointF,
    val landmarks: List<PointF>,

    val hasHeadPose: Boolean = false,
    val pitchDeg: Float = 0f,
    val yawDeg: Float = 0f,
    val rollDeg: Float = 0f,
)
