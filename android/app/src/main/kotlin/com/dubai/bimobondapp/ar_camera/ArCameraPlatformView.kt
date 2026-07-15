package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import androidx.camera.view.PreviewView
import com.dubai.bimobondapp.R
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.platform.PlatformView

class ArCameraPlatformView(
    context: Context,
    private val activity: FlutterActivity,
) : PlatformView {

    private val root: View = LayoutInflater.from(context)
        .inflate(R.layout.ar_camera_platform_view, null, false)
    private val previewView: PreviewView = root.findViewById(R.id.previewView)
    private val warpGlView: FaceWarpGlView = root.findViewById(R.id.warpGlView)
    private val faceOverlay: FaceOverlayView = root.findViewById(R.id.faceOverlay)

    init {
        ArCameraBridge.faceOverlay = faceOverlay
        ArCameraBridge.previewView = previewView
        ArCameraBridge.warpGlView = warpGlView
        ArCameraBridge.platformRoot = root
        ArCameraBridge.hostActivity = activity
        ArCameraBridge.lifecycleOwner = activity
        warpGlView.addOnLayoutChangeListener { _, left, top, right, bottom, _, _, _, _ ->
            ArCameraBridge.updateWarpViewSize(right - left, bottom - top)
        }
        warpGlView.post {
            ArCameraBridge.updateWarpViewSize(warpGlView.width, warpGlView.height)
        }
        root.post {
            ArCameraBridge.applyCurrentFilter()
            ArCameraController.start(activity, activity, previewView, faceOverlay)
        }
    }

    override fun getView(): View = root

    override fun dispose() {
        ArCameraController.stop()
        ArCameraBridge.clear()
    }
}
