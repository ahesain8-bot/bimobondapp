import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';

/// Loads the gift catalog on demand so realtime payloads can be hydrated.
typedef GiftCatalogLoader = Future<List<GiftEntity>> Function();

/// Flat keys the server sends instead of a nested `gift` object, mapped onto
/// the normalized gift keys the shared renderer reads.
const giftPayloadFlatFields = <String, String>{
  'animationUrl': 'animationUrl',
  'animation_url': 'animationUrl',
  'giftAnimationUrl': 'animationUrl',
  'thumbnailUrl': 'thumbnailUrl',
  'thumbnail_url': 'thumbnailUrl',
  'giftThumbnailUrl': 'thumbnailUrl',
  'imageUrl': 'imageUrl',
  'image_url': 'imageUrl',
  'giftImageUrl': 'imageUrl',
  'iconUrl': 'imageUrl',
  'giftIconUrl': 'imageUrl',
  'audioUrl': 'audioUrl',
  'audio_url': 'audioUrl',
  'giftAudioUrl': 'audioUrl',
  'size': 'size',
  'giftSize': 'size',
  'type': 'type',
  'giftType': 'type',
  'color': 'color',
  'colorHex': 'color',
  'icon': 'icon',
  'emoji': 'icon',
};

/// The single owner of gift-metadata hydration for realtime socket payloads.
///
/// `gift_combo` / `auctionGiftCombo` events are frequently flat and carry only
/// `giftId` + `giftName`, with no media and no size. Both are required before
/// the shared renderer can choose between the combo badge and the fullscreen
/// animation, so the missing fields are filled in from the gift catalog.
class GiftCatalogHydrator {
  GiftCatalogHydrator(this._loader);

  final GiftCatalogLoader _loader;
  final Map<String, GiftEntity> _byId = {};
  Future<void>? _inFlight;
  bool _loaded = false;

  /// Merges catalog media/size/type into [payload] when the event omits them.
  Future<void> hydrate(Map<String, dynamic> payload, String giftId) async {
    if (!needsHydration(payload)) return;
    await _ensureLoaded();
    final gift = _byId[giftId] ?? _byName(payload);
    if (gift == null) return;
    enrich(payload, gift);
  }

  /// The catalog entry for [giftId], or null when it has not been loaded yet.
  GiftEntity? giftById(String giftId) => _byId[giftId];

  /// True when the event is missing media, size or type that the gift renderer
  /// needs in order to present the gift.
  static bool needsHydration(Map<String, dynamic> payload) {
    final gift = _asMap(payload['gift']);
    final media = [
      gift?['animationUrl'],
      gift?['animation_url'],
      gift?['thumbnailUrl'],
      gift?['thumbnail_url'],
      gift?['imageUrl'],
      gift?['image_url'],
      gift?['audioUrl'],
      gift?['audio_url'],
      payload['animationUrl'],
      payload['animation_url'],
      payload['thumbnailUrl'],
      payload['thumbnail_url'],
      payload['imageUrl'],
      payload['image_url'],
      payload['audioUrl'],
      payload['audio_url'],
    ];
    final size = gift?['size'] ?? gift?['giftSize'] ?? payload['size'];
    final type = gift?['type'] ?? gift?['giftType'] ?? payload['type'];
    return !media.any(_hasText) || !_hasText(size) || !_hasText(type);
  }

  /// Merges catalog presentation fields into a flat socket payload.
  ///
  /// Existing non-empty event fields win, so nested/legacy payloads keep their
  /// server-provided values while flat payloads gain animation metadata.
  static Map<String, dynamic> enrich(
    Map<String, dynamic> payload,
    GiftEntity catalogGift,
  ) {
    final catalogMap = <String, dynamic>{
      'id': catalogGift.id,
      'name': catalogGift.name,
      'icon': catalogGift.icon,
      'type': catalogGift.type == GiftCatalogType.audio ? 'AUDIO' : 'IMAGE',
      'size': catalogGift.size.name.toUpperCase(),
      if (catalogGift.imageUrl != null) 'imageUrl': catalogGift.imageUrl,
      if (catalogGift.thumbnailUrl != null)
        'thumbnailUrl': catalogGift.thumbnailUrl,
      if (catalogGift.animationUrl != null)
        'animationUrl': catalogGift.animationUrl,
      if (catalogGift.audioUrl != null) 'audioUrl': catalogGift.audioUrl,
      if (catalogGift.color != null) 'color': catalogGift.color,
    };
    // Same precedence the payload parser applies: catalog < flat < nested.
    for (final entry in giftPayloadFlatFields.entries) {
      final value = payload[entry.key];
      if (_hasText(value)) catalogMap[entry.value] = value;
    }
    final existing = _asMap(payload['gift']);
    if (existing != null) {
      for (final entry in existing.entries) {
        if (_hasText(entry.value)) catalogMap[entry.key] = entry.value;
      }
    }
    payload['gift'] = catalogMap;
    payload.putIfAbsent('giftId', () => catalogGift.id);
    payload.putIfAbsent('giftName', () => catalogGift.name);
    return payload;
  }

  /// Catalog lookup by name, for servers that omit a stable gift id.
  GiftEntity? _byName(Map<String, dynamic> payload) {
    final raw =
        (payload['giftName'] ??
                payload['gift_name'] ??
                _asMap(payload['gift'])?['name'])
            ?.toString()
            .trim()
            .toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    for (final gift in _byId.values) {
      if (gift.name.trim().toLowerCase() == raw) return gift;
    }
    return null;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final existing = _inFlight;
    if (existing != null) {
      await existing;
      return;
    }

    final load = () async {
      try {
        final gifts = await _loader();
        _byId
          ..clear()
          ..addEntries(gifts.map((gift) => MapEntry(gift.id, gift)));
        // Only latch on success, otherwise one failed refresh would leave the
        // session without gift metadata until the app restarts.
        _loaded = _byId.isNotEmpty;
      } catch (_) {
        // Gift events must still be delivered when a catalog refresh fails.
      } finally {
        _inFlight = null;
      }
    }();
    _inFlight = load;
    await load;
  }

  static bool _hasText(dynamic value) =>
      value != null && value.toString().trim().isNotEmpty;

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }
}
