package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import androidx.camera.view.PreviewView
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.airbnb.lottie.AsyncUpdates
import com.airbnb.lottie.LottieAnimationView
import com.airbnb.lottie.LottieCompositionFactory
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

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onPause(owner: LifecycleOwner) {
            ArCameraController.onHostPause()
            // Stop burning GPU/CPU on the confetti loop while the screen isn't visible.
            try {
                confettiOverlay.pauseAnimation()
            } catch (_: Throwable) {
            }
        }

        override fun onResume(owner: LifecycleOwner) {
            ArCameraController.onHostResume()
            try {
                if (confettiOverlay.visibility == View.VISIBLE) confettiOverlay.resumeAnimation()
            } catch (_: Throwable) {
            }
        }
    }

    init {
        ArCameraBridge.faceOverlay = faceOverlay
        ArCameraBridge.previewView = previewView
        ArCameraBridge.warpGlView = warpGlView
        ArCameraBridge.confettiOverlay = confettiOverlay
        ArCameraBridge.platformRoot = root
        ArCameraBridge.hostActivity = activity
        ArCameraBridge.lifecycleOwner = activity
        activity.lifecycle.addObserver(lifecycleObserver)
        warpGlView.addOnLayoutChangeListener { _, left, top, right, bottom, _, _, _, _ ->
            ArCameraBridge.updateWarpViewSize(right - left, bottom - top)
        }

        // SurfaceView path — sharper live preview than TextureView (COMPATIBLE).
        previewView.implementationMode = PreviewView.ImplementationMode.PERFORMANCE
        previewView.scaleType = PreviewView.ScaleType.FILL_CENTER
        previewView.visibility = View.VISIBLE
        warpGlView.visibility = View.INVISIBLE

        warpGlView.ensureGlInitialized()

        // Screen-overlay filter animation (Confetti/Keywords/Snowfall/Snow White)
        // — decorative only, on top of the preview/beauty layers, never
        // intercepts touch. Hidden/stopped until one of those filters is
        // actually tapped in the picker — which asset loads and when it plays
        // is entirely driven from ArCameraBridge.applyRenderMode from then on.
        // NOT autoplayed/loaded on camera open. Wrapped so a bad/missing asset
        // or a Lottie failure can never take the camera down with it; a
        // failure listener is required too, since Lottie's async composition
        // loader rethrows parse errors on the main thread if nothing consumes
        // them — registering it here covers every setAnimation() call later.
        confettiOverlay.visibility = View.GONE
        confettiOverlay.repeatCount = LottieDrawable.INFINITE
        confettiOverlay.cancelAnimation()
        try {
            // These compositions are large full-screen 60fps animations (some
            // 3240x3240, hundreds of frames) drawn on top of the live camera
            // preview continuously. AUTOMATIC render mode can still pick the
            // software (Bitmap-backed) path on some devices/compositions,
            // which is expensive at that size every frame — force the
            // hardware-accelerated Canvas path, and let composition property
            // updates run off the main thread so the animation can't stall
            // camera/UI frame delivery.
            confettiOverlay.setRenderMode(RenderMode.HARDWARE)
            confettiOverlay.setAsyncUpdates(AsyncUpdates.ENABLED)
            confettiOverlay.setFailureListener { error ->
                android.util.Log.e("ArCamera", "screen overlay animation failed to load", error)
            }
        } catch (t: Throwable) {
            android.util.Log.e("ArCamera", "screen overlay setup failed", t)
        }

        // Pre-parse all screen-overlay compositions in the background right
        // now, while the user is still looking at Normal Mode — Lottie caches
        // the parsed LottieComposition in memory (LottieCompositionFactory),
        // so whichever one gets tapped first no longer pays the JSON-parse +
        // composition-build cost inline on the tap that switches to it. That
        // one-time build cost (large layer counts, see FilterType) is what
        // showed up as a hitch the first time a given overlay filter was used.
        try {
            FilterType.entries.forEach { type ->
                type.screenOverlayAsset()?.let { asset ->
                    LottieCompositionFactory.fromAsset(context, asset)
                }
            }
        } catch (t: Throwable) {
            android.util.Log.e("ArCamera", "screen overlay pre-warm failed", t)
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
        ArCameraController.stop()
        ArCameraBridge.clear()
    }
}
