/// Backend-backed live scene (`PATCH /lives/:id/scene`, live-p3-parity.md).
///
/// Flutter still owns capture and composition. [dualCameraEnabled] is only
/// complete when two visual sources are actually published/displayed.
class LiveScene {
  const LiveScene({
    this.scene = camera,
    this.cameraFacing = 'front',
    this.dualCameraEnabled = false,
  });

  static const camera = 'CAMERA';
  static const screen = 'SCREEN';
  static const dual = 'DUAL';

  /// `CAMERA` | `SCREEN` | `DUAL`.
  final String scene;

  /// `front` | `back`.
  final String cameraFacing;

  final bool dualCameraEnabled;

  bool get isCamera => scene == camera;
  bool get isScreen => scene == screen;
  bool get isDual => scene == dual || dualCameraEnabled;
  bool get isFront => cameraFacing.toLowerCase() != 'back';

  LiveScene copyWith({
    String? scene,
    String? cameraFacing,
    bool? dualCameraEnabled,
  }) {
    return LiveScene(
      scene: scene ?? this.scene,
      cameraFacing: cameraFacing ?? this.cameraFacing,
      dualCameraEnabled: dualCameraEnabled ?? this.dualCameraEnabled,
    );
  }

  Map<String, dynamic> toPatchBody() => {
    'scene': scene,
    'cameraFacing': cameraFacing,
    'dualCameraEnabled': dualCameraEnabled,
  };

  static LiveScene fromLiveJson(Map<String, dynamic> live) {
    final nested = _asMap(live['scene']);
    return LiveScene(
      scene: normalizeScene(nested?['scene'] ?? live['scene']),
      cameraFacing: normalizeFacing(
        nested?['cameraFacing'] ?? live['cameraFacing'],
      ),
      dualCameraEnabled:
          nested?['dualCameraEnabled'] == true ||
          live['dualCameraEnabled'] == true,
    );
  }

  static LiveScene fromSocket(Map<String, dynamic> payload) {
    final nested = _asMap(payload['scene']);
    return LiveScene(
      scene: normalizeScene(
        nested?['scene'] ?? payload['scene'],
      ),
      cameraFacing: normalizeFacing(
        nested?['cameraFacing'] ?? payload['cameraFacing'],
      ),
      dualCameraEnabled:
          nested?['dualCameraEnabled'] == true ||
          payload['dualCameraEnabled'] == true,
    );
  }

  static String normalizeScene(dynamic raw) {
    final value = raw?.toString().toUpperCase().trim();
    if (value == screen || value == dual) return value!;
    return camera;
  }

  static String normalizeFacing(dynamic raw) {
    final value = raw?.toString().toLowerCase().trim();
    if (value == 'back') return 'back';
    return 'front';
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
