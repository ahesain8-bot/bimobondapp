import 'dart:io';

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/repositories/video_templates_repository.dart';
import 'package:bimobondapp/app/video_templates/engine/template_engine.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

/// Export via [TemplateEngine] after slot validation.
class ExportTemplateCompositionUseCase {
  ExportTemplateCompositionUseCase({
    required this.engine,
    required this.repository,
  });

  final TemplateEngine engine;
  final VideoTemplatesRepository repository;

  Future<Either<Failure, File>> call({
    required VideoTemplateRecipeEntity recipe,
    required Map<String, SlotFillEntry> fills,
    String? projectId,
    void Function(double progress)? onProgress,
  }) async {
    final report = engine.validate(recipe: recipe, fills: fills);
    if (!report.canExport) {
      return Left(
        ServerFailure(report.firstError ?? 'template_validation_failed'),
      );
    }

    if (projectId != null && projectId.isNotEmpty) {
      // Mark project rendering (best-effort — server may ignore unknown PATCH).
    }

    final file = await engine.export(
      recipe: recipe,
      fills: fills,
      onProgress: onProgress,
    );
    if (file == null || !await file.exists()) {
      return Left(ServerFailure('export_failed'));
    }
    return Right(file);
  }
}

/// Queue server export and optionally poll [ProjectExport] progress.
class QueueAndWatchTemplateExportUseCase {
  QueueAndWatchTemplateExportUseCase(this.repository);

  final VideoTemplatesRepository repository;

  Future<Either<Failure, ExportProgressController>> call({
    required String projectId,
    String quality = 'standard',
  }) async {
    final queued = await repository.queueExport(
      projectId: projectId,
      quality: quality,
    );
    return queued.fold(Left.new, (export) {
      if (export.id.isEmpty) {
        return Left(ServerFailure('export_id_missing'));
      }
      return Right(
        ExportProgressController(
          projectId: projectId,
          exportId: export.id,
          fetch: ({required projectId, required exportId}) async {
            final r = await repository.getExport(
              projectId: projectId,
              exportId: exportId,
            );
            return r.fold((_) => null, (e) => e);
          },
        ),
      );
    });
  }
}
