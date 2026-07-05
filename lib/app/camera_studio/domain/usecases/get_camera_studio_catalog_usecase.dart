import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/camera_studio/domain/repositories/camera_studio_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetCameraStudioCatalogUseCase
    implements UseCase<CameraStudioCatalogEntity, GetCameraStudioCatalogParams> {
  GetCameraStudioCatalogUseCase(this.repository);

  final CameraStudioRepository repository;

  @override
  Future<Either<Failure, CameraStudioCatalogEntity>> call(
    GetCameraStudioCatalogParams params,
  ) {
    return repository.getCatalog(forceRefresh: params.forceRefresh);
  }
}

class GetCameraStudioCatalogParams extends Equatable {
  const GetCameraStudioCatalogParams({this.forceRefresh = false});

  final bool forceRefresh;

  @override
  List<Object?> get props => [forceRefresh];
}
