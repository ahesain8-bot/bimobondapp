package com.dubai.bimobondapp.ar_camera

/** Normalized GPU warp uniforms in raw texture UV space (0..1). */
data class FaceWarpParams(
    val filterType: Int,
    val bulge1: FloatArray,
    val bulge2: FloatArray,
    val noseRect: FloatArray,
    val nosePull: Float,
    /** Lip bounding box (minU, minV, maxU, maxV) in warp UV space; zeros = none. */
    val lipRect: FloatArray = floatArrayOf(0f, 0f, 0f, 0f),
    /** Skin-smoothing / beauty strength (0 = off). */
    val beauty: Float = 0f,
    /** Mix original ↔ full filter look (0 = off, 1 = full). */
    val intensity: Float = 1f,
) {
    companion object {
        const val FILTER_NONE = 0
        const val FILTER_BIG_EYES = 1
        const val FILTER_BIG_LIPS = 2
        const val FILTER_LONG_NOSE = 3
        const val FILTER_WHITENING = 4
        const val FILTER_WARM = 5
        const val FILTER_MONO = 6
        const val FILTER_COOL = 7
        const val FILTER_VINTAGE = 8
        const val FILTER_ROSY = 9
        const val FILTER_CLARENDON = 10
        const val FILTER_VALENCIA = 11
        const val FILTER_LUDWIG = 12
        const val FILTER_CITY_FILM = 13
        const val FILTER_GOING_FOR_A_WALK = 14
        const val FILTER_GOOD_MORNING = 15
        const val FILTER_NAH = 16
        const val FILTER_ONCE_UPON_A_TIME = 17
        const val FILTER_PASSING_BY = 18
        const val FILTER_SERENITY = 19
        const val FILTER_UNDENIABLE_2 = 20
        const val FILTER_UNDENIABLE = 21
        const val FILTER_URBAN_COWBOY = 22
        const val FILTER_YOU_CAN_DO_IT = 23
        const val FILTER_SMOOTH_SAILING = 24
        const val FILTER_WELL_SEE = 25

        val INACTIVE = FaceWarpParams(
            filterType = FILTER_NONE,
            bulge1 = floatArrayOf(0f, 0f, 0f, 0f),
            bulge2 = floatArrayOf(0f, 0f, 0f, 0f),
            noseRect = floatArrayOf(0f, 0f, 0f, 0f),
            nosePull = 0f,
            intensity = 0f,
        )
    }
}

object FaceWarpParamsBuilder {

    private fun filterCode(filter: FilterType): Int = when (filter) {
        FilterType.BIG_EYES -> FaceWarpParams.FILTER_BIG_EYES
        FilterType.BIG_LIPS -> FaceWarpParams.FILTER_BIG_LIPS
        FilterType.LONG_NOSE -> FaceWarpParams.FILTER_LONG_NOSE
        FilterType.WHITENING -> FaceWarpParams.FILTER_WHITENING
        FilterType.WARM -> FaceWarpParams.FILTER_WARM
        FilterType.MONO -> FaceWarpParams.FILTER_MONO
        FilterType.COOL -> FaceWarpParams.FILTER_COOL
        FilterType.VINTAGE -> FaceWarpParams.FILTER_VINTAGE
        FilterType.ROSY -> FaceWarpParams.FILTER_ROSY
        FilterType.CLARENDON -> FaceWarpParams.FILTER_CLARENDON
        FilterType.VALENCIA -> FaceWarpParams.FILTER_VALENCIA
        FilterType.LUDWIG -> FaceWarpParams.FILTER_LUDWIG
        FilterType.CITY_FILM -> FaceWarpParams.FILTER_CITY_FILM
        FilterType.GOING_FOR_A_WALK -> FaceWarpParams.FILTER_GOING_FOR_A_WALK
        FilterType.GOOD_MORNING -> FaceWarpParams.FILTER_GOOD_MORNING
        FilterType.NAH -> FaceWarpParams.FILTER_NAH
        FilterType.ONCE_UPON_A_TIME -> FaceWarpParams.FILTER_ONCE_UPON_A_TIME
        FilterType.PASSING_BY -> FaceWarpParams.FILTER_PASSING_BY
        FilterType.SERENITY -> FaceWarpParams.FILTER_SERENITY
        FilterType.UNDENIABLE_2 -> FaceWarpParams.FILTER_UNDENIABLE_2
        FilterType.UNDENIABLE -> FaceWarpParams.FILTER_UNDENIABLE
        FilterType.URBAN_COWBOY -> FaceWarpParams.FILTER_URBAN_COWBOY
        FilterType.YOU_CAN_DO_IT -> FaceWarpParams.FILTER_YOU_CAN_DO_IT
        FilterType.SMOOTH_SAILING -> FaceWarpParams.FILTER_SMOOTH_SAILING
        FilterType.WELL_SEE -> FaceWarpParams.FILTER_WELL_SEE
        else -> FaceWarpParams.FILTER_NONE
    }

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
                // Front uploads are selfie-mirrored to match PreviewView; invert X in UV.
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

            else -> {
                // Color grades (whitening / warm / mono / cool / vintage / rosy).
                val lipRect = snapshot?.let { computeLipRect(it, imageWidth, imageHeight) }
                    ?: floatArrayOf(0f, 0f, 0f, 0f)
                val beauty = when (filter) {
                    FilterType.WHITENING -> 0.62f
                    FilterType.ROSY -> 0.52f
                    FilterType.LUDWIG -> 0.58f
                    else -> 0f
                } * ArCameraBridge.filterIntensity.coerceIn(0f, 1f)
                FaceWarpParams(
                    filterType = filterCode(filter),
                    bulge1 = floatArrayOf(0f, 0f, 0f, 0f),
                    bulge2 = floatArrayOf(0f, 0f, 0f, 0f),
                    noseRect = floatArrayOf(0f, 0f, 0f, 0f),
                    nosePull = 0f,
                    lipRect = lipRect,
                    beauty = beauty,
                    intensity = ArCameraBridge.filterIntensity.coerceIn(0f, 1f),
                )
            }
        }
    }

    /** Lip bounding box in warp UV space, padded slightly for a soft tint mask. */
    private fun computeLipRect(
        snapshot: FaceLandmarkSnapshot,
        imageWidth: Int,
        imageHeight: Int,
    ): FloatArray {
        var minX = Float.MAX_VALUE
        var minY = Float.MAX_VALUE
        var maxX = -Float.MAX_VALUE
        var maxY = -Float.MAX_VALUE
        var count = 0

        fun consume(idx: Int) {
            val p = snapshot.landmarks.getOrNull(idx) ?: return
            minX = minOf(minX, p.x)
            minY = minOf(minY, p.y)
            maxX = maxOf(maxX, p.x)
            maxY = maxOf(maxY, p.y)
            count++
        }

        for (idx in MediaPipeLandmarkIndices.UPPER_LIP) consume(idx)
        for (idx in MediaPipeLandmarkIndices.LOWER_LIP) consume(idx)

        if (count == 0) return floatArrayOf(0f, 0f, 0f, 0f)

        val padX = (maxX - minX) * 0.10f
        val padY = (maxY - minY) * 0.18f
        val front = ArCameraBridge.isFrontCamera
        val a = FaceCoordinateMapper.toWarpUv(
            minX - padX,
            minY - padY,
            imageWidth,
            imageHeight,
            isFrontCamera = front,
        )
        val b = FaceCoordinateMapper.toWarpUv(
            maxX + padX,
            maxY + padY,
            imageWidth,
            imageHeight,
            isFrontCamera = front,
        )

        return floatArrayOf(
            minOf(a[0], b[0]),
            minOf(a[1], b[1]),
            maxOf(a[0], b[0]),
            maxOf(a[1], b[1]),
        )
    }
}
