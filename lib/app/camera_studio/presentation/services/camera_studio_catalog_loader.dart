import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/camera_studio/domain/usecases/get_camera_studio_catalog_usecase.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';

class CameraStudioCatalogLoader {
  CameraStudioCatalogLoader(this._getCatalog);

  final GetCameraStudioCatalogUseCase _getCatalog;

  Future<CameraStudioCatalogEntity> ensureLoaded({
    bool forceRefresh = false,
  }) async {
    final result = await _getCatalog(
      GetCameraStudioCatalogParams(forceRefresh: forceRefresh),
    );
    return result.fold(
      (_) => CameraFilterCatalog.activeCatalog,
      (catalog) {
        if (CameraFilterCatalog.isBackendCatalog(catalog)) {
          CameraFilterCatalog.apply(catalog);
          CameraEffectsCatalog.apply(catalog);
        }
        return CameraFilterCatalog.activeCatalog;
      },
    );
  }
}
