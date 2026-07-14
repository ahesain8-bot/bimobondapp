package com.dubai.bimobondapp.ar_camera

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ArCameraPlatformViewFactory(
    private val activity: FlutterActivity,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return ArCameraPlatformView(context, activity)
    }
}