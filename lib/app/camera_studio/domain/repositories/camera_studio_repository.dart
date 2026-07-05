import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class CameraStudioRepository {
  Future<Either<Failure, CameraStudioCatalogEntity>> getCatalog({
    bool forceRefresh = false,
  });
}
