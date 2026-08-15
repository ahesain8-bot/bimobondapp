/// Normalized effect model sent from Flutter to native Android.
class EffectDefinition {
  final String id;
  final String type;
  final String? assetUrl;
  final String? assetName;
  final int durationMs;
  final bool loop;
  final int startTimeMs;
  final int endTimeMs;
  final double opacity;
  final double scale;
  final double positionX;
  final double positionY;
  final double rotation;
  final String blendMode;

  const EffectDefinition({
    required this.id,
    this.type = 'screen_overlay',
    this.assetUrl,
    this.assetName,
    this.durationMs = 0,
    this.loop = true,
    this.startTimeMs = 0,
    this.endTimeMs = 0,
    this.opacity = 1.0,
    this.scale = 1.0,
    this.positionX = 0.5,
    this.positionY = 0.5,
    this.rotation = 0.0,
    this.blendMode = 'normal',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'assetUrl': assetUrl,
        'assetName': assetName,
        'durationMs': durationMs,
        'loop': loop,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'opacity': opacity,
        'scale': scale,
        'positionX': positionX,
        'positionY': positionY,
        'rotation': rotation,
        'blendMode': blendMode,
      };
}
