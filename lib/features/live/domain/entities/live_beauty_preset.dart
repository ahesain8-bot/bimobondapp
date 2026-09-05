/// A named beauty look applied to the published live video.
///
/// Values map straight onto the native `BeautyParameters` the camera engine
/// already uses for the post camera, so a look tuned there behaves the same on
/// a broadcast. All fields are 0…1.
class LiveBeautyPreset {
  const LiveBeautyPreset({
    required this.id,
    required this.nameAr,
    this.smooth = 0,
    this.brighten = 0,
    this.tone = 0,
    this.sharpen = 0,
    this.eyes = 0,
  });

  final String id;
  final String nameAr;

  /// Edge-preserving skin smoothing, gated by the shader's skin probability.
  final double smooth;

  /// Opens the face without washing out the room.
  final double brighten;

  /// Warm, healthy skin tone.
  final double tone;

  /// Unsharp pass that puts back the detail smoothing takes.
  final double sharpen;

  /// Local lift and contrast inside the eye regions.
  final double eyes;

  bool get isActive =>
      smooth > 0.01 ||
      brighten > 0.01 ||
      tone > 0.01 ||
      sharpen > 0.01 ||
      eyes > 0.01;

  /// The look TikTok applies before the host picks anything.
  ///
  /// Deliberately light: a strong default reads as a plastic filter rather
  /// than a good camera, and hosts judge the app on the first frame they see.
  static const natural = LiveBeautyPreset(
    id: 'beauty_natural',
    nameAr: 'طبيعي',
    smooth: 0.32,
    brighten: 0.18,
    tone: 0.14,
    sharpen: 0.18,
    eyes: 0.10,
  );

  static const off = LiveBeautyPreset(id: 'beauty_off', nameAr: 'بدون');

  static const smoothLook = LiveBeautyPreset(
    id: 'beauty_smooth',
    nameAr: 'نعومة',
    smooth: 0.62,
    brighten: 0.22,
    tone: 0.18,
    sharpen: 0.10,
    eyes: 0.12,
  );

  static const glow = LiveBeautyPreset(
    id: 'beauty_glow',
    nameAr: 'إشراقة',
    smooth: 0.45,
    brighten: 0.42,
    tone: 0.30,
    sharpen: 0.16,
    eyes: 0.22,
  );

  static const fresh = LiveBeautyPreset(
    id: 'beauty_fresh',
    nameAr: 'نضارة',
    smooth: 0.38,
    brighten: 0.26,
    tone: 0.44,
    sharpen: 0.22,
    eyes: 0.18,
  );

  static const sharpLook = LiveBeautyPreset(
    id: 'beauty_sharp',
    nameAr: 'وضوح',
    smooth: 0.20,
    brighten: 0.14,
    tone: 0.10,
    sharpen: 0.55,
    eyes: 0.26,
  );

  /// Picker order — "off" first, then the default, then the stronger looks.
  static const List<LiveBeautyPreset> catalog = [
    off,
    natural,
    smoothLook,
    glow,
    fresh,
    sharpLook,
  ];

  static LiveBeautyPreset byId(String id) {
    for (final preset in catalog) {
      if (preset.id == id) return preset;
    }
    return natural;
  }
}
