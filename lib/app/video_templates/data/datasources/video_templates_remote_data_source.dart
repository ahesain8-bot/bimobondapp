import 'dart:convert';

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

abstract class VideoTemplatesRemoteDataSource {
  Future<List<VideoTemplateCardEntity>> listPhotoTemplates({
    int limit = 40,
    int offset = 0,
  });

  Future<List<VideoTemplateCardEntity>> listTemplates({
    String? templateKind,
    String? categoryId,
    int limit = 40,
    int offset = 0,
  });

  Future<List<VideoTemplateCardEntity>> listFeatured({
    int limit = 40,
    int offset = 0,
  });

  Future<List<VideoTemplateCardEntity>> listTrending({
    int limit = 40,
    int offset = 0,
  });

  Future<List<VideoTemplateCardEntity>> searchTemplates({
    required String query,
    int limit = 40,
    int offset = 0,
  });

  Future<List<VideoTemplateCardEntity>> listBySound({
    required String soundId,
    int limit = 40,
    int offset = 0,
  });

  Future<List<TemplateCategoryEntity>> listCategories();

  Future<VideoTemplateCardEntity> getTemplate(String templateId);

  Future<VideoTemplateRecipeEntity> getRecipe(
    String templateId, {
    bool includeOverlays = false,
  });

  Future<void> recordUse(String templateId);

  Future<VideoTemplateProjectEntity> createProject({
    required String templateId,
    String? title,
  });

  Future<VideoTemplateProjectEntity> getProject(String projectId);

  Future<VideoTemplateProjectSlotEntity> patchProjectSlot({
    required String projectId,
    required String slotId,
    required String userAssetUrl,
    double? trimStart,
    double? trimEnd,
    double? speed,
    double? rotation,
    double? scale,
    double? volume,
  });

  Future<void> completeProject(String projectId);

  Future<VideoTemplateExportEntity> queueExport({
    required String projectId,
    String quality = 'standard',
  });

  Future<VideoTemplateExportEntity> getExport({
    required String projectId,
    required String exportId,
  });

  Future<VideoTemplateExportEntity?> listenExportStream({
    required String projectId,
    required String exportId,
    void Function(VideoTemplateExportEntity snap)? onUpdate,
    Duration timeout = const Duration(minutes: 8),
  });

  Future<List<TemplatePresetItem>> listPresets({
    required String kind,
    String? projectId,
    String? category,
    int limit = 50,
  });

  Future<void> putSlotFilter({
    required String projectId,
    required String slotId,
    String? presetId,
    double intensity = 1,
  });

  Future<void> putSlotEffect({
    required String projectId,
    required String slotId,
    String? presetId,
  });

  Future<void> createProjectText({
    required String projectId,
    required String text,
    double fontSize = 48,
    String color = '#FFFFFF',
    double positionY = 120,
    double startTime = 0,
    required double endTime,
  });

  Future<void> createProjectSticker({
    required String projectId,
    String? presetId,
    String? assetUrl,
    double positionX = 0,
    double positionY = -200,
    double scale = 1,
    double opacity = 1,
    double startTime = 0,
    double? endTime,
  });
}

class VideoTemplatesRemoteDataSourceImpl
    implements VideoTemplatesRemoteDataSource {
  VideoTemplatesRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      return data['message']?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    throw ServerException(message: 'Invalid response');
  }

  Map<String, dynamic> _unwrap(dynamic body) {
    final map = _asMap(body);
    final data = map['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }

  /// Prefer the payload that contains recipe fields + `renderHints`.
  Map<String, dynamic> _unwrapRecipe(
    dynamic body, {
    required String templateId,
  }) {
    final root = _asMap(body);
    final data = root['data'];
    final candidates = <Map<String, dynamic>>[
      root,
      if (data is Map) Map<String, dynamic>.from(data),
    ];
    for (final map in candidates) {
      final hasHints =
          map['renderHints'] is Map || map['render_hints'] is Map;
      final hasSlots = map['slots'] is List;
      if (hasHints || hasSlots || map['id'] != null) {
        if (map['id'] == null) map['id'] = templateId;
        return map;
      }
    }
    final fallback = _unwrap(body);
    if (fallback['id'] == null) fallback['id'] = templateId;
    return fallback;
  }

  List<VideoTemplateCardEntity> _parseCardList(dynamic body) {
    List<dynamic>? raw;
    if (body is List) {
      raw = body;
    } else if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      final data = map['data'] ?? map['items'] ?? map['templates'];
      if (data is List) raw = data;
    }
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => VideoTemplateCardEntity.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
  }

  List<TemplateCategoryEntity> _parseCategoryList(dynamic body) {
    List<dynamic>? raw;
    if (body is List) {
      raw = body;
    } else if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      final data = map['data'] ?? map['items'] ?? map['categories'];
      if (data is List) raw = data;
    }
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => TemplateCategoryEntity.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<VideoTemplateCardEntity>> _getCardShelf(
    String path, {
    Map<String, dynamic>? query,
    String errorLabel = 'Failed to load templates',
  }) async {
    try {
      final response = await apiClient.dio.get(
        path,
        queryParameters: query,
      );
      if (response.statusCode == 200) {
        return _parseCardList(response.data);
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? errorLabel,
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<VideoTemplateCardEntity>> listPhotoTemplates({
    int limit = 40,
    int offset = 0,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.videoTemplatesPhoto,
        queryParameters: {
          'limit': limit.clamp(1, 100),
          'offset': offset.clamp(0, 100000),
        },
      );
      if (response.statusCode == 200) {
        return _parseCardList(response.data);
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ??
            'Failed to load photo templates',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return listTemplates(
          templateKind: 'PHOTO_CAROUSEL',
          limit: limit,
          offset: offset,
        );
      }
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<VideoTemplateCardEntity>> listTemplates({
    String? templateKind,
    String? categoryId,
    int limit = 40,
    int offset = 0,
  }) {
    return _getCardShelf(
      ApiConstants.videoTemplates,
      query: {
        if (templateKind != null && templateKind.isNotEmpty)
          'templateKind': templateKind,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
        'limit': limit.clamp(1, 100),
        'offset': offset.clamp(0, 100000),
      },
    );
  }

  @override
  Future<List<VideoTemplateCardEntity>> listFeatured({
    int limit = 40,
    int offset = 0,
  }) {
    return _getCardShelf(
      ApiConstants.videoTemplatesFeatured,
      query: {
        'limit': limit.clamp(1, 100),
        'offset': offset.clamp(0, 100000),
      },
      errorLabel: 'Failed to load featured templates',
    );
  }

  @override
  Future<List<VideoTemplateCardEntity>> listTrending({
    int limit = 40,
    int offset = 0,
  }) {
    return _getCardShelf(
      ApiConstants.videoTemplatesTrending,
      query: {
        'limit': limit.clamp(1, 100),
        'offset': offset.clamp(0, 100000),
      },
      errorLabel: 'Failed to load trending templates',
    );
  }

  @override
  Future<List<VideoTemplateCardEntity>> searchTemplates({
    required String query,
    int limit = 40,
    int offset = 0,
  }) {
    final q = query.trim();
    if (q.isEmpty) return Future.value(const []);
    return _getCardShelf(
      ApiConstants.videoTemplatesSearch,
      query: {
        'q': q,
        'limit': limit.clamp(1, 100),
        'offset': offset.clamp(0, 100000),
      },
      errorLabel: 'Failed to search templates',
    );
  }

  @override
  Future<List<VideoTemplateCardEntity>> listBySound({
    required String soundId,
    int limit = 40,
    int offset = 0,
  }) {
    final id = soundId.trim();
    if (id.isEmpty) return Future.value(const []);
    return _getCardShelf(
      ApiConstants.videoTemplatesBySound(id),
      query: {
        'limit': limit.clamp(1, 100),
        'offset': offset.clamp(0, 100000),
      },
      errorLabel: 'Failed to load sound templates',
    );
  }

  @override
  Future<List<TemplateCategoryEntity>> listCategories() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.videoTemplatesCategories,
      );
      if (response.statusCode == 200) {
        return _parseCategoryList(response.data);
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ??
            'Failed to load template categories',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<VideoTemplateCardEntity> getTemplate(String templateId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.videoTemplateById(templateId),
      );
      if (response.statusCode == 200) {
        final map = _unwrap(response.data);
        if (map['id'] == null) map['id'] = templateId;
        final card = VideoTemplateCardEntity.fromJson(map);
        if (card.id.isEmpty) {
          throw ServerException(message: 'Template not found');
        }
        return card;
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load template',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<VideoTemplateRecipeEntity> getRecipe(
    String templateId, {
    bool includeOverlays = false,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.videoTemplateRecipe(templateId),
        queryParameters: {
          if (includeOverlays) 'includeOverlays': '1',
        },
      );
      if (response.statusCode == 200) {
        // Recipe is returned as the root object (with `renderHints`) or under
        // `data`. Prefer the map that actually carries renderHints / slots.
        final map = _unwrapRecipe(response.data, templateId: templateId);
        return VideoTemplateRecipeEntity.fromJson(map);
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load recipe',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> recordUse(String templateId) async {
    try {
      await apiClient.dio.post(ApiConstants.videoTemplateUse(templateId));
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<VideoTemplateProjectEntity> createProject({
    required String templateId,
    String? title,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.videoTemplateProjects,
        data: {
          'templateId': templateId,
          if (title != null && title.isNotEmpty) 'title': title,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return VideoTemplateProjectEntity.fromJson(_unwrap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to create project',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<VideoTemplateProjectEntity> getProject(String projectId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.videoTemplateProjectById(projectId),
      );
      if (response.statusCode == 200) {
        return VideoTemplateProjectEntity.fromJson(_unwrap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load project',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<VideoTemplateProjectSlotEntity> patchProjectSlot({
    required String projectId,
    required String slotId,
    required String userAssetUrl,
    double? trimStart,
    double? trimEnd,
    double? speed,
    double? rotation,
    double? scale,
    double? volume,
  }) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.videoTemplateProjectSlot(projectId, slotId),
        data: {
          'userAssetUrl': userAssetUrl,
          if (trimStart != null) 'trimStart': trimStart,
          if (trimEnd != null) 'trimEnd': trimEnd,
          if (speed != null) 'speed': speed,
          if (rotation != null) 'rotation': rotation,
          if (scale != null) 'scale': scale,
          if (volume != null) 'volume': volume,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return VideoTemplateProjectSlotEntity.fromJson(
          _unwrap(response.data),
        );
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to save slot media',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> completeProject(String projectId) async {
    try {
      await apiClient.dio.post(
        ApiConstants.videoTemplateProjectComplete(projectId),
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<VideoTemplateExportEntity> queueExport({
    required String projectId,
    String quality = 'standard',
  }) async {
    try {
      final normalized = quality.trim().toLowerCase() == 'draft'
          ? 'draft'
          : 'standard';
      final response = await apiClient.dio.post(
        ApiConstants.videoTemplateProjectExport(projectId),
        data: {
          'quality': normalized,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final map = _unwrap(response.data);
        if (map['projectId'] == null) map['projectId'] = projectId;
        return VideoTemplateExportEntity.fromJson(map);
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to queue export',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<VideoTemplateExportEntity> getExport({
    required String projectId,
    required String exportId,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.videoTemplateProjectExportById(projectId, exportId),
      );
      if (response.statusCode == 200) {
        final map = _unwrap(response.data);
        if (map['projectId'] == null) map['projectId'] = projectId;
        return VideoTemplateExportEntity.fromJson(map);
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load export',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<VideoTemplateExportEntity?> listenExportStream({
    required String projectId,
    required String exportId,
    void Function(VideoTemplateExportEntity snap)? onUpdate,
    Duration timeout = const Duration(minutes: 8),
  }) async {
    try {
      final response = await apiClient.dio.get<ResponseBody>(
        ApiConstants.videoTemplateProjectExportStream(projectId, exportId),
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'Accept': 'text/event-stream'},
          receiveTimeout: timeout,
          sendTimeout: const Duration(seconds: 20),
        ),
      );
      final byteStream = response.data?.stream;
      if (byteStream == null) return null;

      VideoTemplateExportEntity? last;
      final buffer = StringBuffer();
      await for (final chunk in byteStream.cast<List<int>>()) {
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        var content = buffer.toString().replaceAll('\r\n', '\n');
        while (true) {
          final sep = content.indexOf('\n\n');
          if (sep < 0) break;
          final block = content.substring(0, sep);
          content = content.substring(sep + 2);
          final entity = _parseSseExportBlock(
            block,
            projectId: projectId,
            exportId: exportId,
          );
          if (entity == null) continue;
          last = entity;
          onUpdate?.call(entity);
          if (entity.isComplete || entity.isFailed) {
            return entity;
          }
        }
        buffer
          ..clear()
          ..write(content);
      }
      return last;
    } on DioException catch (e) {
      debugPrint('listenExportStream Dio: ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('listenExportStream: $e\n$st');
      return null;
    }
  }

  VideoTemplateExportEntity? _parseSseExportBlock(
    String block, {
    required String projectId,
    required String exportId,
  }) {
    final dataLines = <String>[];
    for (final rawLine in block.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty || line.startsWith(':')) continue;
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
    if (dataLines.isEmpty) return null;
    final payload = dataLines.join('\n').trim();
    if (payload.isEmpty || payload == '[DONE]') return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      // Some streams nest under `export` / `data`.
      final nested = map['export'] ?? map['data'];
      final body = nested is Map
          ? Map<String, dynamic>.from(nested)
          : map;
      if (body['id'] == null) body['id'] = exportId;
      if (body['projectId'] == null) body['projectId'] = projectId;
      return VideoTemplateExportEntity.fromJson(body);
    } catch (_) {
      return null;
    }
  }

  TemplatePresetKind _presetKindFrom(String kind) {
    switch (kind.toUpperCase()) {
      case 'EFFECT':
        return TemplatePresetKind.effect;
      case 'STICKER':
        return TemplatePresetKind.sticker;
      default:
        return TemplatePresetKind.filter;
    }
  }

  List<TemplatePresetItem> _parsePresetList(dynamic body, String kind) {
    List<dynamic>? raw;
    if (body is List) {
      raw = body;
    } else if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      final data = map['data'] ?? map['items'] ?? map['presets'];
      if (data is List) raw = data;
    }
    if (raw == null) return const [];
    final presetKind = _presetKindFrom(kind);
    return raw
        .whereType<Map>()
        .map(
          (e) => TemplatePresetItem.fromJson(
            Map<String, dynamic>.from(e),
            kind: presetKind,
          ),
        )
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<TemplatePresetItem>> listPresets({
    required String kind,
    String? projectId,
    String? category,
    int limit = 50,
  }) async {
    try {
      final path = projectId != null
          ? ApiConstants.videoTemplateProjectPresets(projectId)
          : ApiConstants.videoTemplatePresets;
      final response = await apiClient.dio.get(
        path,
        queryParameters: {
          'kind': kind,
          if (category != null && category.isNotEmpty) 'category': category,
          'limit': limit,
        },
      );
      if (response.statusCode == 200) {
        return _parsePresetList(response.data, kind);
      }
      return const [];
    } on DioException catch (e) {
      debugPrint('listPresets: ${e.message}');
      return const [];
    }
  }

  @override
  Future<void> putSlotFilter({
    required String projectId,
    required String slotId,
    String? presetId,
    double intensity = 1,
  }) async {
    try {
      await apiClient.dio.put(
        ApiConstants.videoTemplateProjectSlotFilters(projectId, slotId),
        data: {
          if (presetId == null) 'presetId': null else 'presetId': presetId,
          'intensity': intensity,
        },
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> putSlotEffect({
    required String projectId,
    required String slotId,
    String? presetId,
  }) async {
    try {
      await apiClient.dio.put(
        ApiConstants.videoTemplateProjectSlotEffects(projectId, slotId),
        data: {
          if (presetId == null) 'presetId': null else 'presetId': presetId,
        },
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> createProjectText({
    required String projectId,
    required String text,
    double fontSize = 48,
    String color = '#FFFFFF',
    double positionY = 120,
    double startTime = 0,
    required double endTime,
  }) async {
    try {
      await apiClient.dio.post(
        ApiConstants.videoTemplateProjectTexts(projectId),
        data: {
          'text': text,
          'fontSize': fontSize,
          'color': color,
          'positionY': positionY,
          'startTime': startTime,
          'endTime': endTime,
        },
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> createProjectSticker({
    required String projectId,
    String? presetId,
    String? assetUrl,
    double positionX = 0,
    double positionY = -200,
    double scale = 1,
    double opacity = 1,
    double startTime = 0,
    double? endTime,
  }) async {
    try {
      await apiClient.dio.post(
        ApiConstants.videoTemplateProjectStickers(projectId),
        data: {
          if (presetId != null) 'presetId': presetId,
          if (assetUrl != null) 'assetUrl': assetUrl,
          'positionX': positionX,
          'positionY': positionY,
          'scale': scale,
          'opacity': opacity,
          'startTime': startTime,
          if (endTime != null) 'endTime': endTime,
        },
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
