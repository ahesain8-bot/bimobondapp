import 'dart:io';

import 'package:bimobondapp/app/posts/domain/usecases/upload_media_usecase.dart';
import 'package:bimobondapp/app/video_templates/data/datasources/video_template_asset_loader.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/repositories/video_templates_repository.dart';
import 'package:bimobondapp/app/video_templates/engine/template_engine.dart';
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

/// Orchestrates the mobile-api apply path (rendering guide):
/// 1) recipe  2) project  3) upload + PATCH slots  4) **server export** (recommended)
/// 5) client render only as offline / feature-fallback
///
/// Call [CompleteVideoTemplateProjectUseCase] **after** a successful `POST /posts`.
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
    /// Ignored — all exports are forced to server.
    bool? preferServerExport,
    /// If server export fails, try local compose (off by default — server-only).
    bool allowClientFallback = false,
    /// Force client compose even when server succeeds (rare; preview tools).
    bool renderClientVideo = false,
    /// Only create project + upload/PATCH slots (no encode). For client handoff.
    bool skipExport = false,
    /// Forced to `draft` for all server exports.
    String? exportQuality,
    int? fps,
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

    report(0.02, label: 'Preparing');

    // 1) Recipe (with overlays) — golden rule: always /recipe
    VideoTemplateRecipeEntity recipe;
    final existing = selection.recipe;
    if (existing != null &&
        (existing.slots.isNotEmpty || existing.slotCount > 0)) {
      recipe = existing;
    } else {
      final recipeResult = await repository.getRecipe(
        selection.templateId,
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
    // Forced policy: always server + draft (ignore preferredPath / caller).
    const quality = 'draft';
    debugPrint(
      'ApplyVideoTemplate path=server quality=draft '
      '(forced; preferredPath=${hints.preferredPath} '
      'complexity=${hints.complexity} '
      'callerPreferServer=$preferServerExport '
      'callerQuality=$exportQuality)',
    );

    // 2) Create project, or reuse only while still EDITING.
    // Completed projects reject PATCH ("Project is already completed").
    if (VideoTemplateProjectIds.isLocalClientId(selection.projectId)) {
      debugPrint(
        'ApplyVideoTemplate: ignoring client draft id '
        '${selection.projectId} — creating server project',
      );
    }
    final projectIdResult = await _ensureEditableProjectId(
      templateId: selection.templateId,
      title: projectTitle ?? selection.name,
      existingProjectId: selection.serverProjectId,
    );
    final projectId = projectIdResult.fold<String?>((_) => null, (id) => id);
    if (projectId == null) {
      return projectIdResult.fold(
        (f) => Left(f),
        (_) => Left(ServerFailure('project_create_failed')),
      );
    }

    // 3) Upload user media in parallel → `/uploads/...` for server render
    if (urls.isEmpty) {
      if (localFiles.isEmpty) {
        return Left(ServerFailure('no_media_for_template'));
      }
      report(0.05, label: 'Uploading');
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

    // 4) Fill UserProjectSlots in parallel (IMAGE vs VIDEO PATCH rules)
    report(0.2, label: 'Preparing slots');
    var activeProjectId = projectId;
    final slots = recipe.slots;
    if (slots.isNotEmpty) {
      final patchResult = await _patchProjectSlots(
        projectId: activeProjectId,
        recipe: recipe,
        urls: urls,
        localFiles: localFiles,
      );
      final patchFailure = patchResult.fold<Failure?>((f) => f, (_) => null);
      if (patchFailure != null) {
        if (_isProjectCompletedFailure(patchFailure)) {
          debugPrint(
            'ApplyVideoTemplate: slot PATCH hit completed project '
            '$activeProjectId — recreating',
          );
          final recreated = await _ensureEditableProjectId(
            templateId: selection.templateId,
            title: projectTitle ?? selection.name,
            existingProjectId: null,
          );
          final newId = recreated.fold<String?>((_) => null, (id) => id);
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

    // 5–6) Server export only — never encode IMAGE/VIDEO templates on device.
    VideoTemplateExportEntity? export;
    const File? renderedVideo = null;

    if (!skipExport) {
      if (renderClientVideo || allowClientFallback) {
        debugPrint(
          'ApplyVideoTemplate: ignoring client render flags '
          '(renderClientVideo=$renderClientVideo '
          'allowClientFallback=$allowClientFallback) — server-only policy',
        );
      }
      report(0.22, label: 'Rendering');
      export = await _queueAndWaitExport(
        projectId: activeProjectId,
        quality: 'draft',
        maxTicks: exportMaxTicks,
        onProgress: (entity) {
          // Server progress is 0..100 → map into overall 22%..92%.
          final pct = entity.progress.clamp(0, 100) / 100.0;
          report(
            0.22 + pct * 0.7,
            label: entity.stageLabel ?? 'Rendering',
          );
        },
      );
      if (export != null && export.isFailed) {
        debugPrint(
          'Server template export FAILED: '
          '${export.stageLabel ?? export.errorMessage ?? export.status}',
        );
      }
      final serverOk = export != null &&
          export.isComplete &&
          (export.exportUrl?.trim().isNotEmpty ?? false);
      if (serverOk) {
        report(0.95, label: export?.stageLabel ?? 'Almost done');
      }
    }

    report(1, label: 'Done');
    return Right(
      VideoTemplateApplyResult(
        selection: selection.copyWith(
          recipe: recipe,
          projectId: activeProjectId,
          slotCount: slotCount,
          templateKind: recipe.templateKind,
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

  Future<Either<Failure, String>> _ensureEditableProjectId({
    required String templateId,
    required String? title,
    String? existingProjectId,
  }) async {
    final existing =
        VideoTemplateProjectIds.normalizeServerId(existingProjectId);
    if (existing != null) {
      final got = await repository.getProject(existing);
      final project = got.fold<VideoTemplateProjectEntity?>((_) => null, (p) => p);
      if (project != null && project.isEditing) {
        return Right(existing);
      }
      debugPrint(
        'ApplyVideoTemplate: project $existing '
        'status=${project?.status ?? 'unknown'} — creating new project',
      );
    }

    final created = await repository.createProject(
      templateId: templateId,
      title: title,
    );
    final project = created.fold<VideoTemplateProjectEntity?>(
      (_) => null,
      (p) => p,
    );
    final createdId = VideoTemplateProjectIds.normalizeServerId(project?.id);
    if (createdId == null) {
      return created.fold(
        (f) => Left(f),
        (_) => Left(ServerFailure('project_create_failed')),
      );
    }
    return Right(createdId);
  }

  Future<Either<Failure, void>> _patchProjectSlots({
    required String projectId,
    required VideoTemplateRecipeEntity recipe,
    required List<String> urls,
    List<File> localFiles = const [],
  }) async {
    final slots = recipe.slots;
    final beats = recipe.beatTimestamps;
    final patchFutures = <Future<Either<Failure, dynamic>>>[];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (slot.id.isEmpty) continue;
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
          slotId: slot.id,
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
    required int maxTicks,
    void Function(VideoTemplateExportEntity entity)? onProgress,
  }) async {
    final queued = await repository.queueExport(
      projectId: projectId,
      quality: quality,
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
      // 500ms while PROCESSING, 2s while QUEUED (mobile-api checklist).
      final delay = last.isProcessing
          ? const Duration(milliseconds: 500)
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

