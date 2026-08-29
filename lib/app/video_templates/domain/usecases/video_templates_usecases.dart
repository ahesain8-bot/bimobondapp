import 'dart:io';

import 'package:bimobondapp/app/posts/domain/usecases/upload_media_usecase.dart';
import 'package:bimobondapp/app/video_templates/data/datasources/video_template_asset_loader.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/repositories/video_templates_repository.dart';
import 'package:bimobondapp/app/video_templates/engine/template_engine.dart';
import 'package:bimobondapp/app/video_templates/composition/composition_session.dart';
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_one_shot_render_builder.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/video_template_client_renderer.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/video_template_slot_filler.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

class ListPhotoVideoTemplatesUseCase {
  ListPhotoVideoTemplatesUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, List<VideoTemplateCardEntity>>> call({
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  }) {
    return repository.listPhotoTemplates(
      limit: limit,
      offset: offset,
      forceRefresh: forceRefresh,
    );
  }
}

class ListVideoTemplatesUseCase {
  ListVideoTemplatesUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, List<VideoTemplateCardEntity>>> call({
    String? templateKind,
    String? categoryId,
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  }) {
    return repository.listTemplates(
      templateKind: templateKind,
      categoryId: categoryId,
      limit: limit,
      offset: offset,
      forceRefresh: forceRefresh,
    );
  }
}

class ListFeaturedVideoTemplatesUseCase {
  ListFeaturedVideoTemplatesUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, List<VideoTemplateCardEntity>>> call({
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  }) {
    return repository.listFeatured(
      limit: limit,
      offset: offset,
      forceRefresh: forceRefresh,
    );
  }
}

class ListTrendingVideoTemplatesUseCase {
  ListTrendingVideoTemplatesUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, List<VideoTemplateCardEntity>>> call({
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  }) {
    return repository.listTrending(
      limit: limit,
      offset: offset,
      forceRefresh: forceRefresh,
    );
  }
}

class SearchVideoTemplatesUseCase {
  SearchVideoTemplatesUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, List<VideoTemplateCardEntity>>> call({
    required String query,
    int limit = 40,
    int offset = 0,
  }) {
    return repository.searchTemplates(
      query: query,
      limit: limit,
      offset: offset,
    );
  }
}

class ListVideoTemplatesBySoundUseCase {
  ListVideoTemplatesBySoundUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, List<VideoTemplateCardEntity>>> call({
    required String soundId,
    int limit = 40,
    int offset = 0,
    bool forceRefresh = false,
  }) {
    return repository.listBySound(
      soundId: soundId,
      limit: limit,
      offset: offset,
      forceRefresh: forceRefresh,
    );
  }
}

class ListVideoTemplateCategoriesUseCase {
  ListVideoTemplateCategoriesUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, List<TemplateCategoryEntity>>> call({
    bool forceRefresh = false,
  }) {
    return repository.listCategories(forceRefresh: forceRefresh);
  }
}

class GetVideoTemplateUseCase {
  GetVideoTemplateUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, VideoTemplateCardEntity>> call(
    String templateId, {
    bool forceRefresh = false,
  }) {
    return repository.getTemplate(templateId, forceRefresh: forceRefresh);
  }
}

class GetVideoTemplateRecipeUseCase {
  GetVideoTemplateRecipeUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, VideoTemplateRecipeEntity>> call(
    String templateId, {
    bool includeOverlays = true,
    bool forceRefresh = false,
    int? expectedVersion,
  }) {
    return repository.getRecipe(
      templateId,
      includeOverlays: includeOverlays,
      forceRefresh: forceRefresh,
      expectedVersion: expectedVersion,
    );
  }
}

class RecordVideoTemplateUseUseCase {
  RecordVideoTemplateUseUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, void>> call(String templateId) {
    return repository.recordUse(templateId);
  }
}

class CreateVideoTemplateProjectUseCase {
  CreateVideoTemplateProjectUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, VideoTemplateProjectEntity>> call({
    required String templateId,
    String? title,
  }) {
    return repository.createProject(templateId: templateId, title: title);
  }
}

class CreateProjectFromMediaUseCase {
  CreateProjectFromMediaUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, VideoTemplateProjectEntity>> call({
    required List<ProjectFromMediaInput> media,
    String? title,
  }) {
    return repository.createProjectFromMedia(media: media, title: title);
  }
}

class CompleteVideoTemplateProjectUseCase {
  CompleteVideoTemplateProjectUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, void>> call(String projectId) {
    return repository.completeProject(projectId);
  }
}

/// Open-template pipeline: recipe JSON → optional preview assets → editor pack.
///
/// Flow:
/// 1) download template JSON (cached)
/// 2) show preview (cover / previewVideo only)
/// 3) download required editor assets (lazy)
/// 4) ready for SlotEngine / editor
class PrepareVideoTemplateEditorUseCase {
  PrepareVideoTemplateEditorUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, PreparedVideoTemplateSession>> call({
    required String templateId,
    int? expectedVersion,
    bool includeOverlays = true,
    bool prefetchPreview = true,
    bool prefetchEditorAssets = true,
    bool includePlaceholders = false,
    bool forceRefresh = false,
    VideoTemplateCardEntity? card,
  }) async {
    final recipeResult = await repository.getRecipe(
      templateId,
      includeOverlays: includeOverlays,
      forceRefresh: forceRefresh,
      expectedVersion: expectedVersion ?? card?.version,
    );
    final recipe = recipeResult.fold<VideoTemplateRecipeEntity?>(
      (_) => null,
      (r) => r,
    );
    if (recipe == null) {
      return recipeResult.fold(
        (f) => Left(f),
        (_) => Left(ServerFailure('recipe_failed')),
      );
    }

    VideoTemplatePreviewAssets? preview;
    if (prefetchPreview) {
      final previewResult = await repository.prefetchPreviewAssets(
        recipe,
        card: card,
      );
      preview = previewResult.fold((_) => null, (p) => p);
    }

    Map<String, File> editorFiles = const {};
    if (prefetchEditorAssets) {
      final assetsResult = await repository.prefetchEditorAssets(
        recipe,
        includePlaceholders: includePlaceholders,
        includePreview: !prefetchPreview,
      );
      editorFiles = assetsResult.fold((_) => const {}, (m) => m);
    }

    // Best-effort use counter — never fails the prepare path.
    unawaitedRecordUse(templateId);

    return Right(
      PreparedVideoTemplateSession(
        recipe: recipe,
        card: card,
        preview: preview,
        localAssetFiles: editorFiles,
        selection: VideoTemplateSelection.fromRecipe(recipe),
      ),
    );
  }

  void unawaitedRecordUse(String templateId) {
    repository.recordUse(templateId);
  }
}

class PreparedVideoTemplateSession {
  const PreparedVideoTemplateSession({
    required this.recipe,
    required this.selection,
    this.card,
    this.preview,
    this.localAssetFiles = const {},
  });

  final VideoTemplateRecipeEntity recipe;
  final VideoTemplateSelection selection;
  final VideoTemplateCardEntity? card;
  final VideoTemplatePreviewAssets? preview;
  /// Absolute remote URL → local cached [File].
  final Map<String, File> localAssetFiles;

  bool get isReadyForEditor =>
      recipe.slots.isNotEmpty || recipe.slotCount > 0;
}

/// Result of recipe → project fill → server export (preferred) / client fallback.
class VideoTemplateApplyResult {
  const VideoTemplateApplyResult({
    required this.selection,
    required this.projectId,
    required this.uploadedUrls,
    required this.recipe,
    this.export,
    this.renderedVideo,
  });

  final VideoTemplateSelection selection;
  final String projectId;
  /// Server `/uploads/...` paths attached to UserProjectSlots.
  final List<String> uploadedUrls;
  final VideoTemplateRecipeEntity recipe;
  final VideoTemplateExportEntity? export;
  /// Client-rendered MP4 when server export unavailable / fallback.
  final File? renderedVideo;

  bool get hasRenderedVideo => renderedVideo != null;

  /// Prefer server `exportUrl`, else null (caller may upload client MP4).
  String? get serverExportUrl {
    final url = export?.exportUrl?.trim();
    if (url == null || url.isEmpty || export?.isComplete != true) return null;
    return MediaUtils.toServerUploadPath(url);
  }
}

/// Orchestrates the mobile rendering guide path:
/// 1) recipe  2) project  3) upload + PATCH slots
/// 4) **server export** (`POST …/export` → SSE/poll)
/// 5) client render only when [allowClientFallback] / offline
///
/// Call [CompleteVideoTemplateProjectUseCase] **after** a successful `POST /posts`
/// (or after Apply when posting immediately).
class ApplyVideoTemplateUseCase {
  ApplyVideoTemplateUseCase({
    required this.repository,
    required this.uploadMedia,
    TemplateEngine? engine,
  }) : engine = engine ?? TemplateEngine();

  final VideoTemplatesRepository repository;
  final UploadMediaUseCase uploadMedia;
  final TemplateEngine engine;

  Future<Either<Failure, VideoTemplateApplyResult>> call({
    required VideoTemplateSelection selection,
    List<File> localFiles = const [],
    List<String> uploadedUrls = const [],
    /// Prefer server FFmpeg worker (default). Set false to force client encode.
    bool preferServerExport = true,
    /// If server export fails, try local compose.
    bool allowClientFallback = true,
    /// Force client compose even when server succeeds (rare; preview tools).
    bool renderClientVideo = false,
    /// Only create project + upload/PATCH slots (no encode). For client handoff.
    bool skipExport = false,
    /// Final post → `standard`; fast preview/retry → `draft` (guide §5).
    String? exportQuality,
    String? resolution,
    double? fps,
    /// Catalog shelf UUID — omit for gallery / free edit (uses media[] only).
    String? catalogTemplateId,
    String? projectTitle,
    int exportMaxTicks = 240,
    /// Overall apply progress in `0..1` (upload → export → done).
    void Function(double progress, {String? label})? onProgress,
  }) async {
    void report(double p, {String? label}) {
      onProgress?.call(p.clamp(0.0, 1.0), label: label);
    }

    var urls = List<String>.from(
      uploadedUrls
          .map(MediaUtils.toServerUploadPath)
          .where((u) => u.isNotEmpty),
    );

    report(0.02, label: 'Preparing export…');

    // 1) Recipe (with overlays) — golden rule: always /recipe
    VideoTemplateRecipeEntity recipe;
    final existing = selection.recipe;
    if (existing != null &&
        (existing.slots.isNotEmpty || existing.slotCount > 0)) {
      recipe = existing;
    } else {
      final catalogId =
          VideoTemplateProjectIds.normalizeServerId(catalogTemplateId);
      if (catalogId == null) {
        return Left(
          ServerFailure(
            'recipe_failed — no catalog template and no local recipe',
          ),
        );
      }
      final recipeResult = await repository.getRecipe(
        catalogId,
        includeOverlays: true,
      );
      final recipeOr = recipeResult.fold<VideoTemplateRecipeEntity?>(
        (_) => null,
        (r) => r,
      );
      if (recipeOr == null) {
        return recipeResult.fold(
          (f) => Left(f),
          (_) => Left(ServerFailure('recipe_failed')),
        );
      }
      recipe = recipeOr;
    }

    final slotCount = recipe.applySlotCount;
    final hints = recipe.renderHints;
    final quality = _normalizeQuality(
      exportQuality ??
          (preferServerExport ? 'standard' : hints.recommendedFinalQuality),
    );
    final useServer = preferServerExport && !renderClientVideo;
    debugPrint(
      'ApplyVideoTemplate path=${useServer ? 'server' : 'client'} '
      'quality=$quality resolution=$resolution fps=$fps '
      '(preferredPath=${hints.preferredPath} complexity=${hints.complexity})',
    );

    // 2) Upload user media first when needed (required before Flow B project).
    if (urls.isEmpty) {
      if (localFiles.isEmpty) {
        return Left(ServerFailure('no_media_for_template'));
      }
      report(0.05, label: 'Uploading…');
      final uploadResults = await Future.wait(
        localFiles.map((file) => uploadMedia(file)),
      );
      final uniqueUploads = <String>[];
      for (final upload in uploadResults) {
        final url = upload.fold<String?>((_) => null, (u) => u);
        if (url == null || url.isEmpty) {
          return upload.fold(
            (f) => Left(f),
            (_) => Left(ServerFailure('upload_failed')),
          );
        }
        uniqueUploads.add(MediaUtils.toServerUploadPath(url));
      }
      urls = VideoTemplateSlotFiller.padByRepeat(uniqueUploads, slotCount);
      report(0.18, label: 'Uploaded');
    } else if (urls.length < slotCount) {
      urls = VideoTemplateSlotFiller.padByRepeat(urls, slotCount);
    }

    // 3) Create server project (Flow A catalog template or Flow B from-media).
    if (VideoTemplateProjectIds.isLocalClientId(selection.projectId)) {
      debugPrint(
        'ApplyVideoTemplate: ignoring client draft id '
        '${selection.projectId} — creating server project',
      );
    }
    final projectEntityResult = await _ensureEditableProject(
      selection: selection,
      title: projectTitle ?? selection.name,
      existingProjectId: selection.serverProjectId,
      urls: urls,
      localFiles: localFiles,
      catalogTemplateId: catalogTemplateId,
    );
    final projectEntity = projectEntityResult.fold<VideoTemplateProjectEntity?>(
      (_) => null,
      (p) => p,
    );
    if (projectEntity == null) {
      return projectEntityResult.fold(
        (f) => Left(f),
        (_) => Left(ServerFailure('project_create_failed')),
      );
    }
    final projectId = VideoTemplateProjectIds.normalizeServerId(
      projectEntity.id,
    );
    if (projectId == null) {
      return Left(ServerFailure('project_create_failed'));
    }
    var activeProjectId = projectId;
    final serverSlots = projectEntity.slots;

    // 4) Fill UserProjectSlots (Flow A) or refresh trims (Flow B may pre-fill).
    report(0.2, label: 'Preparing slots…');
    final slots = recipe.slots;
    if (slots.isNotEmpty) {
      final patchResult = await _patchProjectSlots(
        projectId: activeProjectId,
        recipe: recipe,
        urls: urls,
        localFiles: localFiles,
        serverSlots: serverSlots,
      );
      final patchFailure = patchResult.fold<Failure?>((f) => f, (_) => null);
      if (patchFailure != null) {
        if (_isProjectCompletedFailure(patchFailure)) {
          debugPrint(
            'ApplyVideoTemplate: slot PATCH hit completed project '
            '$activeProjectId — recreating',
          );
          final recreated = await _ensureEditableProject(
            selection: selection,
            title: projectTitle ?? selection.name,
            existingProjectId: null,
            urls: urls,
            localFiles: localFiles,
            catalogTemplateId: catalogTemplateId,
          );
          final newProject = recreated.fold<VideoTemplateProjectEntity?>(
            (_) => null,
            (p) => p,
          );
          final newId = VideoTemplateProjectIds.normalizeServerId(newProject?.id);
          if (newId == null) {
            return recreated.fold(
              (f) => Left(f),
              (_) => Left(ServerFailure('project_create_failed')),
            );
          }
          activeProjectId = newId;
          final retry = await _patchProjectSlots(
            projectId: activeProjectId,
            recipe: recipe,
            urls: urls,
            localFiles: localFiles,
            serverSlots: newProject?.slots ?? const [],
          );
          if (retry.isLeft()) {
            return retry.fold(
              (f) => Left(f),
              (_) => Left(ServerFailure('slot_patch_failed')),
            );
          }
        } else {
          return Left(patchFailure);
        }
      }
    }

    // 5–6) Server export (guide §4–7) → optional client fallback (§9)
    VideoTemplateExportEntity? export;
    File? renderedVideo;

    if (!skipExport) {
      var serverOk = false;
      if (useServer) {
        report(0.22, label: 'Preparing export…');
        export = await _queueAndWaitExport(
          projectId: activeProjectId,
          quality: quality,
          resolution: resolution,
          fps: fps,
          maxTicks: exportMaxTicks,
          onProgress: (entity) {
            final pct = entity.progress.clamp(0, 100) / 100.0;
            report(
              0.22 + pct * 0.7,
              label: entity.stageLabel ?? 'Rendering clips…',
            );
          },
        );
        if (export != null && export.isFailed) {
          debugPrint(
            'Server template export FAILED: '
            '${export.stageLabel ?? export.errorMessage ?? export.status}',
          );
        }
        serverOk = export != null &&
            export.isComplete &&
            (export.exportUrl?.trim().isNotEmpty ?? false);
        if (serverOk) {
          report(0.95, label: export.stageLabel ?? 'Export complete');
        }
      }

      final needClient = renderClientVideo ||
          (!serverOk && (allowClientFallback || !useServer));
      if (needClient) {
        report(0.35, label: 'Rendering on device…');
        final fills = <String, SlotFillEntry>{};
        for (var i = 0; i < recipe.slots.length; i++) {
          final slot = recipe.slots[i];
          if (slot.id.isEmpty) continue;
          final file = localFiles.isNotEmpty
              ? localFiles[i % localFiles.length]
              : null;
          if (file == null) continue;
          fills[slot.id] = SlotFillEntry(
            slotId: slot.id,
            slotIndex: slot.slotIndex,
            localFile: file,
            userAssetUrl: urls.isNotEmpty ? urls[i % urls.length] : null,
          );
        }
        final clientQuality = quality == 'draft'
            ? TemplateClientExportQuality.draft
            : TemplateClientExportQuality.standard;
        renderedVideo = await engine.export(
          recipe: recipe,
          fills: fills,
          quality: clientQuality,
          onProgress: (p) =>
              report(0.35 + p * 0.6, label: 'Rendering clips…'),
        );
        if (renderedVideo != null) {
          report(0.97, label: 'Finalizing…');
        }
      }
    }

    report(1, label: 'Export complete');
    return Right(
      VideoTemplateApplyResult(
        selection: selection.copyWith(
          recipe: recipe,
          projectId: activeProjectId,
          slotCount: slotCount,
          templateKind: recipe.templateKind,
          templateId: catalogTemplateId ?? '',
          sound: recipe.sound ?? selection.sound,
          soundSegmentId: recipe.soundSegmentId ?? selection.soundSegmentId,
        ),
        projectId: activeProjectId,
        uploadedUrls: urls,
        recipe: recipe,
        export: export,
        renderedVideo: renderedVideo,
      ),
    );
  }

  static String _normalizeQuality(String? raw) {
    final q = (raw ?? 'standard').trim().toLowerCase();
    return q == 'draft' ? 'draft' : 'standard';
  }

  Future<Either<Failure, VideoTemplateProjectEntity>> _ensureEditableProject({
    required VideoTemplateSelection selection,
    required String? title,
    required List<String> urls,
    required List<File> localFiles,
    String? existingProjectId,
    String? catalogTemplateId,
  }) async {
    final existing =
        VideoTemplateProjectIds.normalizeServerId(existingProjectId);
    if (existing != null) {
      final got = await repository.getProject(existing);
      final project =
          got.fold<VideoTemplateProjectEntity?>((_) => null, (p) => p);
      if (project != null && project.isEditing) {
        return Right(project);
      }
      debugPrint(
        'ApplyVideoTemplate: project $existing '
        'status=${project?.status ?? 'unknown'} — creating new project',
      );
    }

    final catalogId = VideoTemplateProjectIds.normalizeServerId(
      catalogTemplateId,
    );
    if (catalogId != null) {
      debugPrint('ApplyVideoTemplate: Flow A catalog template $catalogId');
      return repository.createProject(templateId: catalogId, title: title);
    }

    // Flow B — gallery / free edit (never send local_edit as templateId).
    if (urls.isEmpty) {
      return Left(
        ServerFailure('upload media before POST /projects/from-media'),
      );
    }
    final media = <ProjectFromMediaInput>[];
    for (var i = 0; i < urls.length; i++) {
      final url = urls[i];
      final local = localFiles.isNotEmpty
          ? localFiles[i % localFiles.length]
          : null;
      final isVideo = local != null
          ? VideoThumbnailUtils.isVideoFile(local)
          : _looksLikeVideoAsset(url);
      media.add(
        ProjectFromMediaInput(
          url: url,
          type: isVideo ? 'VIDEO' : 'IMAGE',
        ),
      );
    }
    debugPrint(
      'ApplyVideoTemplate: Flow B from-media (${media.length} clip(s))',
    );
    return repository.createProjectFromMedia(media: media, title: title);
  }

  static String _resolvePatchSlotId({
    required int slotIndex,
    required VideoTemplateSlotEntity recipeSlot,
    required List<VideoTemplateProjectSlotEntity> serverSlots,
  }) {
    for (final s in serverSlots) {
      if (s.slotIndex == slotIndex) {
        final id = s.patchSlotId;
        if (VideoTemplateProjectIds.isServerId(id)) return id;
      }
    }
    if (slotIndex < serverSlots.length) {
      final id = serverSlots[slotIndex].patchSlotId;
      if (VideoTemplateProjectIds.isServerId(id)) return id;
    }
    if (VideoTemplateProjectIds.isServerId(recipeSlot.id)) {
      return recipeSlot.id;
    }
    return recipeSlot.id;
  }

  Future<Either<Failure, void>> _patchProjectSlots({
    required String projectId,
    required VideoTemplateRecipeEntity recipe,
    required List<String> urls,
    List<File> localFiles = const [],
    List<VideoTemplateProjectSlotEntity> serverSlots = const [],
  }) async {
    final slots = recipe.slots;
    final beats = recipe.beatTimestamps;
    final patchFutures = <Future<Either<Failure, dynamic>>>[];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final patchSlotId = _resolvePatchSlotId(
        slotIndex: i,
        recipeSlot: slot,
        serverSlots: serverSlots,
      );
      if (patchSlotId.isEmpty ||
          !VideoTemplateProjectIds.isServerId(patchSlotId)) {
        debugPrint(
          '_patchProjectSlots: skip slot $i — no server slotId '
          '(recipeSlot=${slot.id})',
        );
        continue;
      }
      final url = urls[i % urls.length];
      final local = localFiles.isNotEmpty
          ? localFiles[i % localFiles.length]
          : null;
      // Prefer local file / VIDEO kind; URL extension alone is unreliable.
      final mediaIsVideo = (local != null &&
              VideoThumbnailUtils.isVideoFile(local)) ||
          _looksLikeVideoAsset(url);
      final isImage = !mediaIsVideo &&
          (slot.isImageOnly ||
              (!slot.acceptsVideo &&
                  (recipe.isPhotoCarousel || slot.isImage)));

      double? trimStart;
      double? trimEnd;
      double? speed;
      double? volume;
      if (!isImage) {
        trimStart = 0;
        final slotLen = slot.resolvedDurationSeconds;
        if (slot.syncToBeat &&
            slot.beatIndex != null &&
            slot.beatIndex! >= 0 &&
            slot.beatIndex! < beats.length) {
          trimStart = beats[slot.beatIndex!];
          if (slot.beatIndex! + 1 < beats.length) {
            trimEnd = beats[slot.beatIndex! + 1];
          } else if (slotLen > 0) {
            trimEnd = trimStart + slotLen;
          }
        } else if (slotLen > 0) {
          trimEnd = slotLen;
        }
        speed = 1;
        volume = 1;
      }

      patchFutures.add(
        repository.patchProjectSlot(
          projectId: projectId,
          slotId: patchSlotId,
          userAssetUrl: url,
          trimStart: trimStart,
          trimEnd: trimEnd,
          speed: speed,
          rotation: 0,
          scale: 1,
          volume: volume,
        ),
      );
    }
    final patched = await Future.wait(patchFutures);
    for (final result in patched) {
      if (result.isLeft()) {
        return result.fold(
          (f) => Left(f),
          (_) => Left(ServerFailure('slot_patch_failed')),
        );
      }
    }
    return const Right(null);
  }

  bool _isProjectCompletedFailure(Failure failure) {
    final msg = failure.message.toLowerCase();
    return msg.contains('already completed') ||
        msg.contains('project is already completed');
  }

  bool _looksLikeVideoAsset(String url) {
    final p = url.toLowerCase();
    return p.contains('.mp4') ||
        p.contains('.mov') ||
        p.contains('.m4v') ||
        p.contains('.webm') ||
        p.contains('.mkv') ||
        p.contains('video');
  }

  Future<VideoTemplateExportEntity?> _queueAndWaitExport({
    required String projectId,
    required String quality,
    String? resolution,
    double? fps,
    required int maxTicks,
    void Function(VideoTemplateExportEntity entity)? onProgress,
  }) async {
    final queued = await repository.queueExport(
      projectId: projectId,
      quality: quality,
      resolution: resolution,
      fps: fps,
    );
    final started = queued.fold<VideoTemplateExportEntity?>(
      (f) {
        debugPrint('queueExport failed: ${f.message}');
        return null;
      },
      (e) => e,
    );
    if (started == null || started.id.isEmpty) return started;

    var last = started;
    onProgress?.call(last);
    if (last.isComplete || last.isFailed) return last;

    // Prefer SSE progress; fall back to polling if stream unavailable.
    final streamed = await repository.listenExportStream(
      projectId: projectId,
      exportId: started.id,
      onUpdate: (entity) {
        last = entity;
        onProgress?.call(entity);
        if (entity.stageLabel != null && entity.stageLabel!.isNotEmpty) {
          debugPrint(
            'Template export SSE ${entity.progress.round()}% — '
            '${entity.stageLabel}',
          );
        }
      },
    );
    if (streamed != null) {
      onProgress?.call(streamed);
      return streamed;
    }

    for (var i = 0; i < maxTicks; i++) {
      // Guide §4: poll every 1–2s (faster while PROCESSING).
      final delay = last.isProcessing
          ? const Duration(seconds: 1)
          : const Duration(seconds: 2);
      await Future<void>.delayed(delay);
      final snap = await repository.getExport(
        projectId: projectId,
        exportId: started.id,
      );
      final entity = snap.fold<VideoTemplateExportEntity?>((_) => null, (e) => e);
      if (entity == null) continue;
      last = entity;
      onProgress?.call(entity);
      if (entity.stageLabel != null && entity.stageLabel!.isNotEmpty) {
        debugPrint(
          'Template export ${entity.progress.round()}% — ${entity.stageLabel}',
        );
      }
      if (entity.isComplete || entity.isFailed) return entity;
    }
    return last;
  }
}

/// One-shot server render per mobile guide: upload → `POST /render` → poll.
class OneShotRenderVideoTemplateUseCase {
  OneShotRenderVideoTemplateUseCase({
    required this.repository,
    required this.uploadMedia,
  });

  final VideoTemplatesRepository repository;
  final UploadMediaUseCase uploadMedia;

  Future<Either<Failure, VideoTemplateApplyResult>> call({
    required CompositionSession session,
    required VideoTemplateSelection selection,
    String? catalogTemplateId,
    String? exportQuality,
    String? resolution,
    double? fps,
    String? projectTitle,
    int exportMaxTicks = 240,
    void Function(double progress, {String? label})? onProgress,
  }) async {
    void report(double p, {String? label}) {
      onProgress?.call(p.clamp(0.0, 1.0), label: label);
    }

    final recipe = session.recipe;
    final slots = session.slots;
    if (slots.isEmpty) {
      return Left(ServerFailure('no_media_for_template'));
    }

    report(0.05, label: 'Uploading…');
    final slotIdToUrl = <String, String>{};
    final uploadedUrls = <String>[];

    for (final slot in slots) {
      final fill = session.fills[slot.id];
      if (fill == null) continue;

      String? url = fill.userAssetUrl != null
          ? MediaUtils.toServerUploadPath(fill.userAssetUrl!)
          : null;

      if (fill.localFile != null && fill.localFile!.path.isNotEmpty) {
        final upload = await uploadMedia(fill.localFile!);
        final uploaded = upload.fold<String?>((_) => null, (u) => u);
        if (uploaded == null || uploaded.isEmpty) {
          return upload.fold(
            (f) => Left(f),
            (_) => Left(ServerFailure('upload_failed')),
          );
        }
        url = MediaUtils.toServerUploadPath(uploaded);
      }

      if (url == null || url.isEmpty) continue;
      slotIdToUrl[slot.id] = url;
      uploadedUrls.add(url);
    }

    if (uploadedUrls.isEmpty) {
      return Left(ServerFailure('no_media_for_template'));
    }
    report(0.18, label: 'Uploaded');

    final filterPresetsResult = await repository.listPresets(kind: 'FILTER');
    final effectPresetsResult = await repository.listPresets(kind: 'EFFECT');
    final filterPresets = filterPresetsResult.fold(
      (_) => const <TemplatePresetItem>[],
      (list) => list,
    );
    final effectPresets = effectPresetsResult.fold(
      (_) => const <TemplatePresetItem>[],
      (list) => list,
    );

    final body = TemplateOneShotRenderBuilder.build(
      session: session,
      slotIdToUploadedUrl: slotIdToUrl,
      catalogTemplateId: null,
      title: projectTitle ?? selection.name,
      exportQuality: exportQuality,
      resolution: resolution,
      fps: fps,
      filterPresets: filterPresets,
      effectPresets: effectPresets,
      includeCatalogTemplateId: false,
      explicitEditedExport: true,
    );

    body.remove('templateId');
    TemplateOneShotRenderBuilder.stripCatalogTemplateKeys(body);

    debugPrint(
      'OneShotRender POST /render keys=${body.keys.toList()} '
      'hasTemplateId=${body.containsKey('templateId')} '
      'hasVideoTemplateId=${body.containsKey('videoTemplateId')} '
      'texts=${(body['texts'] as List?)?.length ?? 'omit'} '
      'stickers=${(body['stickers'] as List?)?.length ?? 'omit'} '
      'textsOwned=${session.userTextsLayerOwned} '
      'audios=${(body['audios'] as List?)?.length ?? 'omit'} '
      'durationSeconds=${body['durationSeconds']} '
      'slots=${body['slots']}',
    );
    final slotList = body['slots'];
    if (slotList is List && slotList.isNotEmpty) {
      final first = slotList.first;
      if (first is Map) {
        debugPrint(
          'OneShotRender slot0 filters=${first['filters']} '
          'filterName=${first['filterName']} '
          'effects=${first['effects']} '
          'effectType=${first['effectType']}',
        );
      }
    }

    if (body['media'] == null && body['templateId'] == null) {
      return Left(ServerFailure('no_media_for_template'));
    }

    report(0.22, label: 'Preparing export…');
    final jobResult = await repository.renderOneShot(body);
    final job = jobResult.fold<VideoTemplateRenderJobEntity?>(
      (_) => null,
      (j) => j,
    );
    if (job == null) {
      return jobResult.fold(
        (f) => Left(f),
        (_) => Left(ServerFailure('render_failed')),
      );
    }

    final projectId = VideoTemplateProjectIds.normalizeServerId(job.projectId);
    final exportId = job.exportId.trim();
    if (projectId == null || exportId.isEmpty) {
      return Left(ServerFailure('render_failed'));
    }

    var export = job.toExportEntity();
    if (export.isComplete || export.isFailed) {
      if (export.isFailed) {
        return Left(ServerFailure(export.stageLabel ?? 'Export failed'));
      }
    } else {
      export = await _waitForExport(
            projectId: projectId,
            exportId: exportId,
            initial: export,
            maxTicks: exportMaxTicks,
            onProgress: (entity) {
              final pct = entity.progress.clamp(0, 100) / 100.0;
              report(
                0.22 + pct * 0.7,
                label: entity.stageLabel ?? 'Rendering clips…',
              );
            },
          ) ??
          export;
    }

    if (export.isFailed) {
      return Left(
        ServerFailure(export.stageLabel ?? export.errorMessage ?? 'Export failed'),
      );
    }
    if (!export.isComplete ||
        (export.exportUrl?.trim().isEmpty ?? true)) {
      return Left(ServerFailure('export_timeout'));
    }

    report(0.95, label: export.stageLabel ?? 'Export complete');

    final updatedSelection = selection.copyWith(
      projectId: projectId,
      recipe: recipe,
      templateId: catalogTemplateId ?? '',
    );

    return Right(
      VideoTemplateApplyResult(
        selection: updatedSelection,
        projectId: projectId,
        uploadedUrls: uploadedUrls,
        recipe: recipe,
        export: export,
      ),
    );
  }

  Future<VideoTemplateExportEntity?> _waitForExport({
    required String projectId,
    required String exportId,
    required VideoTemplateExportEntity initial,
    required int maxTicks,
    void Function(VideoTemplateExportEntity entity)? onProgress,
  }) async {
    var last = initial;
    onProgress?.call(last);
    if (last.isComplete || last.isFailed) return last;

    final streamed = await repository.listenExportStream(
      projectId: projectId,
      exportId: exportId,
      onUpdate: (entity) {
        last = entity;
        onProgress?.call(entity);
      },
    );
    if (streamed != null) {
      onProgress?.call(streamed);
      return streamed;
    }

    for (var i = 0; i < maxTicks; i++) {
      final delay = last.isProcessing
          ? const Duration(seconds: 1)
          : const Duration(seconds: 2);
      await Future<void>.delayed(delay);
      final snap = await repository.getExport(
        projectId: projectId,
        exportId: exportId,
      );
      final entity = snap.fold<VideoTemplateExportEntity?>((_) => null, (e) => e);
      if (entity == null) continue;
      last = entity;
      onProgress?.call(entity);
      if (entity.isComplete || entity.isFailed) return entity;
    }
    return last;
  }
}

