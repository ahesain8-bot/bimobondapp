/// String enum constants aligned with Prisma (`schema-reference.md`).
///
/// Values are stored as [String] on entities so unknown API values never crash
/// the app. Use [isKnown] / [normalize] helpers when branching in the engine.
library;

abstract final class TemplateAssetTypes {
  static const video = 'VIDEO';
  static const image = 'IMAGE';
  static const audio = 'AUDIO';
  static const font = 'FONT';
  static const lut = 'LUT';
  static const sticker = 'STICKER';
  static const overlay = 'OVERLAY';
  static const other = 'OTHER';

  static const Set<String> known = {
    video,
    image,
    audio,
    font,
    lut,
    sticker,
    overlay,
    other,
  };

  /// Returns uppercased known value, or the original trimmed string if unknown.
  static String normalize(String? raw, {String fallback = other}) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return fallback;
    final u = s.toUpperCase();
    return known.contains(u) ? u : s;
  }

  static bool isKnown(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    return known.contains(raw.trim().toUpperCase());
  }
}

abstract final class TemplateTrackTypes {
  static const video = 'VIDEO';
  static const audio = 'AUDIO';
  static const text = 'TEXT';
  static const sticker = 'STICKER';
  static const overlay = 'OVERLAY';
  static const adjustment = 'ADJUSTMENT';

  static const Set<String> known = {
    video,
    audio,
    text,
    sticker,
    overlay,
    adjustment,
  };

  static String normalize(String? raw, {String fallback = video}) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return fallback;
    final u = s.toUpperCase();
    return known.contains(u) ? u : s;
  }

  static bool isKnown(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    return known.contains(raw.trim().toUpperCase());
  }
}

abstract final class TemplateClipSourceTypes {
  static const user = 'USER';
  static const stock = 'STOCK';
  static const templateBuiltin = 'TEMPLATE_BUILTIN';

  static const Set<String> known = {user, stock, templateBuiltin};

  static String normalize(String? raw, {String fallback = templateBuiltin}) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return fallback;
    final u = s.toUpperCase();
    return known.contains(u) ? u : s;
  }

  static bool isKnown(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    return known.contains(raw.trim().toUpperCase());
  }
}

abstract final class VideoTemplateStatuses {
  static const draft = 'DRAFT';
  static const review = 'REVIEW';
  static const published = 'PUBLISHED';
  static const archived = 'ARCHIVED';

  static const Set<String> known = {draft, review, published, archived};

  static String normalize(String? raw, {String fallback = published}) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return fallback;
    final u = s.toUpperCase();
    return known.contains(u) ? u : s;
  }

  static bool isKnown(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    return known.contains(raw.trim().toUpperCase());
  }
}

/// Keyframe easing tokens commonly used by the recipe; unknown values are kept.
abstract final class TemplateKeyframeEasings {
  static const linear = 'linear';
  static const easeIn = 'easeIn';
  static const easeOut = 'easeOut';
  static const easeInOut = 'easeInOut';

  static const Set<String> known = {linear, easeIn, easeOut, easeInOut};

  static String? normalizeNullable(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static bool isKnown(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    return known.contains(raw.trim());
  }
}
