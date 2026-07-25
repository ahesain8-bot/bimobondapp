import 'package:bimobondapp/app/ar_camera/ar_color_filter_catalog_model.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:get_it/get_it.dart';

/// Fetches the native AR camera's color filters from
/// `GET /camera-studio/color-filters` and applies them to [ArFilterCatalog].
///
/// Separate from `camera_studio_catalog_loader.dart`, which feeds the OLDER
/// CamerAwesome-based [CameraFilterCatalog] from `/camera-studio/catalog` —
/// that catalog uses a different filter model (GPU LUT-style presets) and
/// doesn't carry the beauty fields (blush/whiten/lipTint/etc.) this native
/// pipeline's shader needs, so it can't be reused here.
///
/// Always falls back to (and leaves untouched) the bundled static catalog —
/// see [ArFilterCatalog.restoreBundledColorCatalog] — on any failure: no
/// network, bad JSON, or an empty response.
class ArColorFilterRemoteLoader {
  ArColorFilterRemoteLoader._();

  static bool _loaded = false;

  static Future<void> ensureLoaded({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;
    _loaded = true;
    try {
      final apiClient = GetIt.instance<ApiClient>();
      final response = await apiClient.dio.get(
        ApiConstants.cameraStudioColorFilters,
      );
      if (response.statusCode != 200) return;
      final body = response.data;
      final json = body is Map<String, dynamic>
          ? body
          : body is Map
              ? Map<String, dynamic>.from(body)
              : null;
      if (json == null) return;

      final catalog = ArColorFilterCatalog.fromJson(json);
      if (catalog.categories.isEmpty) return;
      ArFilterCatalog.updateColorCatalog(catalog);
    } catch (_) {
      // Bundled catalog (already the default) is enough offline.
    }
  }
}
