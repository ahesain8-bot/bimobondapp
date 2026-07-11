import 'package:bimobondapp/app/camera_studio/data/datasources/camera_studio_remote_data_source.dart';
import 'package:bimobondapp/app/camera_studio/data/models/camera_studio_catalog_model.dart';
import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/camera_studio/domain/usecases/get_camera_studio_catalog_usecase.dart';
import 'package:bimobondapp/app/camera_studio/presentation/di/camera_studio_injector.dart'
    as camera_studio_di;
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_placement.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';

class CameraStudioCatalogLoader {
  CameraStudioCatalogLoader(this._getCatalog);

  final GetCameraStudioCatalogUseCase _getCatalog;

  static void applyBundledCatalog() {
    final bundled = CameraStudioCatalogModel.bundled();
    CameraFilterCatalog.apply(bundled);
    CameraEffectsCatalog.apply(bundled);
  }

  Future<CameraStudioCatalogEntity> ensureLoaded({
    bool forceRefresh = false,
  }) async {
    late final dynamic result;
    await Future.wait([
      _getCatalog(
        GetCameraStudioCatalogParams(forceRefresh: forceRefresh),
      ).then((value) => result = value),
      _loadPlacementSchema(),
    ]);
    return result.fold(
      (_) {
        if (!CameraFilterCatalog.hasCatalog) applyBundledCatalog();
        return CameraFilterCatalog.activeCatalog;
      },
      (catalog) {
        if (catalog.filterCategories.isNotEmpty) {
          CameraFilterCatalog.apply(catalog);
        }
        if (catalog.effectCategories.isNotEmpty) {
          CameraEffectsCatalog.apply(catalog);
        }
        if (!CameraFilterCatalog.hasCatalog) applyBundledCatalog();
        return CameraFilterCatalog.activeCatalog;
      },
    );
  }

  Future<void> _loadPlacementSchema() async {
    try {
      final schema = await camera_studio_di
          .sl<CameraStudioRemoteDataSource>()
          .getEffectPlacementSchema();
      final defaults = schema['defaultsBySlug'];
      if (defaults is Map) {
        CameraEffectPlacementDefaults.applyRemoteDefaults(
          Map<String, dynamic>.from(defaults),
        );
      }
    } catch (_) {
      // Bundled defaults are enough offline.
    }
  }
}
