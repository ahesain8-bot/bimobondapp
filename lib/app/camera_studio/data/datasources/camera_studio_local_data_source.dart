import 'package:bimobondapp/app/camera_studio/data/models/camera_studio_catalog_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class CameraStudioLocalDataSource {
  Future<CameraStudioCatalogModel?> readCachedCatalog();
  Future<String?> readCachedVersion();
  Future<void> writeCatalog(CameraStudioCatalogModel catalog);
}

class CameraStudioLocalDataSourceImpl implements CameraStudioLocalDataSource {
  CameraStudioLocalDataSourceImpl({required this.sharedPreferences});

  static const _catalogKey = 'camera_studio_catalog_json';
  static const _versionKey = 'camera_studio_catalog_version';

  final SharedPreferences sharedPreferences;

  @override
  Future<CameraStudioCatalogModel?> readCachedCatalog() async {
    final raw = sharedPreferences.getString(_catalogKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CameraStudioCatalogModel.decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> readCachedVersion() async {
    return sharedPreferences.getString(_versionKey);
  }

  @override
  Future<void> writeCatalog(CameraStudioCatalogModel catalog) async {
    await sharedPreferences.setString(_catalogKey, catalog.encode());
    await sharedPreferences.setString(_versionKey, catalog.version);
  }
}
