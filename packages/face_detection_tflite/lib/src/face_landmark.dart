part of face_detection_tflite;

/// Landmark mesh model is intentionally omitted from this slim package.
class FaceLandmark {
  FaceLandmark._();

  static Future<FaceLandmark> create({
    InterpreterOptions? options,
    bool useIsolate = true,
  }) async {
    throw UnsupportedError(
      'face_landmark.tflite was removed to shrink the APK. '
      'Use FaceDetectionMode.fast only.',
    );
  }

  void dispose() {}
}
