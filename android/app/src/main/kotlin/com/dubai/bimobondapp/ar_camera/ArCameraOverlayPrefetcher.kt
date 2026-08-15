package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.util.Log
import com.airbnb.lottie.LottieCompositionFactory

/**
 * Warms Lottie / MP4 caches for the published screen overlays.
 *
 * Called from Dart right after `/camera-studio/ar-overlays` resolves (see
 * `ArCameraBridge.prefetchOverlays`), because only Dart knows which animations
 * are currently published — the native side no longer carries a list of its own.
 *
 * [LottieCompositionFactory] is doing the real work for JSON overlays: it
 * keeps parsed compositions in an in-memory LRU keyed by the URL/asset, and for
 * network sources it also writes the downloaded file to its own disk cache. So
 * this both avoids the first-tap download AND the first-tap JSON parse, and is
 * cheap to call again — an already-cached composition resolves immediately.
 *
 * Video overlays are prefetched via [ScreenOverlayVideoCache].
 */
object ArCameraOverlayPrefetcher {

    fun prefetch(
        context: Context,
        lottieUrls: List<String>,
        videoUrls: List<String>,
        assets: List<String>,
    ) {
        val appContext = context.applicationContext
        ScreenOverlayVideoCache.prefetch(appContext, videoUrls)
        for (url in lottieUrls) {
            if (url.isBlank()) continue
            try {
                // Async by contract; failures are delivered to the listener
                // rather than thrown, and a failed prefetch only costs a slower
                // first tap.
                LottieNetworkLoader.loadFromUrl(appContext, url, url)
                    .addFailureListener { t ->
                        Log.w(TAG, "overlay prefetch failed: $url", t)
                    }
            } catch (t: Throwable) {
                Log.w(TAG, "overlay prefetch threw: $url", t)
            }
        }
        for (asset in assets) {
            if (asset.isBlank()) continue
            try {
                LottieCompositionFactory.fromAsset(appContext, asset)
                    .addFailureListener { t ->
                        Log.w(TAG, "overlay asset prefetch failed: $asset", t)
                    }
            } catch (t: Throwable) {
                Log.w(TAG, "overlay asset prefetch threw: $asset", t)
            }
        }
    }

    private const val TAG = "ArCameraOverlay"
}
