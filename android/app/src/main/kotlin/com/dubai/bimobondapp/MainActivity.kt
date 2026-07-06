package com.dubai.bimobondapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        SafePluginRegistrant.registerWith(flutterEngine)
    }
}
