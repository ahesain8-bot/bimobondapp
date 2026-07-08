import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

Completer<void>? _mapsInitCompleter;

/// Initializes the Android map renderer before any [GoogleMap] is created.
Future<void> configureGoogleMaps() async {
  if (kIsWeb) return;

  if (_mapsInitCompleter != null) {
    return _mapsInitCompleter!.future;
  }

  final completer = Completer<void>();
  _mapsInitCompleter = completer;

  WidgetsFlutterBinding.ensureInitialized();

  final platform = GoogleMapsFlutterPlatform.instance;
  if (platform is GoogleMapsFlutterAndroid) {
    try {
      await platform.initializeWithRenderer(AndroidMapRenderer.latest);
      await platform.warmup();
    } catch (_) {
      // Renderer can only be initialized once per process.
    }
  }

  completer.complete();
}
