part of face_detection_tflite;

/// Iris landmark model is intentionally omitted from this slim package.
class IrisLandmark {
  IrisLandmark._();

  static Future<IrisLandmark> create({
    InterpreterOptions? options,
    bool useIsolate = true,
  }) async {
    throw UnsupportedError(
      'iris_landmark.tflite was removed to shrink the APK. '
      'Use FaceDetectionMode.fast only.',
    );
  }

  static Future<IrisLandmark> createFromFile(
    String modelPath, {
    InterpreterOptions? options,
    bool useIsolate = true,
  }) async {
    throw UnsupportedError(
      'iris_landmark.tflite was removed to shrink the APK.',
    );
  }

  void dispose() {}
}
