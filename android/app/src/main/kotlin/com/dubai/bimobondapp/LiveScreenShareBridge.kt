package com.dubai.bimobondapp

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

internal object LiveScreenShareBridge {
    const val CHANNEL = "com.dubai.bimobondapp/live_screen_share"

    fun register(flutterEngine: FlutterEngine, activity: MainActivity) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            LiveScreenShareService.start(activity.applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SCREEN_SHARE_FGS", e.message, null)
                        }
                    }
                    "stop" -> {
                        try {
                            LiveScreenShareService.stop(activity.applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SCREEN_SHARE_FGS", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
