part of face_detection_tflite;

/// Slim face detector: front-camera BlazeFace only (bbox + 6 keypoints).
/// Mesh and iris models are not included in the APK.
class FaceDetector {
  FaceDetection? _detector;

  bool get isReady => _detector != null;

  static ffi.DynamicLibrary? _tfliteLib;

  static Future<void> _ensureTFLiteLoaded() async {
    if (_tfliteLib != null) return;

    final exe = File(Platform.resolvedExecutable);
    final exeDir = exe.parent;

    late final List<String> candidates;
    late final String hint;

    if (Platform.isWindows) {
      candidates = [
        p.join(exeDir.path, 'libtensorflowlite_c-win.dll'),
        'libtensorflowlite_c-win.dll',
      ];
      hint =
          'Desktop TFLite binary is not bundled in this slim package.';
    } else if (Platform.isLinux) {
      candidates = [
        p.join(exeDir.path, 'lib', 'libtensorflowlite_c-linux.so'),
        'libtensorflowlite_c-linux.so',
      ];
      hint =
          'Desktop TFLite binary is not bundled in this slim package.';
    } else if (Platform.isMacOS) {
      final contents = exeDir.parent;
      candidates = [
        p.join(contents.path, 'Resources', 'libtensorflowlite_c-mac.dylib'),
        'libtensorflowlite_c-mac.dylib',
      ];
      hint = 'Desktop TFLite binary is not bundled in this slim package.';
    } else {
      // Android / iOS: TFLite is provided by tflite_flutter_custom natives.
      _tfliteLib = ffi.DynamicLibrary.process();
      return;
    }

    final tried = <String>[];
    for (final c in candidates) {
      try {
        if (c.contains(p.separator)) {
          if (!File(c).existsSync()) {
            tried.add(c);
            continue;
          }
        }
        _tfliteLib = ffi.DynamicLibrary.open(c);
        return;
      } catch (_) {
        tried.add(c);
      }
    }

    throw ArgumentError(
      'Failed to locate TensorFlow Lite C library.\n'
      'Tried:\n - ${tried.join('\n - ')}\n\n$hint',
    );
  }

  Future<void> initialize({
    FaceDetectionModel model = FaceDetectionModel.frontCamera,
    InterpreterOptions? options,
  }) async {
    await _ensureTFLiteLoaded();
    try {
      _detector = await FaceDetection.create(
        model,
        options: options,
        useIsolate: true,
      );
    } catch (e) {
      _detector?.dispose();
      _detector = null;
      rethrow;
    }
  }

  Future<List<Detection>> _detectDetections(
    Uint8List imageBytes, {
    RectF? roi,
  }) async {
    final d = _detector;
    if (d == null) {
      throw StateError(
        'FaceDetector not initialized. Call initialize() first.',
      );
    }

    final decodedInfo = await _decodeImageOffUi(imageBytes);
    final dets = await d.call(imageBytes, roi: roi);
    if (dets.isEmpty) return dets;

    final imgW = decodedInfo.width.toDouble();
    final imgH = decodedInfo.height.toDouble();
    return dets
        .map(
          (det) => Detection(
            bbox: det.bbox,
            score: det.score,
            keypointsXY: det.keypointsXY,
            imageSize: Size(imgW, imgH),
          ),
        )
        .toList(growable: false);
  }

  Future<PipelineResult> detectFaces(
    Uint8List imageBytes, {
    FaceDetectionMode mode = FaceDetectionMode.fast,
    RectF? roi,
  }) async {
    // Mesh / iris modes are unsupported in this slim package; always use
    // detector keypoints (equivalent to FaceDetectionMode.fast).
    final decodedInfo = await _decodeImageOffUi(imageBytes);
    final imgSize = Size(
      decodedInfo.width.toDouble(),
      decodedInfo.height.toDouble(),
    );
    final dets = await _detectDetections(imageBytes, roi: roi);

    final faces = dets
        .map(
          (det) => FaceResult(
            detection: det,
            mesh: const <math.Point<double>>[],
            irises: const <math.Point<double>>[],
            originalSize: imgSize,
          ),
        )
        .toList(growable: false);

    return PipelineResult(faces: faces, originalSize: imgSize);
  }

  void dispose() {
    _detector?.dispose();
    _detector = null;
  }
}
