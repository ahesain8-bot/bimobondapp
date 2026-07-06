package com.dubai.bimobondapp

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        try {
            GeneratedPluginRegistrant.registerWith(flutterEngine)
        } catch (t: Throwable) {
            // FFmpegKit throws Error (not Exception) on 16 KB page-size emulators,
            // aborting registration before Firebase and later plugins are loaded.
            Log.e(TAG, "Plugin registration aborted; registering remaining plugins", t)
            RemainingPluginRegistrant.registerWith(flutterEngine)
        }
    }

    companion object {
        private const val TAG = "MainActivity"
    }
}
