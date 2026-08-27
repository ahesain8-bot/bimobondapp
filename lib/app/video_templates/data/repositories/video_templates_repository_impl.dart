import 'dart:io';

import 'package:bimobondapp/app/video_templates/data/datasources/video_template_asset_loader.dart';
import 'package:bimobondapp/app/video_templates/data/datasources/video_templates_local_cache.dart';
import 'package:bimobondapp/app/video_templates/data/datasources/video_templates_remote_data_source.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/app/video_templates/domain/repositories/video_templates_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

class VideoTemplatesRepositoryImpl implements VideoTemplatesRepository {
  VideoTemplatesRepositoryImpl({
    required this.remoteDataSource,
    required this.localCache,
    required this.assetLoader,
  });

  final VideoTemplatesRemoteDataSource remoteDataSource;
  final VideoTemplatesLocalCache localCache;
  final VideoTemplateAssetLoader assetLoader;

  Future<Either<Failure, List<VideoTemplateCardEntity>>> _cachedList({
    required String cacheKey,
    required Future<List<VideoTemplateCardEntity>> Function() fetch,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = localCache.getList(cacheKey);
      if (cached != null) return Right(cached);
    }
    try {
      final list = await fetch();
      localCache.putList(cacheKey, list);
      return Right(list);
    } catch (e) {
      final stale = localCache.getList(cacheKey);
      if (stale != null) return Right(stale);
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, List<VideoTemplateCardEntity>>> listPhotoTemplates({
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  }) {
    return _cachedList(
      cacheKey: VideoTemplatesLocalCache.listKey(
        shelf: 'photo',
        templateKind: VideoTemplateKinds.photoCarousel,
        limit: limit,
        offset: offset,
      ),
      forceRefresh: forceRefresh,
      fetch: () => remoteDataSource.listPhotoTemplates(
        limit: limit,
        offset: offset,
      ),
    );
  }

  @override
  Future<Either<Failure, List<VideoTemplateCardEntity>>> listTemplates({
    String? templateKind,
    String? categoryId,
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  }) {
    return _cachedList(
      cacheKey: VideoTemplatesLocalCache.listKey(
        shelf: 'catalog',
        templateKind: templateKind,
        categoryId: categoryId,
        limit: limit,
        offset: offset,
      ),
      forceRefresh: forceRefresh,
      fetch: () => remoteDataSource.listTemplates(
        templateKind: templateKind,
        categoryId: categoryId,
        limit: limit,
        offset: offset,
      ),
    );
  }

  @override
  Future<Either<Failure, List<VideoTemplateCardEntity>>> listFeatured({
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  }) {
    return _cachedList(
      cacheKey: VideoTemplatesLocalCache.listKey(
        shelf: 'featured',
        limit: limit,
        offset: offset,
      ),
      forceRefresh: forceRefresh,
      fetch: () => remoteDataSource.listFeatured(limit: limit, offset: offset),
    );
  }

  @override
  Future<Either<Failure, List<VideoTemplateCardEntity>>> listTrending({
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  }) {
    return _cachedList(
      cacheKey: VideoTemplatesLocalCache.listKey(
        shelf: 'trending',
        limit: limit,
        offset: offset,
      ),
      forceRefresh: forceRefresh,
      fetch: () => remoteDataSource.listTrending(limit: limit, offset: offset),
    );
  }

  @override
  Future<Either<Failure, List<VideoTemplateCardEntity>>> searchTemplates({
    required String query,
    int limit = 40,
    int offset = 0,
  }) async {
    // Search results are not cached (query-sensitive / short-lived).
    try {
      final list = await remoteDataSource.searchTemplates(
        query: query,
        limit: limit,
        offset: offset,
      );
      localCache.putCards(list);
      return Right(list);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, List<VideoTemplateCardEntity>>> listBySound({
    required String soundId,
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  }) {
    return _cachedList(
      cacheKey: VideoTemplatesLocalCache.listKey(
        shelf: 'by-sound',
        soundId: soundId,
        limit: limit,
        offset: offset,
      ),
      forceRefresh: forceRefresh,
      fetch: () => remoteDataSource.listBySound(
        soundId: soundId,
        limit: limit,
        offset: offset,
      ),
    );
  }

  @override
  Future<Either<Failure, List<TemplateCategoryEntity>>> listCategories({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = localCache.getCategories();
      if (cached != null) return Right(cached);
    }
    try {
      final list = await remoteDataSource.listCategories();
      localCache.putCategories(list);
      return Right(list);
    } catch (e) {
      final stale = localCache.getCategories();
      if (stale != null) return Right(stale);
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, VideoTemplateCardEntity>> getTemplate(
    String templateId, {
    bool forceRefresh = false,
  }) async {
    final id = templateId.trim();
    if (id.isEmpty) {
      return Left(ServerFailure('template_id_required'));
    }
    if (!forceRefresh) {
      final cached = localCache.getCard(id);
      if (cached != null) return Right(cached);
    }
    try {
      final card = await remoteDataSource.getTemplate(id);
      final previous = localCache.getCard(id);
      if (previous != null && previous.version != card.version) {
        localCache.invalidateTemplate(id, newerVersion: card.version);
      }
      localCache.putCard(card);
      return Right(card);
    } catch (e) {
      final stale = localCache.getCard(id);
      if (stale != null) return Right(stale);
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, VideoTemplateRecipeEntity>> getRecipe(
    String templateId, {
    bool includeOverlays = false,
    bool forceRefresh = false,
    int? expectedVersion,
  }) async {
    final id = templateId.trim();
    if (id.isEmpty) {
      return Left(ServerFailure('template_id_required'));
    }

    if (!forceRefresh) {
      final cached = localCache.getRecipe(
        id,
        includeOverlays: includeOverlays,
        expectedVersion: expectedVersion,
      );
      // Prefer any cached recipe for instant template apply. Soft preview
      // only needs effects/layouts; stale renderHints still look correct.
      if (cached != null) {
        return Right(cached);
      }
    }

    try {
      final recipe = await remoteDataSource.getRecipe(
        id,
        includeOverlays: includeOverlays,
      );
      if (expectedVersion != null &&
          expectedVersion > 0 &&
          recipe.version != expectedVersion) {
        // Server returned a different version than the shelf card — still
        // accept it (source of truth) but drop older sibling caches.
        localCache.invalidateTemplate(id);
      }
      localCache.putRecipe(recipe, includeOverlays: includeOverlays);
      return Right(recipe);
    } catch (e) {
      final stale = localCache.getRecipe(
        id,
        includeOverlays: includeOverlays,
        expectedVersion: null,
      );
      if (stale != null) return Right(stale);
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> recordUse(String templateId) async {
    try {
      await remoteDataSource.recordUse(templateId);
      return const Right(null);
    } catch (_) {
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, VideoTemplatePreviewAssets>> prefetchPreviewAssets(
    VideoTemplateRecipeEntity recipe, {
    VideoTemplateCardEntity? card,
  }) async {
    try {
      final assets = await assetLoader.prefetchPreview(recipe, card: card);
      return Right(assets);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, File>>> prefetchEditorAssets(
    VideoTemplateRecipeEntity recipe, {
    bool includePlaceholders = false,
    bool includePreview = true,
  }) async {
    try {
      final files = await assetLoader.prefetchEditorAssets(
        recipe,
        includePlaceholders: includePlaceholders,
        includePreview: includePreview,
      );
      return Right(files);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, File?>> ensureAssetUrl(
    String url, {
    bool preferVideoCache = false,
  }) async {
    try {
      final file = await assetLoader.ensureUrl(
        url,
        preferVideoCache: preferVideoCache,
      );
      return Right(file);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  void invalidateTemplateCache(String templateId, {int? newerVersion}) {
    localCache.invalidateTemplate(templateId, newerVersion: newerVersion);
  }

  @override
  void clearMetadataCache() {
    localCache.clearAll();
    assetLoader.clearSession();
  }

  @override
  Future<Either<Failure, VideoTemplateProjectEntity>> createProject({
    required String templateId,
    String? title,
  }) async {
    final id = VideoTemplateProjectIds.normalizeServerId(templateId);
    if (id == null) {
      debugPrint(
        'createProject blocked — templateId must be a UUID '
        '(got "$templateId")',
      );
      return Left(
        ServerFailure(
          'templateId must be a UUID — use the template id from '
          'GET /video-templates/:id (not name or slug)',
        ),
      );
    }
    try {
      return Right(
        await remoteDataSource.createProject(
          templateId: id,
          title: title,
        ),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, VideoTemplateProjectEntity>> createProjectFromMedia({
    required List<ProjectFromMediaInput> media,
    String? title,
  }) async {
    if (media.isEmpty) {
      return Left(ServerFailure('media is required for from-media project'));
    }
    try {
      return Right(
        await remoteDataSource.createProjectFromMedia(
          media: media,
          title: title,
        ),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, VideoTemplateProjectEntity>> getProject(
    String projectId,
  ) async {
    try {
      return Right(await remoteDataSource.getProject(projectId));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, VideoTemplateProjectSlotEntity>> patchProjectSlot({
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
      return Right(
        await remoteDataSource.patchProjectSlot(
          projectId: projectId,
          slotId: slotId,
          userAssetUrl: userAssetUrl,
          trimStart: trimStart,
          trimEnd: trimEnd,
          speed: speed,
          rotation: rotation,
          scale: scale,
          volume: volume,
        ),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> completeProject(String projectId) async {
    try {
      await remoteDataSource.completeProject(projectId);
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, VideoTemplateRenderJobEntity>> renderOneShot(
    Map<String, dynamic> body,
  ) async {
    try {
      return Right(await remoteDataSource.renderOneShot(body));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, VideoTemplateExportEntity>> queueExport({
    required String projectId,
    String quality = 'standard',
    String? resolution,
    double? fps,
  }) async {
    try {
      return Right(
        await remoteDataSource.queueExport(
          projectId: projectId,
          quality: quality,
          resolution: resolution,
          fps: fps,
        ),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, VideoTemplateExportEntity>> getExport({
    required String projectId,
    required String exportId,
  }) async {
    try {
      return Right(
        await remoteDataSource.getExport(
          projectId: projectId,
          exportId: exportId,
        ),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<VideoTemplateExportEntity?> listenExportStream({
    required String projectId,
    required String exportId,
    void Function(VideoTemplateExportEntity snap)? onUpdate,
    Duration timeout = const Duration(minutes: 8),
  }) {
    return remoteDataSource.listenExportStream(
      projectId: projectId,
      exportId: exportId,
      onUpdate: onUpdate,
      timeout: timeout,
    );
  }

  @override
  Future<Either<Failure, List<TemplatePresetItem>>> listPresets({
    required String kind,
    String? projectId,
    String? category,
    int limit = 50,
  }) async {
    try {
      return Right(
        await remoteDataSource.listPresets(
          kind: kind,
          projectId: projectId,
          category: category,
          limit: limit,
        ),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, List<TemplateFontItem>>> listFonts() async {
    try {
      return Right(await remoteDataSource.listFonts());
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> putSlotFilter({
    required String projectId,
    required String slotId,
    String? presetId,
    double intensity = 1,
    double? startTime,
    double? endTime,
  }) async {
    try {
      await remoteDataSource.putSlotFilter(
        projectId: projectId,
        slotId: slotId,
        presetId: presetId,
        intensity: intensity,
        startTime: startTime,
        endTime: endTime,
      );
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> putSlotEffect({
    required String projectId,
    required String slotId,
    String? presetId,
    double? startTime,
    double? endTime,
  }) async {
    try {
      await remoteDataSource.putSlotEffect(
        projectId: projectId,
        slotId: slotId,
        presetId: presetId,
        startTime: startTime,
        endTime: endTime,
      );
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> putSlotFilterItems({
    required String projectId,
    required String slotId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await remoteDataSource.putSlotFilterItems(
        projectId: projectId,
        slotId: slotId,
        items: items,
      );
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> putSlotEffectItems({
    required String projectId,
    required String slotId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await remoteDataSource.putSlotEffectItems(
        projectId: projectId,
        slotId: slotId,
        items: items,
      );
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> createProjectText({
    required String projectId,
    required String text,
    double fontSize = 48,
    String color = '#FFFFFF',
    double positionX = 0,
    double positionY = 120,
    double startTime = 0,
    required double endTime,
    String? fontAssetId,
  }) async {
    try {
      await remoteDataSource.createProjectText(
        projectId: projectId,
        text: text,
        fontSize: fontSize,
        color: color,
        positionX: positionX,
        positionY: positionY,
        startTime: startTime,
        endTime: endTime,
        fontAssetId: fontAssetId,
      );
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> createProjectSticker({
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
      await remoteDataSource.createProjectSticker(
        projectId: projectId,
        presetId: presetId,
        assetUrl: assetUrl,
        positionX: positionX,
        positionY: positionY,
        scale: scale,
        opacity: opacity,
        startTime: startTime,
        endTime: endTime,
      );
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
