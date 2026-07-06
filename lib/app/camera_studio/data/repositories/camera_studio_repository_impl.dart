import 'package:bimobondapp/app/camera_studio/data/datasources/camera_studio_local_data_source.dart';
import 'package:bimobondapp/app/camera_studio/data/datasources/camera_studio_remote_data_source.dart';
import 'package:bimobondapp/app/camera_studio/data/models/camera_studio_catalog_model.dart';
import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/camera_studio/domain/repositories/camera_studio_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

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
      if (!forceRefresh) {
        final cachedVersion = await localDataSource.readCachedVersion();
        if (cachedVersion != null && cachedVersion.isNotEmpty) {
          try {
            final remote = await remoteDataSource.getCatalog();
            if (remote.version == cachedVersion) {
              final cached = await localDataSource.readCachedCatalog();
              if (cached != null) return Right(cached);
            } else {
              await localDataSource.writeCatalog(remote);
              return Right(remote);
            }
          } catch (_) {
            final cached = await localDataSource.readCachedCatalog();
            if (cached != null) return Right(cached);
          }
        }
      }

      final remote = await remoteDataSource.getCatalog();
      await localDataSource.writeCatalog(remote);
      return Right(remote);
    } catch (e) {
      final cached = await localDataSource.readCachedCatalog();
      if (cached != null) return Right(cached);
      return Right(CameraStudioCatalogModel.bundled());
    }
  }
}
