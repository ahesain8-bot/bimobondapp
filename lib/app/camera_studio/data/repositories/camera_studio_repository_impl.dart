import 'package:bimobondapp/app/camera_studio/data/datasources/camera_studio_local_data_source.dart';
import 'package:bimobondapp/app/camera_studio/data/datasources/camera_studio_remote_data_source.dart';
import 'package:bimobondapp/app/camera_studio/data/models/camera_studio_catalog_model.dart';
import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/camera_studio/domain/repositories/camera_studio_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

class CameraStudioRepositoryImpl implements CameraStudioRepository {
  CameraStudioRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  final CameraStudioRemoteDataSource remoteDataSource;
  final CameraStudioLocalDataSource localDataSource;

  @override
  Future<Either<Failure, CameraStudioCatalogEntity>> getCatalog({
    bool forceRefresh = false,
  }) async {
    try {
      final remote = await remoteDataSource.getCatalog();
      if (remote.filterCategories.isEmpty && remote.effectCategories.isEmpty) {
        throw const FormatException('Empty camera studio catalog from API');
      }
      await localDataSource.writeCatalog(remote);
      debugPrint(
        'CameraStudio: loaded API catalog v${remote.version} '
        '(${remote.filterCategories.length} filter tabs, '
        '${remote.effectCategories.length} effect tabs)',
      );
      return Right(remote);
    } catch (e, st) {
      debugPrint('CameraStudio: API catalog fetch failed: $e\n$st');
    }

    if (!forceRefresh) {
      final cached = await localDataSource.readCachedCatalog();
      if (cached != null && cached.filterCategories.isNotEmpty) {
        debugPrint('CameraStudio: using cached catalog v${cached.version}');
        return Right(cached);
      }
    }

    debugPrint('CameraStudio: using bundled offline catalog');
    return Right(CameraStudioCatalogModel.bundled());
  }
}
