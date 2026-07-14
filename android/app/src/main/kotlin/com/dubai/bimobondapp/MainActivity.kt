package com.dubai.bimobondapp

import android.content.pm.PackageManager
import com.dubai.bimobondapp.ar_camera.ArCameraBridge
import com.dubai.bimobondapp.ar_camera.ArCameraController
import com.dubai.bimobondapp.ar_camera.ArCameraPlatformViewFactory
import com.dubai.bimobondapp.ar_camera.FaceLandmarkerHolder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val AR_CAMERA_CHANNEL = "com.dubai.bimobondapp/ar_camera"
        const val AR_CAMERA_VIEW_TYPE = "ar-camera-preview"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            AR_CAMERA_VIEW_TYPE,
            ArCameraPlatformViewFactory(this),
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AR_CAMERA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ping" -> result.success("native_connected")
                    "warmup" -> {
                        FaceLandmarkerHolder.warmup(this)
                        result.success(null)
                    }
                    "setFilter" -> {
                        val filter = call.argument<String>("filter") ?: "none"
                        val intensity = call.argument<Double>("intensity")?.toFloat()
                        ArCameraBridge.setFilter(filter, intensity)
                        result.success(null)
                    }
                    "setFilterIntensity" -> {
                        val intensity = call.argument<Double>("intensity")?.toFloat() ?: 1f
                        ArCameraBridge.updateFilterIntensity(intensity)
                        result.success(null)
                    }
                    "prepareShaderPipeline" -> {
                        ArCameraBridge.prepareShaderPipeline()
                        result.success(null)
                    }
                    "takePhoto" -> {
                        ArCameraController.takePhoto { path, error ->
                            if (path != null) {
                                result.success(path)
                            } else {
                                result.error("photo_failed", error ?: "unknown", null)
                            }
                        }
                    }
                    "startRecording" -> {
                        ArCameraController.startRecording { ok, error ->
                            if (ok) {
                                result.success(null)
                            } else {
                                result.error("record_start_failed", error ?: "unknown", null)
                            }
                        }
                    }
                    "stopRecording" -> {
                        ArCameraController.stopRecording { path, error ->
                            if (path != null) {
                                result.success(path)
                            } else {
                                result.error("record_stop_failed", error ?: "unknown", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100 &&
            grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            ArCameraController.onPermissionGranted()
        }
    }
}