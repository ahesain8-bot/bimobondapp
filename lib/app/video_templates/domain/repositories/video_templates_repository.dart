import 'dart:io';

import 'package:bimobondapp/app/video_templates/data/datasources/video_template_asset_loader.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

/// Template loading + project APIs. Metadata is cached; assets are lazy.
///
/// Alias: [TemplateRepository] (Phase 2 naming).
abstract class VideoTemplatesRepository {
  // --- Discovery ---

  Future<Either<Failure, List<VideoTemplateCardEntity>>> listPhotoTemplates({
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  });

  Future<Either<Failure, List<VideoTemplateCardEntity>>> listTemplates({
    String? templateKind,
    String? categoryId,
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  });

  Future<Either<Failure, List<VideoTemplateCardEntity>>> listFeatured({
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  });

  Future<Either<Failure, List<VideoTemplateCardEntity>>> listTrending({
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  });

  Future<Either<Failure, List<VideoTemplateCardEntity>>> searchTemplates({
    required String query,
    int limit = 40,
    int offset = 0,
  });

  Future<Either<Failure, List<VideoTemplateCardEntity>>> listBySound({
    required String soundId,
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  });

  Future<Either<Failure, List<TemplateCategoryEntity>>> listCategories({
    bool forceRefresh = false,
  });

  /// Lightweight template card / detail (not the full recipe).
  Future<Either<Failure, VideoTemplateCardEntity>> getTemplate(
    String templateId, {
    bool forceRefresh = false,
  });

  /// Primary editor contract. Caches JSON metadata only — no asset downloads.
  Future<Either<Failure, VideoTemplateRecipeEntity>> getRecipe(
    String templateId, {
    bool includeOverlays = false,
    bool forceRefresh = false,
    int? expectedVersion,
  });

  Future<Either<Failure, void>> recordUse(String templateId);

  // --- Lazy assets ---

  /// Cover + preview video only (detail screen).
  Future<Either<Failure, VideoTemplatePreviewAssets>> prefetchPreviewAssets(
    VideoTemplateRecipeEntity recipe, {
    VideoTemplateCardEntity? card,
  });

  /// Stickers / overlays / LUTs / fonts needed before the editor opens.
  Future<Either<Failure, Map<String, File>>> prefetchEditorAssets(
    VideoTemplateRecipeEntity recipe, {
    bool includePlaceholders = false,
    bool includePreview = true,
  });

  Future<Either<Failure, File?>> ensureAssetUrl(
    String url, {
    bool preferVideoCache = false,
  });

  void invalidateTemplateCache(String templateId, {int? newerVersion});

  void clearMetadataCache();

  // --- Projects / export ---

  Future<Either<Failure, VideoTemplateProjectEntity>> createProject({
    required String templateId,
    String? title,
  });

  /// Gallery / free edit — no catalog `templateId` (Flow B).
  Future<Either<Failure, VideoTemplateProjectEntity>> createProjectFromMedia({
    required List<ProjectFromMediaInput> media,
    String? title,
  });

  Future<Either<Failure, VideoTemplateProjectEntity>> getProject(
    String projectId,
  );

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
  });

  Future<Either<Failure, void>> completeProject(String projectId);

  Future<Either<Failure, VideoTemplateRenderJobEntity>> renderOneShot(
    Map<String, dynamic> body,
  );

  Future<Either<Failure, VideoTemplateExportEntity>> queueExport({
    required String projectId,
    String quality = 'standard',
    String? resolution,
    double? fps,
  });

  /// SSE export progress. Null = stream unavailable (caller should poll).
  Future<VideoTemplateExportEntity?> listenExportStream({
    required String projectId,
    required String exportId,
    void Function(VideoTemplateExportEntity snap)? onUpdate,
    Duration timeout = const Duration(minutes: 8),
  });

  Future<Either<Failure, VideoTemplateExportEntity>> getExport({
    required String projectId,
    required String exportId,
  });

  Future<Either<Failure, List<TemplatePresetItem>>> listPresets({
    required String kind,
    String? projectId,
    String? category,
    int limit = 50,
  });

  Future<Either<Failure, List<TemplateFontItem>>> listFonts();

  Future<Either<Failure, void>> putSlotFilter({
    required String projectId,
    required String slotId,
    String? presetId,
    double intensity = 1,
    double? startTime,
    double? endTime,
  });

  Future<Either<Failure, void>> putSlotEffect({
    required String projectId,
    required String slotId,
    String? presetId,
    double? startTime,
    double? endTime,
  });

  Future<Either<Failure, void>> putSlotFilterItems({
    required String projectId,
    required String slotId,
    required List<Map<String, dynamic>> items,
  });

  Future<Either<Failure, void>> putSlotEffectItems({
    required String projectId,
    required String slotId,
    required List<Map<String, dynamic>> items,
  });

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
  });

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
  });
}

/// Phase 2 schema-oriented alias for [VideoTemplatesRepository].
typedef TemplateRepository = VideoTemplatesRepository;
