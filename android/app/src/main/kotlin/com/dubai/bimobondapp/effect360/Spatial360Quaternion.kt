package com.dubai.bimobondapp.effect360

import android.hardware.SensorManager
import android.opengl.Matrix
import android.view.Surface

object Spatial360Quaternion {
    /**
     * Converts a 4-element Android Rotation Vector to a 4x4 View Matrix, accounting for display rotation.
     */
    fun rotationVectorToViewMatrix(
        rotationVector: FloatArray,
        outMatrix: FloatArray,
        displayRotation: Int = Surface.ROTATION_0
    ) {
        val rotationMatrix = FloatArray(16)
        SensorManager.getRotationMatrixFromVector(rotationMatrix, rotationVector)

        var axisX = SensorManager.AXIS_X
        var axisY = SensorManager.AXIS_Z

        when (displayRotation) {
            Surface.ROTATION_90 -> {
                axisX = SensorManager.AXIS_Z
                axisY = SensorManager.AXIS_MINUS_X
            }
            Surface.ROTATION_180 -> {
                axisX = SensorManager.AXIS_MINUS_X
                axisY = SensorManager.AXIS_MINUS_Z
            }
            Surface.ROTATION_270 -> {
                axisX = SensorManager.AXIS_MINUS_Z
                axisY = SensorManager.AXIS_X
            }
            else -> {
                axisX = SensorManager.AXIS_X
                axisY = SensorManager.AXIS_Z
            }
        }

        val remappedMatrix = FloatArray(16)
        SensorManager.remapCoordinateSystem(rotationMatrix, axisX, axisY, remappedMatrix)

        Matrix.invertM(outMatrix, 0, remappedMatrix, 0)
    }
}
