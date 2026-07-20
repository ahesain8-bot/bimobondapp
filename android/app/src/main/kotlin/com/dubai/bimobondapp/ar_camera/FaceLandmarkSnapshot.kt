package com.dubai.bimobondapp.ar_camera

import android.graphics.PointF
import android.graphics.RectF

/** Face landmark data extracted from MediaPipe (468-point mesh). */
data class FaceLandmarkSnapshot(
    val imageWidth: Int,
    val imageHeight: Int,
    val boundingBox: RectF,
    val leftEye: PointF,
    val rightEye: PointF,
    /** Tighter center for GPU eye-bulge (iris region). */
    val leftEyeBulge: PointF,
    val rightEyeBulge: PointF,
    val noseTip: PointF,
    val noseBridge: PointF,
    val mouthLeft: PointF,
    val mouthRight: PointF,
    val mouthBottom: PointF,
    val topHead: PointF,
    val landmarks: List<PointF>,
    /** Head pose from facial transformation matrix (degrees). */
    val hasHeadPose: Boolean = false,
    val pitchDeg: Float = 0f,
    val yawDeg: Float = 0f,
    val rollDeg: Float = 0f,
)
