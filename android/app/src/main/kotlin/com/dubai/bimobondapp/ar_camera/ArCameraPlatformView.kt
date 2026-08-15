package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.view.LayoutInflater
import android.view.TextureView
import android.view.View
import androidx.camera.view.PreviewView
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.airbnb.lottie.AsyncUpdates
import com.airbnb.lottie.LottieAnimationView
import com.airbnb.lottie.LottieDrawable
import com.airbnb.lottie.RenderMode
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
    private val confettiOverlay: LottieAnimationView = root.findViewById(R.id.confettiOverlay)
    private val videoOverlay: TextureView = root.findViewById(R.id.videoOverlay)

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onPause(owner: LifecycleOwner) {
            android.util.Log.i(
                "ArCameraLifecycle",
                "PlatformView.onPause state=${owner.lifecycle.currentState} " +
                    "rootAttached=${root.isAttachedToWindow} " +
                    "glSurface=${warpGlView.cameraSurfaceTexture() != null}",
            )
            ArCameraController.onHostPause()
            try {
                confettiOverlay.pauseAnimation()
            } catch (_: Throwable) {
            }
            try {
                ArCameraBridge.ensureVideoHelper()?.pause()
            } catch (_: Throwable) {
            }
        }

        override fun onResume(owner: LifecycleOwner) {
            android.util.Log.i(
                "ArCameraLifecycle",
                "PlatformView.onResume state=${owner.lifecycle.currentState} " +
                    "rootAttached=${root.isAttachedToWindow} " +
                    "glSurface=${warpGlView.cameraSurfaceTexture() != null}",
            )
            ArCameraController.onHostResume()
            try {
                if (confettiOverlay.visibility == View.VISIBLE) confettiOverlay.resumeAnimation()
            } catch (_: Throwable) {
            }
            try {
                if (videoOverlay.visibility == View.VISIBLE) {
                    ArCameraBridge.ensureVideoHelper()?.resume()
                }
            } catch (_: Throwable) {
            }
        }
    }

    init {
        ArCameraBridge.faceOverlay = faceOverlay
        ArCameraBridge.previewView = previewView
        ArCameraBridge.warpGlView = warpGlView
        ArCameraBridge.confettiOverlay = confettiOverlay
        ArCameraBridge.videoOverlay = videoOverlay
        ArCameraBridge.platformRoot = root
        ArCameraBridge.hostActivity = activity
        ArCameraBridge.lifecycleOwner = activity
        activity.lifecycle.addObserver(lifecycleObserver)
        warpGlView.addOnLayoutChangeListener { _, left, top, right, bottom, _, _, _, _ ->
            ArCameraBridge.updateWarpViewSize(right - left, bottom - top)
        }

        previewView.implementationMode = PreviewView.ImplementationMode.PERFORMANCE
        previewView.scaleType = PreviewView.ScaleType.FILL_CENTER
        previewView.visibility = View.VISIBLE
        warpGlView.visibility = View.INVISIBLE

        warpGlView.ensureGlInitialized()

        confettiOverlay.visibility = View.GONE
        videoOverlay.visibility = View.GONE
        confettiOverlay.repeatCount = LottieDrawable.INFINITE
        confettiOverlay.cancelAnimation()
        try {
            confettiOverlay.setRenderMode(RenderMode.HARDWARE)
            confettiOverlay.setAsyncUpdates(AsyncUpdates.ENABLED)
            confettiOverlay.setFailureListener { error ->
                android.util.Log.e("ArCamera", "screen overlay animation failed to load", error)
            }
        } catch (t: Throwable) {
            android.util.Log.e("ArCamera", "screen overlay setup failed", t)
        }

        ArCameraBridge.syncPreviewNaturalOrientation()
        ArCameraController.start(activity, activity, previewView, faceOverlay)
        ArCameraBridge.applyCurrentFilter()
        root.post {
            ArCameraBridge.updateWarpViewSize(warpGlView.width, warpGlView.height)
            ArCameraBridge.reapplyPreviewLetterbox()
        }
    }

    override fun getView(): View = root

    override fun dispose() {
        try {
            activity.lifecycle.removeObserver(lifecycleObserver)
        } catch (_: Throwable) {
        }
        try {
            confettiOverlay.cancelAnimation()
        } catch (_: Throwable) {
        }
        try {
            ArCameraBridge.ensureVideoHelper()?.release()
        } catch (_: Throwable) {
        }
        ArCameraController.stop()
        ArCameraBridge.clear()
    }
}
