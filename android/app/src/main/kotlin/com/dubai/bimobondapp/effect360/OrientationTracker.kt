package com.dubai.bimobondapp.effect360

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.opengl.Matrix

class OrientationTracker(context: Context) : SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rotationVectorSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

    private val currentViewMatrix = FloatArray(16)
    private val smoothViewMatrix = FloatArray(16)

    private var isTracking = false

    init {
        Matrix.setIdentityM(currentViewMatrix, 0)
        Matrix.setIdentityM(smoothViewMatrix, 0)
    }

    fun startTracking() {
        if (isTracking || rotationVectorSensor == null) return
        sensorManager.registerListener(this, rotationVectorSensor, SensorManager.SENSOR_DELAY_GAME)
        isTracking = true
    }

    fun stopTracking() {
        if (!isTracking) return
        sensorManager.unregisterListener(this)
        isTracking = false
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ROTATION_VECTOR) return

        val rawViewMatrix = FloatArray(16)
        Spatial360Quaternion.rotationVectorToViewMatrix(
            rotationVector = event.values,
            outMatrix = rawViewMatrix,
            displayRotation = android.view.Surface.ROTATION_0
        )

        // Low-pass filter smoothing alpha = 0.15f
        for (i in 0..15) {
            smoothViewMatrix[i] = smoothViewMatrix[i] + 0.15f * (rawViewMatrix[i] - smoothViewMatrix[i])
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    fun getViewMatrix(outMatrix: FloatArray) {
        System.arraycopy(smoothViewMatrix, 0, outMatrix, 0, 16)
    }
}
