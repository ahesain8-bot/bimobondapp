import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/ar_camera/ar_overlay_catalog_model.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:get_it/get_it.dart';

/// Fetches the camera's full-screen Lottie overlays from
/// `GET /camera-studio/ar-overlays` and applies them to [ArFilterCatalog].
///
/// Mirrors [ArColorFilterRemoteLoader]'s contract: always falls back to (and
/// leaves untouched) the bundled catalog on any failure — no network, bad JSON,
/// or an empty response — so the effect carousel still has its four shipped
/// overlays offline.
class ArOverlayRemoteLoader {
  ArOverlayRemoteLoader._();

  static bool _loaded = false;

  static Future<void> ensureLoaded({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;
    _loaded = true;
    try {
      final apiClient = GetIt.instance<ApiClient>();
      final response = await apiClient.dio.get(
        ApiConstants.cameraStudioArOverlays,
      );
      if (response.statusCode != 200) return;
      final body = response.data;
      final json = body is Map<String, dynamic>
          ? body
          : body is Map
          ? Map<String, dynamic>.from(body)
          : null;
      if (json == null) return;

      final catalog = ArOverlayCatalog.fromJson(json);
      if (catalog.overlays.isEmpty) return;
      ArFilterCatalog.updateOverlayCatalog(catalog);
    } catch (_) {
      // Bundled catalog (already the default) is enough offline.
    }
  }
}
