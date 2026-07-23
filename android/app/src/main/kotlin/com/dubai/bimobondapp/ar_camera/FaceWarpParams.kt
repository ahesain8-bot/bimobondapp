package com.dubai.bimobondapp.ar_camera

data class FaceWarpParams(
    val filterType: Int,
    val bulge1: FloatArray,
    val bulge2: FloatArray,
    val noseRect: FloatArray,
    val nosePull: Float,
) {
    companion object {
        const val FILTER_NONE = 0
        const val FILTER_BIG_EYES = 1
        const val FILTER_BIG_LIPS = 2
        const val FILTER_LONG_NOSE = 3

        val INACTIVE = FaceWarpParams(
            filterType = FILTER_NONE,
            bulge1 = floatArrayOf(0f, 0f, 0f, 0f),
            bulge2 = floatArrayOf(0f, 0f, 0f, 0f),
            noseRect = floatArrayOf(0f, 0f, 0f, 0f),
            nosePull = 0f,
        )
    }
}

object FaceWarpParamsBuilder {

    fun build(
        snapshot: FaceLandmarkSnapshot?,
        filter: FilterType,
        imageWidth: Int,
        imageHeight: Int,
        viewWidth: Int,
        viewHeight: Int,
    ): FaceWarpParams {
        if (!filter.useShader() ||
            imageWidth <= 0 ||
            imageHeight <= 0 ||
            viewWidth <= 0 ||
            viewHeight <= 0
        ) {
            return FaceWarpParams.INACTIVE
        }

        if (filter.isDistortion() && snapshot == null) {
            return FaceWarpParams.INACTIVE
        }

        val faceWidth = snapshot?.boundingBox?.width()?.coerceAtLeast(1f) ?: 1f
        val faceHeight = snapshot?.boundingBox?.height()?.coerceAtLeast(1f) ?: 1f

        fun map(x: Float, y: Float): FloatArray =
            FaceCoordinateMapper.toWarpUv(
                x,
                y,
                imageWidth,
                imageHeight,

                isFrontCamera = ArCameraBridge.isFrontCamera,
            )

        fun radius(radiusPx: Float): Float =
            FaceCoordinateMapper.toWarpRadiusX(radiusPx, imageWidth)

        fun lengthY(lengthPx: Float): Float =
            FaceCoordinateMapper.toWarpLengthY(lengthPx, imageHeight)

        return when (filter) {
            FilterType.BIG_EYES -> {
                if (snapshot == null) return FaceWarpParams.INACTIVE
                val rightCenter = map(snapshot.rightEyeBulge.x, snapshot.rightEyeBulge.y)
                val leftCenter = map(snapshot.leftEyeBulge.x, snapshot.leftEyeBulge.y)
                val radiusNorm = radius(faceWidth * 0.25f)
                val strength = 1.6f

                FaceWarpParams(
                    filterType = FaceWarpParams.FILTER_BIG_EYES,
                    bulge1 = floatArrayOf(rightCenter[0], rightCenter[1], radiusNorm, strength),
                    bulge2 = floatArrayOf(leftCenter[0], leftCenter[1], radiusNorm, strength),
                    noseRect = floatArrayOf(0f, 0f, 0f, 0f),
                    nosePull = 0f,
                )
            }

            FilterType.BIG_LIPS -> {
                if (snapshot == null) return FaceWarpParams.INACTIVE
                val upperLip = snapshot.landmarks.getOrNull(MediaPipeLandmarkIndices.MOUTH_TOP)
                val centerX = (snapshot.mouthLeft.x + snapshot.mouthRight.x) / 2f
                val centerY = when {
                    upperLip != null -> (upperLip.y + snapshot.mouthBottom.y) / 2f
                    else -> (snapshot.mouthBottom.y + snapshot.mouthLeft.y) / 2f
                }
                val center = map(centerX, centerY)

                FaceWarpParams(
                    filterType = FaceWarpParams.FILTER_BIG_LIPS,
                    bulge1 = floatArrayOf(
                        center[0],
                        center[1],
                        radius(faceWidth * 0.32f),
                        1.5f,
                    ),
                    bulge2 = floatArrayOf(0f, 0f, 0f, 0f),
                    noseRect = floatArrayOf(0f, 0f, 0f, 0f),
                    nosePull = 0f,
                )
            }

            FilterType.LONG_NOSE -> {
                if (snapshot == null) return FaceWarpParams.INACTIVE
                val bridgePoints = buildList {
                    for (idx in MediaPipeLandmarkIndices.NOSE_BRIDGE_LINE) {
                        snapshot.landmarks.getOrNull(idx)?.let { add(it) }
                    }
                }
                val bridgeCenterX = if (bridgePoints.isNotEmpty()) {
                    bridgePoints.map { it.x }.average().toFloat()
                } else {
                    (snapshot.noseBridge.x + snapshot.noseTip.x) / 2f
                }
                val noseTopY = if (bridgePoints.size >= 2) {
                    bridgePoints.minOf { it.y }
                } else {
                    snapshot.noseBridge.y - faceHeight * 0.02f
                }
                val noseBottomY = snapshot.noseTip.y + faceHeight * 0.06f

                val noseCenter = map(bridgeCenterX, (noseTopY + noseBottomY) / 2f)
                val topMapped = map(bridgeCenterX, noseTopY - faceHeight * 0.01f)
                val bottomMapped = map(bridgeCenterX, noseBottomY)

                val leftNostril = snapshot.landmarks.getOrNull(98)
                val rightNostril = snapshot.landmarks.getOrNull(327)
                val halfWidth = when {
                    leftNostril != null && rightNostril != null -> {
                        val left = map(leftNostril.x, leftNostril.y)
                        val right = map(rightNostril.x, rightNostril.y)
                        kotlin.math.abs(left[0] - right[0]) / 2f + radius(faceWidth * 0.04f)
                    }
                    else -> radius(faceWidth * 0.11f)
                }
                val halfHeight =
                    (kotlin.math.abs(bottomMapped[1] - topMapped[1]) * 0.5f).coerceAtLeast(0.01f)

                FaceWarpParams(
                    filterType = FaceWarpParams.FILTER_LONG_NOSE,
                    bulge1 = floatArrayOf(noseCenter[0], noseCenter[1], halfWidth * 1.3f, halfHeight * 1.4f),
                    bulge2 = floatArrayOf(0f, 0f, 0f, 0f),
                    noseRect = floatArrayOf(0f, 0f, 0f, 0f),
                    nosePull = lengthY(faceHeight * 0.28f),
                )
            }

            else -> FaceWarpParams.INACTIVE
        }
    }
}
