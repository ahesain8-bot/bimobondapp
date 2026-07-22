import 'dart:convert';

// ---------------------------------------------------------------------------
// AR FACE EFFECTS CATALOG — Backend API Contract + App Model
// ---------------------------------------------------------------------------
//
// Full spec (send to backend): docs/backend-ar-camera-api.md
//
// ENDPOINT
//   GET /camera-studio/ar-effects
//   Optional wrapper: { "data": { …catalog… } }
//   Offline fallback in app: [ArEffectCatalog.bundled]
//
// WHAT THIS POWERS
//   The bottom sticker carousel in the AR camera (glasses, dog, mask, big eyes…)
//   NOT the color Filters panel — that is ar_color_filter_catalog_model.dart.
//
// ── BACKEND: HOW TO ADD AN EFFECT ───────────────────────────────────────────
//
//   1. Choose renderType (see below): sticker | composite | distortion | none
//   2. Set a unique `id` (snake_case) — MUST match native FilterType ids in app
//   3. Set label, sortOrder, emoji, thumbnailUrl
//   4. sticker    → upload transparent PNG + provide anchor config (or copy preset)
//   5. composite  → upload multiple PNGs in stickers[] (dog = 3 layers)
//   6. distortion → NO file upload; set distortionPreset only
//   7. Bump catalog `version` whenever content changes
//
// ── RENDER TYPE: "none" ─────────────────────────────────────────────────────
//
//   The "Original" slot — clears all effects. No assets required.
//
// ── RENDER TYPE: "sticker" ───────────────────────────────────────────────────
//
//   Use for: glasses, shades, moustache, mask (single PNG overlay on face)
//
//   REQUIRED:
//     renderType: "sticker"
//     assetUrl:   HTTPS URL to transparent PNG on CDN
//     anchor:     { … } face placement recipe (see anchor fields below)
//
//   OPTIONAL:
//     assetAsset: bundled filename for offline, e.g. "glasses_round.png"
//
//   PNG UPLOAD RULES:
//     • Format: PNG with transparent background (alpha channel required)
//     • Size: 512–1024 px (content-dependent)
//     • Filename: lowercase_snake_case.png
//     • thumbnailUrl: separate small image for carousel icon (optional; emoji fallback)
//
// ── RENDER TYPE: "composite" ─────────────────────────────────────────────────
//
//   Use for: dog filter (ears + nose + tongue stacked in one effect)
//
//   REQUIRED:
//     renderType: "composite"
//     stickers: [ { assetUrl, anchor }, { assetUrl, anchor }, … ]
//
//   Each layer in stickers[] is drawn in array order (back → front).
//
// ── RENDER TYPE: "distortion" ────────────────────────────────────────────────
//
//   Use for: big_eyes, big_lips, long_nose (GPU face-warp shader)
//
//   REQUIRED:
//     renderType: "distortion"
//     distortionPreset: "big_eyes" | "big_lips" | "long_nose"
//
//   NO PNG UPLOAD — dashboard should hide file upload for this type.
//
// ── ANCHOR CONFIG (sticker / composite layers) ───────────────────────────────
//
//   Tells the app where to pin the PNG on the face (MediaPipe 468-point mesh).
//
//   Common landmark indices:
//     33  = left eye outer corner     263 = right eye outer corner
//     168 = nose bridge               1   = nose tip
//     152 = chin                      10  = forehead
//     61  = mouth left                291 = mouth right
//     17  = mouth bottom              234 = left cheek
//     454 = right cheek
//
//   pinX allowed values:
//     ref_midpoint | anchor | nose_bridge | mouth_midpoint | eye_midpoint
//
//   pinY allowed values:
//     anchor | ref_midline | eye_line | nose_mouth_blend | top_head_offset
//
//   Key sizing fields (use ONE primary width strategy):
//     widthScreenMult   float  width = eyeDistance × this (glasses ≈ 3.5)
//     widthFaceFrac     float  width = faceWidth × this (dog ears ≈ 1.05)
//     widthMinFaceFrac  float  minimum width as fraction of face width
//
//   Pivot (where PNG attaches to anchor point, 0..1 within image):
//     pivotU, pivotV  — e.g. glasses center = (0.5, 0.5)
//
//   Dashboard tip: copy anchor from [ArEffectCatalog.bundled] for known presets.
//   For brand-new stickers, coordinate with the mobile team before publishing.
//
// ── EXAMPLE: sticker (glasses) ───────────────────────────────────────────────
//
// {
//   "id": "glasses",
//   "label": "Glasses",
//   "renderType": "sticker",
//   "sortOrder": 1,
//   "emoji": "😎",
//   "thumbnailUrl": "https://cdn.example.com/thumbs/glasses.jpg",
//   "assetUrl": "https://cdn.example.com/stickers/glasses_round.png",
//   "assetAsset": "glasses_round.png",
//   "anchor": {
//     "leftLandmark": 33,
//     "rightLandmark": 263,
//     "anchorLandmark": 168,
//     "pinX": "nose_bridge",
//     "pinY": "eye_line",
//     "widthScreenMult": 3.5,
//     "widthMinFaceFrac": 0.70,
//     "pivotU": 0.5,
//     "pivotV": 0.5,
//     "useAveragedEyes": true
//   }
// }
//
// ── EXAMPLE: composite (dog) ─────────────────────────────────────────────────
//
// {
//   "id": "dog",
//   "label": "Dog",
//   "renderType": "composite",
//   "sortOrder": 3,
//   "emoji": "🐶",
//   "stickers": [
//     {
//       "assetUrl": "https://cdn.example.com/stickers/filter_ears.png",
//       "assetAsset": "filter_ears.png",
//       "anchor": { "pinY": "top_head_offset", "widthFaceFrac": 1.05, … }
//     },
//     {
//       "assetUrl": "https://cdn.example.com/stickers/filter_nose.png",
//       "assetAsset": "filter_nose.png",
//       "anchor": { "pivotU": 0.305, "pivotV": 0.154, … }
//     },
//     {
//       "assetUrl": "https://cdn.example.com/stickers/filter_tongue.png",
//       "assetAsset": "filter_tongue.png",
//       "anchor": { … }
//     }
//   ]
// }
//
// ── EXAMPLE: distortion (big eyes) ─────────────────────────────────────────
//
// {
//   "id": "big_eyes",
//   "label": "Big Eyes",
//   "renderType": "distortion",
//   "sortOrder": 6,
//   "emoji": "👀",
//   "distortionPreset": "big_eyes"
// }
//
// ── TOP-LEVEL RESPONSE ───────────────────────────────────────────────────────
//
// {
//   "version": "2026-07-20T01",
//   "effectCategories": [
//     {
//       "id": "carousel",
//       "label": "Effects",
//       "sortOrder": 0,
//       "effects": [ … ]
//     }
//   ]
// }
//
// ── VALIDATION RULES ─────────────────────────────────────────────────────────
//
//   • sticker    → assetUrl OR assetAsset required + anchor object required
//   • composite  → stickers[] required, each layer needs asset + anchor
//   • distortion → distortionPreset must be big_eyes | big_lips | long_nose
//   • id         → do NOT rename existing ids without an app release
//
// ── FILES TO UPLOAD (current app stickers — 7 PNGs) ──────────────────────────
//
//   glasses_round.png, glasses_aviator.png, filter_moustache.png,
//   filter_skull_mask.png, filter_ears.png, filter_nose.png, filter_tongue.png
//   (from android/app/src/main/res/drawable/)
//
// ── SEED DATA ────────────────────────────────────────────────────────────────
//
//   [ArEffectCatalog.bundled] below = exact carousel the app ships today.
//   Use it as reference when seeding the database.
// ---------------------------------------------------------------------------

/// Carousel effect engine type.
enum ArEffectRenderType {
  /// Original / no effect — UI metadata only, nothing applied to the camera.
  none,

  /// Single transparent PNG sticker.
  sticker,

  /// Multiple PNG layers (dog filter).
  composite,

  /// GPU face-warp — no PNG upload.
  distortion;

  static ArEffectRenderType fromJson(dynamic raw) {
    final s = raw?.toString().toLowerCase().trim();
    return switch (s) {
      'sticker' => ArEffectRenderType.sticker,
      'composite' => ArEffectRenderType.composite,
      'distortion' => ArEffectRenderType.distortion,
      _ => ArEffectRenderType.none,
    };
  }

  String toJson() => name;
}

/// Built-in distortion presets (native shader).
abstract final class ArEffectDistortionPreset {
  static const bigEyes = 'big_eyes';
  static const bigLips = 'big_lips';
  static const longNose = 'long_nose';

  static const all = [bigEyes, bigLips, longNose];
}

class ArEffectCatalog {
  const ArEffectCatalog({
    required this.version,
    required this.categories,
  });

  final String version;
  final List<ArEffectCategoryModel> categories;

  /// Flat list of all effects (carousel order preserved per category sort).
  List<ArEffectItemModel> get allEffects {
    final out = <ArEffectItemModel>[];
    final cats = List<ArEffectCategoryModel>.from(categories)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final cat in cats) {
      final fx = List<ArEffectItemModel>.from(cat.effects)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      out.addAll(fx);
    }
    return out;
  }

  ArEffectItemModel? findEffect(String id) {
    for (final effect in allEffects) {
      if (effect.id == id) return effect;
    }
    return null;
  }

  factory ArEffectCatalog.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return ArEffectCatalog.fromJson(data);
    }

    final raw = json['effectCategories'];
    final categories = raw is List
        ? raw
            .whereType<Map>()
            .map(
              (e) => ArEffectCategoryModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false)
        : const <ArEffectCategoryModel>[];

    return ArEffectCatalog(
      version: json['version']?.toString() ?? 'bundled',
      categories: categories,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'effectCategories':
            categories.map((c) => c.toJson()).toList(growable: false),
      };

  String encode() => jsonEncode(toJson());

  static ArEffectCatalog decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return ArEffectCatalog.fromJson(Map<String, dynamic>.from(decoded));
    }
    throw const FormatException('Invalid AR effect catalog');
  }

  /// Offline fallback — same carousel effects the app ships in the current release.
  static ArEffectCatalog bundled() {
    return ArEffectCatalog(
      version: 'bundled',
      categories: [
        ArEffectCategoryModel(
          id: 'carousel',
          label: 'Effects',
          sortOrder: 0,
          effects: [
            const ArEffectItemModel(
              id: 'none',
              label: 'Original',
              renderType: ArEffectRenderType.none,
              emoji: '✨',
              sortOrder: 0,
            ),
            const ArEffectItemModel(
              id: 'glasses',
              label: 'Glasses',
              renderType: ArEffectRenderType.sticker,
              emoji: '😎',
              sortOrder: 1,
              assetAsset: 'glasses_round.png',
              anchor: ArStickerAnchorModel(
                leftLandmark: 33,
                rightLandmark: 263,
                anchorLandmark: 168,
                pinX: 'nose_bridge',
                pinY: 'eye_line',
                widthScreenMult: 3.5,
                widthMinFaceFrac: 0.70,
                pivotU: 0.5,
                pivotV: 0.5,
                useAveragedEyes: true,
              ),
            ),
            const ArEffectItemModel(
              id: 'shades',
              label: 'Shades',
              renderType: ArEffectRenderType.sticker,
              emoji: '🕶️',
              sortOrder: 2,
              assetAsset: 'glasses_aviator.png',
              anchor: ArStickerAnchorModel(
                leftLandmark: 33,
                rightLandmark: 263,
                anchorLandmark: 168,
                pinX: 'nose_bridge',
                pinY: 'eye_line',
                widthScreenMult: 3.5,
                widthMinFaceFrac: 0.70,
                pivotU: 0.5,
                pivotV: 0.48,
                useAveragedEyes: true,
              ),
            ),
            ArEffectItemModel(
              id: 'dog',
              label: 'Dog',
              renderType: ArEffectRenderType.composite,
              emoji: '🐶',
              sortOrder: 3,
              stickers: [
                const ArEffectStickerLayerModel(
                  assetAsset: 'filter_ears.png',
                  anchor: ArStickerAnchorModel(
                    leftLandmark: 33,
                    rightLandmark: 263,
                    anchorLandmark: 10,
                    pinX: 'eye_midpoint',
                    pinY: 'top_head_offset',
                    offsetYFaceFrac: -0.18,
                    widthFaceFrac: 1.05,
                    pivotU: 0.5,
                    pivotV: 0.75,
                    yawSqueeze: 0.18,
                    useAveragedEyes: true,
                  ),
                ),
                const ArEffectStickerLayerModel(
                  assetAsset: 'filter_nose.png',
                  anchor: ArStickerAnchorModel(
                    leftLandmark: 33,
                    rightLandmark: 263,
                    anchorLandmark: 1,
                    pinX: 'anchor',
                    pinY: 'anchor',
                    widthScreenMult: 1.1,
                    pivotU: 0.305,
                    pivotV: 0.154,
                    yawSqueeze: 0.15,
                    useAveragedEyes: true,
                  ),
                ),
                const ArEffectStickerLayerModel(
                  assetAsset: 'filter_tongue.png',
                  anchor: ArStickerAnchorModel(
                    leftLandmark: 61,
                    rightLandmark: 291,
                    anchorLandmark: 17,
                    pinX: 'mouth_midpoint',
                    pinY: 'anchor',
                    offsetYFaceFrac: 0.04,
                    widthScreenMult: 1.25,
                    pivotU: 0.333,
                    pivotV: 0.0,
                    yawSqueeze: 0.12,
                    useAveragedEyes: true,
                  ),
                ),
              ],
            ),
            const ArEffectItemModel(
              id: 'moustache',
              label: 'Moustache',
              renderType: ArEffectRenderType.sticker,
              emoji: '🥸',
              sortOrder: 4,
              assetAsset: 'filter_moustache.png',
              anchor: ArStickerAnchorModel(
                leftLandmark: 61,
                rightLandmark: 291,
                anchorLandmark: 1,
                pinX: 'ref_midpoint',
                pinY: 'nose_mouth_blend',
                widthScreenMult: 1.9,
                widthMinFaceFrac: 0.48,
                pivotU: 0.5,
                pivotV: 0.45,
              ),
            ),
            const ArEffectItemModel(
              id: 'mask',
              label: 'Mask',
              renderType: ArEffectRenderType.sticker,
              emoji: '💀',
              sortOrder: 5,
              assetAsset: 'filter_skull_mask.png',
              anchor: ArStickerAnchorModel(
                leftLandmark: 234,
                rightLandmark: 454,
                anchorLandmark: 1,
                offsetYFaceFrac: 0.02,
                pinX: 'ref_midpoint',
                pinY: 'anchor',
                widthScreenMult: 1.40,
                widthMinFaceFrac: 1.05,
                pivotU: 0.50,
                pivotV: 0.30,
                scaleFromFaceBox: true,
                heightSpanFrac: 0.42,
                heightAnchorTopLandmark: 1,
                heightAnchorBottomLandmark: 152,
              ),
            ),
            const ArEffectItemModel(
              id: 'big_eyes',
              label: 'Big Eyes',
              renderType: ArEffectRenderType.distortion,
              emoji: '👀',
              sortOrder: 6,
              distortionPreset: ArEffectDistortionPreset.bigEyes,
            ),
            const ArEffectItemModel(
              id: 'big_lips',
              label: 'Big Lips',
              renderType: ArEffectRenderType.distortion,
              emoji: '👄',
              sortOrder: 7,
              distortionPreset: ArEffectDistortionPreset.bigLips,
            ),
            const ArEffectItemModel(
              id: 'long_nose',
              label: 'Nose',
              renderType: ArEffectRenderType.distortion,
              emoji: '👃',
              sortOrder: 8,
              distortionPreset: ArEffectDistortionPreset.longNose,
            ),
          ],
        ),
      ],
    );
  }
}

class ArEffectCategoryModel {
  const ArEffectCategoryModel({
    required this.id,
    required this.label,
    required this.sortOrder,
    required this.effects,
  });

  final String id;
  final String label;
  final int sortOrder;
  final List<ArEffectItemModel> effects;

  factory ArEffectCategoryModel.fromJson(Map<String, dynamic> json) {
    final raw = json['effects'];
    final effects = raw is List
        ? raw
            .whereType<Map>()
            .map(
              (e) => ArEffectItemModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false)
        : const <ArEffectItemModel>[];

    return ArEffectCategoryModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      sortOrder: _readInt(json['sortOrder']),
      effects: effects,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'sortOrder': sortOrder,
        'effects': effects.map((e) => e.toJson()).toList(growable: false),
      };
}

class ArEffectItemModel {
  const ArEffectItemModel({
    required this.id,
    required this.label,
    this.renderType = ArEffectRenderType.none,
    this.thumbnailUrl,
    this.emoji,
    this.previewColorHex,
    this.sortOrder = 0,
    this.assetUrl,
    this.assetAsset,
    this.anchor,
    this.stickers,
    this.distortionPreset,
  });

  final String id;
  final String label;
  final ArEffectRenderType renderType;

  /// Carousel thumbnail (JPG/PNG icon) — sticker PNG se alag.
  final String? thumbnailUrl;
  final String? emoji;
  final String? previewColorHex;
  final int sortOrder;

  /// CDN URL to the sticker PNG (online).
  final String? assetUrl;

  /// Bundled filename for offline, e.g. `glasses_round.png`.
  final String? assetAsset;

  /// Face placement recipe — required for [ArEffectRenderType.sticker].
  final ArStickerAnchorModel? anchor;

  /// Layers for [ArEffectRenderType.composite] (dog filter).
  final List<ArEffectStickerLayerModel>? stickers;

  /// One of [ArEffectDistortionPreset] for [ArEffectRenderType.distortion].
  final String? distortionPreset;

  bool get isNone => renderType == ArEffectRenderType.none || id == 'none';
  bool get isSticker => renderType == ArEffectRenderType.sticker;
  bool get isComposite => renderType == ArEffectRenderType.composite;
  bool get isDistortion => renderType == ArEffectRenderType.distortion;

  bool get hasValidSticker =>
      isSticker &&
      _hasAsset(assetUrl, assetAsset) &&
      anchor != null;

  bool get hasValidComposite =>
      isComposite &&
      stickers != null &&
      stickers!.isNotEmpty &&
      stickers!.every((s) => s.hasValidAsset);

  bool get hasValidDistortion =>
      isDistortion &&
      distortionPreset != null &&
      ArEffectDistortionPreset.all.contains(distortionPreset);

  /// Resolved sticker PNG: CDN first, then bundled filename.
  String? get effectiveAssetSource {
    if (!isSticker) return null;
    return _resolveAsset(assetUrl, assetAsset);
  }

  factory ArEffectItemModel.fromJson(Map<String, dynamic> json) {
    final stickersRaw = json['stickers'];
    final stickers = stickersRaw is List
        ? stickersRaw
            .whereType<Map>()
            .map(
              (e) => ArEffectStickerLayerModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false)
        : null;

    final anchorRaw = json['anchor'];
    final anchor = anchorRaw is Map
        ? ArStickerAnchorModel.fromJson(
            Map<String, dynamic>.from(anchorRaw),
          )
        : null;

    var renderType = json.containsKey('renderType')
        ? ArEffectRenderType.fromJson(json['renderType'])
        : _inferRenderType(
            stickers: stickers,
            anchor: anchor,
            distortionPreset: json['distortionPreset']?.toString(),
            assetUrl: json['assetUrl']?.toString(),
            assetAsset: json['assetAsset']?.toString(),
          );

    return ArEffectItemModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      renderType: renderType,
      thumbnailUrl: _readOptionalString(json['thumbnailUrl']),
      emoji: _readOptionalString(json['emoji']),
      previewColorHex: _readOptionalString(json['previewColorHex']),
      sortOrder: _readInt(json['sortOrder']),
      assetUrl: _readOptionalString(json['assetUrl']),
      assetAsset: _readOptionalString(json['assetAsset']),
      anchor: anchor,
      stickers: stickers,
      distortionPreset: _readOptionalString(json['distortionPreset']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'renderType': renderType.toJson(),
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (emoji != null) 'emoji': emoji,
        if (previewColorHex != null) 'previewColorHex': previewColorHex,
        'sortOrder': sortOrder,
        if (isSticker && assetUrl != null) 'assetUrl': assetUrl,
        if (isSticker && assetAsset != null) 'assetAsset': assetAsset,
        if (isSticker && anchor != null) 'anchor': anchor!.toJson(),
        if (isComposite && stickers != null)
          'stickers': stickers!.map((s) => s.toJson()).toList(growable: false),
        if (isDistortion && distortionPreset != null)
          'distortionPreset': distortionPreset,
      };
}

/// One PNG layer inside a [ArEffectRenderType.composite] effect.
class ArEffectStickerLayerModel {
  const ArEffectStickerLayerModel({
    this.id,
    this.assetUrl,
    this.assetAsset,
    required this.anchor,
  });

  final String? id;
  final String? assetUrl;
  final String? assetAsset;
  final ArStickerAnchorModel anchor;

  bool get hasValidAsset => _hasAsset(assetUrl, assetAsset);

  String? get effectiveAssetSource => _resolveAsset(assetUrl, assetAsset);

  factory ArEffectStickerLayerModel.fromJson(Map<String, dynamic> json) {
    final anchorRaw = json['anchor'];
    return ArEffectStickerLayerModel(
      id: _readOptionalString(json['id']),
      assetUrl: _readOptionalString(json['assetUrl']),
      assetAsset: _readOptionalString(json['assetAsset']),
      anchor: anchorRaw is Map
          ? ArStickerAnchorModel.fromJson(
              Map<String, dynamic>.from(anchorRaw),
            )
          : const ArStickerAnchorModel(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (assetUrl != null) 'assetUrl': assetUrl,
        if (assetAsset != null) 'assetAsset': assetAsset,
        'anchor': anchor.toJson(),
      };
}

/// Face placement recipe — mirrors native [StickerAnchorConfig] in Kotlin.
class ArStickerAnchorModel {
  const ArStickerAnchorModel({
    this.leftLandmark = 33,
    this.rightLandmark = 263,
    this.anchorLandmark = 168,
    this.secondaryAnchorLandmark = -1,
    this.secondaryBlendY = 0,
    this.offsetYFaceFrac = 0,
    this.offsetXFaceFrac = 0,
    this.widthOverRef = 2.4,
    this.maxFaceWidthFrac = 0,
    this.minFaceWidthFrac = 0,
    this.pivotU = 0.5,
    this.pivotV = 0.5,
    this.rotationOffsetDeg = 0,
    this.yawSqueeze = 0.25,
    this.scaleFromFaceBox = false,
    this.heightSpanFrac = 0,
    this.heightAnchorTopLandmark = -1,
    this.heightAnchorBottomLandmark = -1,
    this.pinX = 'ref_midpoint',
    this.pinY = 'anchor',
    this.useAveragedEyes = false,
    this.widthScreenMult = 0,
    this.widthFaceFrac = 0,
    this.widthMinFaceFrac = 0,
  });

  final int leftLandmark;
  final int rightLandmark;
  final int anchorLandmark;
  final int secondaryAnchorLandmark;
  final double secondaryBlendY;
  final double offsetYFaceFrac;
  final double offsetXFaceFrac;
  final double widthOverRef;
  final double maxFaceWidthFrac;
  final double minFaceWidthFrac;
  final double pivotU;
  final double pivotV;
  final double rotationOffsetDeg;
  final double yawSqueeze;
  final bool scaleFromFaceBox;
  final double heightSpanFrac;
  final int heightAnchorTopLandmark;
  final int heightAnchorBottomLandmark;
  final String pinX;
  final String pinY;
  final bool useAveragedEyes;
  final double widthScreenMult;
  final double widthFaceFrac;
  final double widthMinFaceFrac;

  factory ArStickerAnchorModel.fromJson(Map<String, dynamic> json) {
    return ArStickerAnchorModel(
      leftLandmark: _readInt(json['leftLandmark'], defaultValue: 33),
      rightLandmark: _readInt(json['rightLandmark'], defaultValue: 263),
      anchorLandmark: _readInt(json['anchorLandmark'], defaultValue: 168),
      secondaryAnchorLandmark:
          _readInt(json['secondaryAnchorLandmark'], defaultValue: -1),
      secondaryBlendY: _readDouble(json['secondaryBlendY']),
      offsetYFaceFrac: _readDouble(json['offsetYFaceFrac']),
      offsetXFaceFrac: _readDouble(json['offsetXFaceFrac']),
      widthOverRef: _readDouble(json['widthOverRef'], defaultValue: 2.4),
      maxFaceWidthFrac: _readDouble(json['maxFaceWidthFrac']),
      minFaceWidthFrac: _readDouble(json['minFaceWidthFrac']),
      pivotU: _readDouble(json['pivotU'], defaultValue: 0.5),
      pivotV: _readDouble(json['pivotV'], defaultValue: 0.5),
      rotationOffsetDeg: _readDouble(json['rotationOffsetDeg']),
      yawSqueeze: _readDouble(json['yawSqueeze'], defaultValue: 0.25),
      scaleFromFaceBox: json['scaleFromFaceBox'] == true,
      heightSpanFrac: _readDouble(json['heightSpanFrac']),
      heightAnchorTopLandmark:
          _readInt(json['heightAnchorTopLandmark'], defaultValue: -1),
      heightAnchorBottomLandmark:
          _readInt(json['heightAnchorBottomLandmark'], defaultValue: -1),
      pinX: json['pinX']?.toString() ?? 'ref_midpoint',
      pinY: json['pinY']?.toString() ?? 'anchor',
      useAveragedEyes: json['useAveragedEyes'] == true,
      widthScreenMult: _readDouble(json['widthScreenMult']),
      widthFaceFrac: _readDouble(json['widthFaceFrac']),
      widthMinFaceFrac: _readDouble(json['widthMinFaceFrac']),
    );
  }

  Map<String, dynamic> toJson() => {
        'leftLandmark': leftLandmark,
        'rightLandmark': rightLandmark,
        'anchorLandmark': anchorLandmark,
        if (secondaryAnchorLandmark >= 0)
          'secondaryAnchorLandmark': secondaryAnchorLandmark,
        if (secondaryBlendY != 0) 'secondaryBlendY': secondaryBlendY,
        if (offsetYFaceFrac != 0) 'offsetYFaceFrac': offsetYFaceFrac,
        if (offsetXFaceFrac != 0) 'offsetXFaceFrac': offsetXFaceFrac,
        if (widthOverRef != 2.4) 'widthOverRef': widthOverRef,
        if (maxFaceWidthFrac != 0) 'maxFaceWidthFrac': maxFaceWidthFrac,
        if (minFaceWidthFrac != 0) 'minFaceWidthFrac': minFaceWidthFrac,
        'pivotU': pivotU,
        'pivotV': pivotV,
        if (rotationOffsetDeg != 0) 'rotationOffsetDeg': rotationOffsetDeg,
        if (yawSqueeze != 0.25) 'yawSqueeze': yawSqueeze,
        if (scaleFromFaceBox) 'scaleFromFaceBox': scaleFromFaceBox,
        if (heightSpanFrac > 0) 'heightSpanFrac': heightSpanFrac,
        if (heightAnchorTopLandmark >= 0)
          'heightAnchorTopLandmark': heightAnchorTopLandmark,
        if (heightAnchorBottomLandmark >= 0)
          'heightAnchorBottomLandmark': heightAnchorBottomLandmark,
        'pinX': pinX,
        'pinY': pinY,
        if (useAveragedEyes) 'useAveragedEyes': useAveragedEyes,
        if (widthScreenMult > 0) 'widthScreenMult': widthScreenMult,
        if (widthFaceFrac > 0) 'widthFaceFrac': widthFaceFrac,
        if (widthMinFaceFrac > 0) 'widthMinFaceFrac': widthMinFaceFrac,
      };
}

ArEffectRenderType _inferRenderType({
  required List<ArEffectStickerLayerModel>? stickers,
  required ArStickerAnchorModel? anchor,
  required String? distortionPreset,
  required String? assetUrl,
  required String? assetAsset,
}) {
  if (distortionPreset != null && distortionPreset.isNotEmpty) {
    return ArEffectRenderType.distortion;
  }
  if (stickers != null && stickers.isNotEmpty) {
    return ArEffectRenderType.composite;
  }
  if (_hasAsset(assetUrl, assetAsset) || anchor != null) {
    return ArEffectRenderType.sticker;
  }
  return ArEffectRenderType.none;
}

bool _hasAsset(String? url, String? asset) =>
    (url ?? '').trim().isNotEmpty || (asset ?? '').trim().isNotEmpty;

String? _resolveAsset(String? url, String? asset) {
  final u = url?.trim();
  if (u != null && u.isNotEmpty) return u;
  final a = asset?.trim();
  if (a != null && a.isNotEmpty) return a;
  return null;
}

String? _readOptionalString(dynamic value) {
  final s = value?.toString().trim();
  if (s == null || s.isEmpty) return null;
  return s;
}

int _readInt(dynamic value, {int defaultValue = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

double _readDouble(dynamic value, {double defaultValue = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}
