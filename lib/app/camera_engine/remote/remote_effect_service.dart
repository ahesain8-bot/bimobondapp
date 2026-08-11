import 'dart:convert';

import 'package:bimobondapp/app/camera_engine/native_camera_controller.dart';
import 'package:bimobondapp/app/camera_engine/remote/remote_effect_cache.dart';
import 'package:bimobondapp/app/camera_engine/remote/remote_effect_downloader.dart';
import 'package:bimobondapp/app/camera_engine/remote/remote_effect_models.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

/// Phase 8: fetch → cache metadata → download assets → install on native.
///
/// Flutter UI should list effects from [catalog] only — never hard-code effect ids.
class RemoteEffectService {
  RemoteEffectService({
    RemoteEffectDownloader? downloader,
    NativeCameraController? controller,
  })  : _downloader = downloader ?? RemoteEffectDownloader(),
        _controller = controller;

  final RemoteEffectDownloader _downloader;
  final NativeCameraController? _controller;
  final _cache = RemoteEffectCache.instance;

  RemoteEffectCatalog _catalog = const RemoteEffectCatalog(
    version: '0',
    effects: [],
  );

  RemoteEffectCatalog get catalog => _catalog;
  List<RemoteEffect> get effects => _catalog.effects;

  /// Refresh catalog: network → disk cache → bundled seed asset.
  Future<RemoteEffectCatalog> refresh({bool forceNetwork = true}) async {
    if (forceNetwork) {
      try {
        if (GetIt.instance.isRegistered<ApiClient>()) {
          final remote = await _fetchRemote();
          if (remote.effects.isNotEmpty) {
            _catalog = remote;
            await _cache.saveCatalog(remote);
            return _catalog;
          }
        }
      } catch (_) {
        // fall through to cache / seed
      }
    }

    final cached = await _cache.loadCatalog();
    if (cached != null && cached.effects.isNotEmpty) {
      _catalog = cached;
      return _catalog;
    }

    final seed = await _loadSeed();
    _catalog = seed;
    await _cache.saveCatalog(seed);
    return _catalog;
  }

  Future<RemoteEffectCatalog> _fetchRemote() async {
    final apiClient = GetIt.instance<ApiClient>();
    final response = await apiClient.dio.get(ApiConstants.cameraEngineEffects);
    if (response.statusCode != 200) {
      throw StateError('effects_http_${response.statusCode}');
    }
    return RemoteEffectCatalog.parse(response.data);
  }

  Future<RemoteEffectCatalog> _loadSeed() async {
    final raw = await rootBundle.loadString(
      'assets/camera_engine/effects_seed.json',
    );
    final decoded = jsonDecode(raw);
    return RemoteEffectCatalog.parse(decoded);
  }

  RemoteEffect? find(String id) {
    for (final e in _catalog.effects) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Download (if needed), install on Kotlin, and activate.
  Future<void> activate(
    String? effectId, {
    NativeCameraController? controller,
  }) async {
    final cam = controller ?? _controller;
    if (cam == null) {
      throw StateError('native_camera_controller_missing');
    }
    if (effectId == null || effectId.isEmpty || effectId == 'none') {
      await cam.setFaceEffect(null);
      return;
    }

    final effect = find(effectId);
    if (effect == null) {
      throw StateError('unknown_effect:$effectId');
    }

    if (effect.usesNativePreset) {
      await cam.setFaceEffect(effect.nativePresetId);
      return;
    }

    await _installRemote(effect, cam);
    await cam.setFaceEffect(effect.id);
    await _purgeUnused(keepIds: {effect.id}, controller: cam);
  }

  Future<void> _installRemote(
    RemoteEffect effect,
    NativeCameraController cam,
  ) async {
    final installed = await _cache.installedVersions();
    final current = installed[effect.id] ?? 0;
    final paths = await _downloader.ensureAssets(effect);

    // Skip native reload when version is already current and files exist.
    if (current >= effect.version && paths.length == effect.assets.length) {
      // Still ensure native has the definition (process may have restarted).
      await cam.installFaceEffect(
        id: effect.id,
        name: effect.name,
        version: effect.version,
        layers: _layerPayloads(effect, paths),
        force: current < effect.version,
      );
      return;
    }

    await cam.installFaceEffect(
      id: effect.id,
      name: effect.name,
      version: effect.version,
      layers: _layerPayloads(effect, paths),
      force: current < effect.version,
    );
    await _cache.setInstalledVersion(effect.id, effect.version);
  }

  List<Map<String, dynamic>> _layerPayloads(
    RemoteEffect effect,
    Map<String, String> paths,
  ) {
    final scale = effect.scale;
    final layers = effect.resolvedLayers();
    final out = <Map<String, dynamic>>[];
    for (final layer in layers) {
      final path = paths[layer.assetKey];
      if (path == null) continue;
      out.add({
        'assetId': '${effect.id}_${layer.assetKey}',
        'filePath': path,
        'leftLandmark': layer.leftLandmark,
        'rightLandmark': layer.rightLandmark,
        'anchorLandmark': layer.anchorLandmark,
        'pinX': layer.pinX,
        'pinY': layer.pinY,
        'widthOverRef': layer.widthOverRef * scale,
        'widthFaceFrac': layer.widthFaceFrac,
        'offsetXFaceFrac': layer.offsetXFaceFrac,
        'offsetYFaceFrac': layer.offsetYFaceFrac,
        'pivotU': layer.pivotU,
        'pivotV': layer.pivotV,
        'yawSqueeze': layer.yawSqueeze,
        'opacity': layer.opacity * effect.opacity,
      });
    }
    return out;
  }

  /// Release native resources / files for effects not in [keepIds].
  Future<void> _purgeUnused({
    required Set<String> keepIds,
    required NativeCameraController controller,
  }) async {
    final installed = await _cache.installedVersions();
    final drop = <String>[];
    for (final id in installed.keys) {
      if (!keepIds.contains(id)) drop.add(id);
    }
    if (drop.isEmpty) return;
    await controller.unloadFaceEffects(drop);
    for (final id in drop) {
      await _cache.deleteEffectFiles(id);
    }
  }
}
