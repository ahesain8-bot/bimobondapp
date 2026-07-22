enum CameraStudioMode { photo, video, live }

class CameraZoomStep {
  const CameraZoomStep({required this.label, required this.value});

  final String label;
  final double value;
}

class CameraStudioConstants {
  CameraStudioConstants._();

  static const zoomSteps = [
    CameraZoomStep(label: '0.5x', value: 0.0),
    CameraZoomStep(label: '1x', value: 0.18),
    CameraZoomStep(label: '2x', value: 0.45),
    CameraZoomStep(label: '3x', value: 0.72),
  ];

  static const durationOptions = [15, 60, 180];
  static const speedOptions = [0.3, 0.5, 1.0, 2.0, 3.0];
  static const studioModes = [
    CameraStudioMode.photo,
    CameraStudioMode.video,
    CameraStudioMode.live,
  ];

  static const storyStudioModes = [
    CameraStudioMode.photo,
    CameraStudioMode.video,
  ];
}
