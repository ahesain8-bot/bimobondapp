import 'dart:convert';
import 'dart:io';

import 'package:bimobondapp/app/camera_engine/remote/remote_effect_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local metadata + on-disk asset cache for Phase 8 remote effects.
class RemoteEffectCache {
  RemoteEffectCache._();
  static final RemoteEffectCache instance = RemoteEffectCache._();

  static const _prefsKey = 'camera_engine_remote_effects_catalog_v1';
  static const _installedKey = 'camera_engine_installed_effect_versions_v1';

  Future<Directory> effectsRoot() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/camera_engine_effects');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> effectDir(String effectId) async {
    final root = await effectsRoot();
    final dir = Directory('${root.path}/$effectId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> assetFilePath(String effectId, String assetKey) async {
    final dir = await effectDir(effectId);
    final safe = assetKey.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return '${dir.path}/$safe.png';
  }

  Future<void> saveCatalog(RemoteEffectCatalog catalog) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(catalog.toJson()));
  }

  Future<RemoteEffectCatalog?> loadCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return RemoteEffectCatalog.fromJson(map);
      }
      if (map is Map) {
        return RemoteEffectCatalog.fromJson(Map<String, dynamic>.from(map));
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, int>> installedVersions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_installedKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        return map.map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
        );
      }
    } catch (_) {}
    return {};
  }

  Future<void> setInstalledVersion(String effectId, int version) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await installedVersions();
    current[effectId] = version;
    await prefs.setString(_installedKey, jsonEncode(current));
  }

  Future<void> clearInstalledVersion(String effectId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await installedVersions();
    current.remove(effectId);
    await prefs.setString(_installedKey, jsonEncode(current));
  }

  Future<void> deleteEffectFiles(String effectId) async {
    final dir = await effectDir(effectId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await clearInstalledVersion(effectId);
  }
}
