/// Phase 8 backend-driven effect metadata (NestJS `GET /effects` shape).
class RemoteEffectCatalog {
  const RemoteEffectCatalog({
    required this.version,
    required this.effects,
  });

  final String version;
  final List<RemoteEffect> effects;

  factory RemoteEffectCatalog.fromJson(Map<String, dynamic> json) {
    final rawEffects = json['effects'];
    final list = <RemoteEffect>[];
    if (rawEffects is List) {
      for (final e in rawEffects) {
        if (e is Map) {
          list.add(RemoteEffect.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    } else if (json['id'] != null) {
      // Single effect payload.
      list.add(RemoteEffect.fromJson(json));
    }
    return RemoteEffectCatalog(
      version: json['version']?.toString() ??
          json['catalogVersion']?.toString() ??
          '0',
      effects: list,
    );
  }

  /// Accepts either `{version, effects:[...]}` or a bare `[...]` list.
  factory RemoteEffectCatalog.parse(dynamic body) {
    if (body is List) {
      final list = <RemoteEffect>[];
      for (final e in body) {
        if (e is Map) {
          list.add(RemoteEffect.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      return RemoteEffectCatalog(version: 'list', effects: list);
    }
    if (body is Map<String, dynamic>) {
      return RemoteEffectCatalog.fromJson(body);
    }
    if (body is Map) {
      return RemoteEffectCatalog.fromJson(Map<String, dynamic>.from(body));
    }
    return const RemoteEffectCatalog(version: '0', effects: []);
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'effects': effects.map((e) => e.toJson()).toList(),
      };
}

class RemoteEffect {
  const RemoteEffect({
    required this.id,
    required this.name,
    required this.type,
    required this.version,
    this.thumbnail,
    this.assets = const {},
    this.parameters = const {},
    this.layers = const [],
    this.nativePresetId,
  });

  final String id;
  final String name;
  final String type;
  final int version;
  final String? thumbnail;
  final Map<String, String> assets;
  final Map<String, dynamic> parameters;
  final List<RemoteEffectLayer> layers;

  /// When set, activates a native bundled preset instead of downloading PNGs.
  final String? nativePresetId;

  bool get isFaceSticker =>
      type == 'face_sticker' || type == 'sticker' || type == 'composite';

  bool get usesNativePreset =>
      nativePresetId != null && nativePresetId!.isNotEmpty;

  double get scale => (parameters['scale'] as num?)?.toDouble() ?? 1.0;
  double get opacity => (parameters['opacity'] as num?)?.toDouble() ?? 1.0;

  factory RemoteEffect.fromJson(Map<String, dynamic> json) {
    final assetsRaw = json['assets'];
    final assets = <String, String>{};
    if (assetsRaw is Map) {
      assetsRaw.forEach((k, v) {
        if (v != null) assets[k.toString()] = v.toString();
      });
    }

    final paramsRaw = json['parameters'];
    final params = <String, dynamic>{};
    if (paramsRaw is Map) {
      params.addAll(Map<String, dynamic>.from(paramsRaw));
    }

    final layersRaw = json['layers'];
    final layers = <RemoteEffectLayer>[];
    if (layersRaw is List) {
      for (final e in layersRaw) {
        if (e is Map) {
          layers.add(RemoteEffectLayer.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    final versionRaw = json['version'];
    final version = versionRaw is int
        ? versionRaw
        : versionRaw is num
            ? versionRaw.toInt()
            : int.tryParse(versionRaw?.toString() ?? '') ?? 1;

    return RemoteEffect(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ??
          json['label']?.toString() ??
          json['id']?.toString() ??
          '',
      type: json['type']?.toString() ??
          json['renderType']?.toString() ??
          'face_sticker',
      version: version,
      thumbnail: json['thumbnail']?.toString() ??
          json['thumbnailUrl']?.toString(),
      assets: assets,
      parameters: params,
      layers: layers,
      nativePresetId: json['nativePresetId']?.toString() ??
          json['native_preset_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'version': version,
        'thumbnail': thumbnail,
        'assets': assets,
        'parameters': parameters,
        'layers': layers.map((e) => e.toJson()).toList(),
        'nativePresetId': nativePresetId,
      };

  /// Resolved layers: explicit [layers] or synthesized from [assets] keys.
  List<RemoteEffectLayer> resolvedLayers() {
    if (layers.isNotEmpty) return layers;
    final out = <RemoteEffectLayer>[];
    assets.forEach((key, url) {
      out.add(RemoteEffectLayer.presetForAssetKey(key, opacity: opacity));
    });
    if (out.isEmpty && usesNativePreset) {
      // Native preset needs no download layers.
      return const [];
    }
    return out;
  }
}

class RemoteEffectLayer {
  const RemoteEffectLayer({
    required this.assetKey,
    this.leftLandmark = 33,
    this.rightLandmark = 263,
    this.anchorLandmark = 168,
    this.pinX = 'ref_midpoint',
    this.pinY = 'anchor',
    this.widthOverRef = 2.4,
    this.widthFaceFrac = 0,
    this.offsetXFaceFrac = 0,
    this.offsetYFaceFrac = 0,
    this.pivotU = 0.5,
    this.pivotV = 0.5,
    this.yawSqueeze = 0.15,
    this.opacity = 1,
  });

  final String assetKey;
  final int leftLandmark;
  final int rightLandmark;
  final int anchorLandmark;
  final String pinX;
  final String pinY;
  final double widthOverRef;
  final double widthFaceFrac;
  final double offsetXFaceFrac;
  final double offsetYFaceFrac;
  final double pivotU;
  final double pivotV;
  final double yawSqueeze;
  final double opacity;

  factory RemoteEffectLayer.fromJson(Map<String, dynamic> json) {
    return RemoteEffectLayer(
      assetKey: json['assetKey']?.toString() ??
          json['asset']?.toString() ??
          json['key']?.toString() ??
          '',
      leftLandmark: (json['leftLandmark'] as num?)?.toInt() ?? 33,
      rightLandmark: (json['rightLandmark'] as num?)?.toInt() ?? 263,
      anchorLandmark: (json['anchorLandmark'] as num?)?.toInt() ?? 168,
      pinX: json['pinX']?.toString() ?? 'ref_midpoint',
      pinY: json['pinY']?.toString() ?? 'anchor',
      widthOverRef: (json['widthOverRef'] as num?)?.toDouble() ?? 2.4,
      widthFaceFrac: (json['widthFaceFrac'] as num?)?.toDouble() ?? 0,
      offsetXFaceFrac: (json['offsetXFaceFrac'] as num?)?.toDouble() ?? 0,
      offsetYFaceFrac: (json['offsetYFaceFrac'] as num?)?.toDouble() ?? 0,
      pivotU: (json['pivotU'] as num?)?.toDouble() ?? 0.5,
      pivotV: (json['pivotV'] as num?)?.toDouble() ?? 0.5,
      yawSqueeze: (json['yawSqueeze'] as num?)?.toDouble() ?? 0.15,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'assetKey': assetKey,
        'leftLandmark': leftLandmark,
        'rightLandmark': rightLandmark,
        'anchorLandmark': anchorLandmark,
        'pinX': pinX,
        'pinY': pinY,
        'widthOverRef': widthOverRef,
        'widthFaceFrac': widthFaceFrac,
        'offsetXFaceFrac': offsetXFaceFrac,
        'offsetYFaceFrac': offsetYFaceFrac,
        'pivotU': pivotU,
        'pivotV': pivotV,
        'yawSqueeze': yawSqueeze,
        'opacity': opacity,
      };

  /// Sensible defaults when backend only sends asset URLs by key.
  factory RemoteEffectLayer.presetForAssetKey(
    String key, {
    double opacity = 1,
  }) {
    final k = key.toLowerCase();
    if (k.contains('ear') || k.contains('hat') || k.contains('crown')) {
      return RemoteEffectLayer(
        assetKey: key,
        leftLandmark: 33,
        rightLandmark: 263,
        anchorLandmark: 10,
        pinX: 'ref_midpoint',
        pinY: 'above_ref',
        widthOverRef: 3.1,
        offsetYFaceFrac: -0.2,
        pivotV: 0.85,
        opacity: opacity,
      );
    }
    if (k.contains('nose')) {
      return RemoteEffectLayer(
        assetKey: key,
        leftLandmark: 33,
        rightLandmark: 263,
        anchorLandmark: 1,
        pinX: 'anchor',
        pinY: 'anchor',
        widthOverRef: 0.95,
        opacity: opacity,
      );
    }
    if (k.contains('glass') || k.contains('shade')) {
      return RemoteEffectLayer(
        assetKey: key,
        leftLandmark: 33,
        rightLandmark: 263,
        anchorLandmark: 168,
        pinX: 'ref_midpoint',
        pinY: 'ref_midline',
        widthOverRef: 2.65,
        opacity: opacity,
      );
    }
    if (k.contains('mask')) {
      return RemoteEffectLayer(
        assetKey: key,
        leftLandmark: 234,
        rightLandmark: 454,
        anchorLandmark: 1,
        pinX: 'ref_midpoint',
        pinY: 'anchor',
        widthOverRef: 1.35,
        opacity: opacity,
      );
    }
    // Generic sticker under mouth / chin.
    return RemoteEffectLayer(
      assetKey: key,
      leftLandmark: 61,
      rightLandmark: 291,
      anchorLandmark: 152,
      pinX: 'ref_midpoint',
      pinY: 'anchor',
      widthOverRef: 1.6,
      offsetYFaceFrac: 0.06,
      opacity: opacity,
    );
  }
}
