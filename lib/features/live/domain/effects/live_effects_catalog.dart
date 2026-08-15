import '../entities/live_effect.dart';

/// Built-in live effects catalog (no remote fetch yet).
class LiveEffectsCatalog {
  const LiveEffectsCatalog._();

  static const String categoryTrending = 'trending';
  static const String categorySports = 'sports';
  static const String categoryNew = 'new';
  static const String categoryScreen = 'screen';

  static const List<LiveEffectCategory> categories = [
    LiveEffectCategory(id: categoryTrending, labelAr: 'متصدر'),
    LiveEffectCategory(id: categorySports, labelAr: 'الرياضة'),
    LiveEffectCategory(id: categoryNew, labelAr: 'جديد'),
    LiveEffectCategory(id: categoryScreen, labelAr: 'الشاشة'),
  ];

  static const LiveEffect none = LiveEffect(
    id: 'none',
    nameAr: 'بدون',
    kind: LiveEffectKind.none,
    categoryId: categoryTrending,
    isClear: true,
  );

  static const List<LiveEffect> all = [
    none,
    // Trending — landmark-driven AR
    LiveEffect(
      id: 'sunglasses',
      nameAr: 'نظارة عصرية',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categoryTrending,
    ),
    LiveEffect(
      id: 'cat_ears',
      nameAr: 'أذن قطة',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categoryTrending,
    ),
    LiveEffect(
      id: 'bunny_ears',
      nameAr: 'أذن أرنب',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categoryTrending,
    ),
    LiveEffect(
      id: 'crown',
      nameAr: 'تاج',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categorySports,
    ),
    LiveEffect(
      id: 'hearts',
      nameAr: 'قلوب',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categoryTrending,
    ),
    LiveEffect(
      id: 'stars',
      nameAr: 'نجوم',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categoryTrending,
    ),
    LiveEffect(
      id: 'sparkles',
      nameAr: 'لمعان',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categoryTrending,
    ),
    // Beauty / makeup
    LiveEffect(
      id: 'soft_skin',
      nameAr: 'بشرة ناعمة',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categoryNew,
    ),
    LiveEffect(
      id: 'blush',
      nameAr: 'خدود',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categoryNew,
    ),
    LiveEffect(
      id: 'cute_cheeks',
      nameAr: 'خدود لطيفة',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categoryNew,
    ),
    LiveEffect(
      id: 'subtle_makeup',
      nameAr: 'مكياج خفيف',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categoryNew,
    ),
    // Color grades
    LiveEffect(
      id: 'warm_glow',
      nameAr: 'توهج دافئ',
      kind: LiveEffectKind.colorGrade,
      categoryId: categoryNew,
    ),
    LiveEffect(
      id: 'cool_tone',
      nameAr: 'تدرج بارد',
      kind: LiveEffectKind.colorGrade,
      categoryId: categoryNew,
    ),
    LiveEffect(
      id: 'fresh',
      nameAr: 'إطلالة منعشة',
      kind: LiveEffectKind.colorGrade,
      categoryId: categoryTrending,
    ),
    LiveEffect(
      id: 'natural_beauty',
      nameAr: 'جمال طبيعي',
      kind: LiveEffectKind.colorGrade,
      categoryId: categoryNew,
    ),
    // Screen
    LiveEffect(
      id: 'virtual_bg',
      nameAr: 'خلفية خضراء',
      kind: LiveEffectKind.virtualBackground,
      categoryId: categoryScreen,
    ),
    LiveEffect(
      id: 'face_glow',
      nameAr: 'إضاءة وجه',
      kind: LiveEffectKind.faceOverlay,
      categoryId: categorySports,
    ),
  ];

  static LiveEffect byId(String id) {
    for (final effect in all) {
      if (effect.id == id) return effect;
    }
    return none;
  }

  static List<LiveEffect> byCategory(String categoryId) {
    return all
        .where(
          (e) =>
              e.categoryId == categoryId ||
              (e.isClear && categoryId == categoryTrending),
        )
        .toList(growable: false);
  }

  /// Compact tray order — tracking demos first.
  static List<LiveEffect> get trayEffects {
    const order = [
      'sunglasses',
      'cat_ears',
      'bunny_ears',
      'crown',
      'blush',
      'none',
      'hearts',
      'sparkles',
      'soft_skin',
      'warm_glow',
      'cool_tone',
      'virtual_bg',
    ];
    return [
      for (final id in order) byId(id),
    ];
  }
}
