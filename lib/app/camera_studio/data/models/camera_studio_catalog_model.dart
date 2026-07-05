import 'dart:convert';

import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:flutter/material.dart';

class CameraStudioCatalogModel extends CameraStudioCatalogEntity {
  const CameraStudioCatalogModel({
    required super.version,
    required super.filterCategories,
    required super.effectCategories,
  });

  factory CameraStudioCatalogModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return CameraStudioCatalogModel.fromJson(data);
    }

    return CameraStudioCatalogModel(
      version: json['version']?.toString() ?? 'bundled',
      filterCategories: _readFilterCategories(json['filterCategories']),
      effectCategories: _readEffectCategories(json['effectCategories']),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'filterCategories': filterCategories
            .map(
              (category) => {
                'slug': category.slug,
                'labelKey': category.labelKey,
                'sortOrder': category.sortOrder,
                'filters': category.filters
                    .map(
                      (filter) => {
                        if (filter.id != null) 'id': filter.id,
                        'slug': filter.slug,
                        'engineType': filter.engineType,
                        'engineKey': filter.engineKey,
                        if (filter.labelKey != null) 'labelKey': filter.labelKey,
                        if (filter.customLabel != null)
                          'customLabel': filter.customLabel,
                        if (filter.thumbnailUrl != null)
                          'thumbnailUrl': filter.thumbnailUrl,
                        if (filter.previewColorHex != null)
                          'previewColorHex': filter.previewColorHex,
                        'isOriginal': filter.isOriginal,
                        'isBeautyDefault': filter.isBeautyDefault,
                        'sortOrder': filter.sortOrder,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
        'effectCategories': effectCategories
            .map(
              (category) => {
                'slug': category.slug,
                'labelKey': category.labelKey,
                'sortOrder': category.sortOrder,
                'effects': category.effects
                    .map(
                      (effect) => {
                        if (effect.id != null) 'id': effect.id,
                        'slug': effect.slug,
                        'effectType': effect.effectType,
                        if (effect.emoji != null) 'emoji': effect.emoji,
                        'previewColorHex': effect.previewColorHex,
                        'labelKey': effect.labelKey,
                        'requiresFaceDetection': effect.requiresFaceDetection,
                        'isScreenEffect': effect.isScreenEffect,
                        'sortOrder': effect.sortOrder,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      };

  String encode() => jsonEncode(toJson());

  static CameraStudioCatalogModel decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return CameraStudioCatalogModel.fromJson(decoded);
    }
    if (decoded is Map) {
      return CameraStudioCatalogModel.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    }
    throw FormatException('Invalid camera studio catalog cache');
  }

  static const CameraStudioCatalogModel empty = CameraStudioCatalogModel(
    version: '',
    filterCategories: [],
    effectCategories: [],
  );

  static List<CameraFilterCategoryEntity> _readFilterCategories(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (entry) => CameraFilterCategoryModel.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList(growable: false);
  }

  static List<CameraEffectCategoryEntity> _readEffectCategories(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (entry) => CameraEffectCategoryModel.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .toList(growable: false);
  }

  /// Offline fallback matching the backend seed defaults (no bundled PNGs).
  static CameraStudioCatalogModel bundled() {
    CameraFilterEntity filter(
      String slug,
      String engineKey, {
      String? labelKey,
      String? customLabel,
      String? previewColorHex,
      bool isOriginal = false,
      bool isBeautyDefault = false,
    }) {
      return CameraFilterEntity(
        slug: slug,
        engineKey: engineKey,
        labelKey: labelKey,
        customLabel: customLabel,
        previewColorHex: previewColorHex,
        isOriginal: isOriginal,
        isBeautyDefault: isBeautyDefault,
      );
    }

    CameraFilterCategoryEntity category(
      String slug,
      String labelKey,
      int sortOrder,
      List<CameraFilterEntity> filters,
    ) {
      return CameraFilterCategoryEntity(
        slug: slug,
        labelKey: labelKey,
        sortOrder: sortOrder,
        filters: filters,
      );
    }

    return CameraStudioCatalogModel(
      version: 'bundled',
      filterCategories: [
        category('trending', 'cameraCategoryTrending', 0, [
          filter('original', 'Original', isOriginal: true, previewColorHex: '#E8D5C4'),
          filter('amaro', 'Amaro', previewColorHex: '#E8A87C'),
          filter('juno', 'Juno', customLabel: 'Golden', previewColorHex: '#FFD166'),
          filter('lark', 'Lark', customLabel: 'Natural', previewColorHex: '#90CAF9'),
          filter('addictive-red', 'Addictive Red', previewColorHex: '#E07A7A'),
          filter('clarendon', 'Clarendon', previewColorHex: '#5C9EAD'),
          filter('reyes', 'Reyes', customLabel: 'Flash', previewColorHex: '#D4A574'),
          filter('aden', 'Aden', customLabel: 'Glow', isBeautyDefault: true, previewColorHex: '#F4A6C7'),
        ]),
        category('newFilters', 'cameraCategoryNew', 1, [
          filter('original', 'Original', isOriginal: true, previewColorHex: '#E8D5C4'),
          filter('aden', 'Aden', customLabel: 'Glow', isBeautyDefault: true, previewColorHex: '#F4A6C7'),
          filter('perpetua', 'Perpetua', previewColorHex: '#7A7A7A'),
          filter('walden', 'Walden', previewColorHex: '#2E8B57'),
          filter('ginza', 'Ginza', previewColorHex: '#7A7A7A'),
          filter('sierra', 'Sierra', previewColorHex: '#7A7A7A'),
          filter('hefe', 'Hefe', previewColorHex: '#CD853F'),
        ]),
        category('portrait', 'cameraCategoryPortrait', 2, [
          filter('original', 'Original', isOriginal: true, previewColorHex: '#E8D5C4'),
          filter('aden', 'Aden', customLabel: 'Glow', isBeautyDefault: true, previewColorHex: '#F4A6C7'),
          filter('lark', 'Lark', customLabel: 'Natural', previewColorHex: '#90CAF9'),
          filter('juno', 'Juno', customLabel: 'Golden', previewColorHex: '#FFD166'),
          filter('reyes', 'Reyes', customLabel: 'Flash', previewColorHex: '#D4A574'),
          filter('inkwell', 'Inkwell', previewColorHex: '#9E9E9E'),
          filter('moon', 'Moon', previewColorHex: '#6B705C'),
          filter('willow', 'Willow', previewColorHex: '#7A7A7A'),
          filter('brannan', 'Brannan', previewColorHex: '#7A7A7A'),
          filter('stinson', 'Stinson', previewColorHex: '#7A7A7A'),
        ]),
        category('vibe', 'cameraCategoryVibe', 3, [
          filter('original', 'Original', isOriginal: true, previewColorHex: '#E8D5C4'),
          filter('sutro', 'Sutro', previewColorHex: '#4A5568'),
          filter('hudson', 'Hudson', previewColorHex: '#4682B4'),
          filter('lofi', 'LoFi', previewColorHex: '#8B7355'),
          filter('slumber', 'Slumber', previewColorHex: '#7A7A7A'),
          filter('dogpatch', 'Dogpatch', previewColorHex: '#7A7A7A'),
          filter('addictive-blue', 'Addictive Blue', previewColorHex: '#7EB8DA'),
        ]),
        category('landscape', 'cameraCategoryLandscape', 4, [
          filter('original', 'Original', isOriginal: true, previewColorHex: '#E8D5C4'),
          filter('brooklyn', 'Brooklyn', previewColorHex: '#C9A66B'),
          filter('gingham', 'Gingham', previewColorHex: '#7A7A7A'),
          filter('xproii', 'XProII', previewColorHex: '#BC8F8F'),
          filter('ludwig', 'Ludwig', previewColorHex: '#7A7A7A'),
          filter('crema', 'Crema', previewColorHex: '#7A7A7A'),
          filter('ashby', 'Ashby', previewColorHex: '#7A7A7A'),
        ]),
      ],
      effectCategories: [
        CameraEffectCategoryEntity(
          slug: 'trending',
          labelKey: 'cameraCategoryTrending',
          sortOrder: 0,
          effects: [
            const CameraEffectEntity(
              slug: 'none',
              effectType: 'face_ar',
              emoji: '○',
              previewColorHex: '#555555',
              labelKey: 'cameraFilterOriginal',
            ),
            const CameraEffectEntity(
              slug: 'crown',
              effectType: 'face_ar',
              emoji: '👑',
              previewColorHex: '#FFD700',
              labelKey: 'cameraEffectCrown',
              requiresFaceDetection: true,
            ),
            const CameraEffectEntity(
              slug: 'bunny',
              effectType: 'face_ar',
              emoji: '🐰',
              previewColorHex: '#F8BBD0',
              labelKey: 'cameraEffectBunny',
              requiresFaceDetection: true,
            ),
            const CameraEffectEntity(
              slug: 'sunglasses',
              effectType: 'face_ar',
              emoji: '😎',
              previewColorHex: '#37474F',
              labelKey: 'cameraEffectSunglasses',
              requiresFaceDetection: true,
            ),
            const CameraEffectEntity(
              slug: 'dog',
              effectType: 'face_ar',
              emoji: '🐶',
              previewColorHex: '#8D6E63',
              labelKey: 'cameraEffectDog',
              requiresFaceDetection: true,
            ),
            const CameraEffectEntity(
              slug: 'hearts',
              effectType: 'face_ar',
              emoji: '💕',
              previewColorHex: '#E91E63',
              labelKey: 'cameraEffectHearts',
              requiresFaceDetection: true,
            ),
            const CameraEffectEntity(
              slug: 'sparkle',
              effectType: 'screen_overlay',
              emoji: '✨',
              previewColorHex: '#CE93D8',
              labelKey: 'cameraEffectSparkle',
              isScreenEffect: true,
            ),
            const CameraEffectEntity(
              slug: 'neon',
              effectType: 'screen_overlay',
              emoji: '💜',
              previewColorHex: '#7C4DFF',
              labelKey: 'cameraEffectNeon',
              isScreenEffect: true,
            ),
            const CameraEffectEntity(
              slug: 'glitch',
              effectType: 'screen_overlay',
              emoji: '⚡',
              previewColorHex: '#00E5FF',
              labelKey: 'cameraEffectGlitch',
              isScreenEffect: true,
            ),
          ],
        ),
      ],
    );
  }
}

class CameraFilterCategoryModel extends CameraFilterCategoryEntity {
  const CameraFilterCategoryModel({
    required super.slug,
    required super.labelKey,
    required super.sortOrder,
    required super.filters,
  });

  factory CameraFilterCategoryModel.fromJson(Map<String, dynamic> json) {
    final filtersRaw = json['filters'];
    final filters = filtersRaw is List
        ? filtersRaw
            .whereType<Map>()
            .map(
              (entry) => CameraFilterModel.fromJson(
                Map<String, dynamic>.from(entry),
              ),
            )
            .toList(growable: false)
        : const <CameraFilterEntity>[];

    return CameraFilterCategoryModel(
      slug: json['slug']?.toString() ?? '',
      labelKey: json['labelKey']?.toString() ?? '',
      sortOrder: _readInt(json['sortOrder']),
      filters: filters,
    );
  }
}

class CameraFilterModel extends CameraFilterEntity {
  const CameraFilterModel({
    super.id,
    required super.slug,
    required super.engineKey,
    super.engineType,
    super.labelKey,
    super.customLabel,
    super.thumbnailUrl,
    super.previewColorHex,
    super.isOriginal,
    super.isBeautyDefault,
    super.sortOrder,
  });

  factory CameraFilterModel.fromJson(Map<String, dynamic> json) {
    return CameraFilterModel(
      id: json['id']?.toString(),
      slug: json['slug']?.toString() ?? '',
      engineType: json['engineType']?.toString() ?? 'camerawesome',
      engineKey: json['engineKey']?.toString() ?? '',
      labelKey: json['labelKey']?.toString(),
      customLabel: json['customLabel']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      previewColorHex: json['previewColorHex']?.toString(),
      isOriginal: json['isOriginal'] == true,
      isBeautyDefault: json['isBeautyDefault'] == true,
      sortOrder: _readInt(json['sortOrder']),
    );
  }
}

class CameraEffectCategoryModel extends CameraEffectCategoryEntity {
  const CameraEffectCategoryModel({
    required super.slug,
    required super.labelKey,
    required super.sortOrder,
    required super.effects,
  });

  factory CameraEffectCategoryModel.fromJson(Map<String, dynamic> json) {
    final effectsRaw = json['effects'];
    final effects = effectsRaw is List
        ? effectsRaw
            .whereType<Map>()
            .map(
              (entry) => CameraEffectModel.fromJson(
                Map<String, dynamic>.from(entry),
              ),
            )
            .toList(growable: false)
        : const <CameraEffectEntity>[];

    return CameraEffectCategoryModel(
      slug: json['slug']?.toString() ?? '',
      labelKey: json['labelKey']?.toString() ?? '',
      sortOrder: _readInt(json['sortOrder']),
      effects: effects,
    );
  }
}

class CameraEffectModel extends CameraEffectEntity {
  const CameraEffectModel({
    super.id,
    required super.slug,
    required super.effectType,
    super.emoji,
    required super.previewColorHex,
    required super.labelKey,
    super.requiresFaceDetection,
    super.isScreenEffect,
    super.sortOrder,
  });

  factory CameraEffectModel.fromJson(Map<String, dynamic> json) {
    return CameraEffectModel(
      id: json['id']?.toString(),
      slug: json['slug']?.toString() ?? '',
      effectType: json['effectType']?.toString() ?? 'face_ar',
      emoji: json['emoji']?.toString(),
      previewColorHex: json['previewColorHex']?.toString() ?? '#7A7A7A',
      labelKey: json['labelKey']?.toString() ?? '',
      requiresFaceDetection: json['requiresFaceDetection'] == true,
      isScreenEffect: json['isScreenEffect'] == true,
      sortOrder: _readInt(json['sortOrder']),
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Color? parsePreviewColorHex(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final normalized = raw.replaceFirst('#', '');
  if (normalized.length == 6) {
    final value = int.tryParse('FF$normalized', radix: 16);
    if (value != null) return Color(value);
  }
  if (normalized.length == 8) {
    final value = int.tryParse(normalized, radix: 16);
    if (value != null) return Color(value);
  }
  return null;
}
