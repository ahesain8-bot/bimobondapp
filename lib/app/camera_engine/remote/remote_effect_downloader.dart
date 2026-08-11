import 'dart:io';

import 'package:bimobondapp/app/camera_engine/remote/remote_effect_cache.dart';
import 'package:bimobondapp/app/camera_engine/remote/remote_effect_models.dart';
import 'package:dio/dio.dart';

/// Downloads remote effect PNGs into the local cache directory.
class RemoteEffectDownloader {
  RemoteEffectDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final _cache = RemoteEffectCache.instance;

  /// Ensures all asset files for [effect] exist locally. Returns key → path.
  Future<Map<String, String>> ensureAssets(RemoteEffect effect) async {
    final out = <String, String>{};
    for (final entry in effect.assets.entries) {
      final key = entry.key;
      final url = entry.value;
      if (url.isEmpty) continue;
      final path = await _cache.assetFilePath(effect.id, key);
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        await _download(url, path);
      }
      out[key] = path;
    }
    return out;
  }

  Future<String?> ensureThumbnail(RemoteEffect effect) async {
    final url = effect.thumbnail;
    if (url == null || url.isEmpty) return null;
    final dir = await _cache.effectDir(effect.id);
    final path = '${dir.path}/thumb.jpg';
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      try {
        await _download(url, path);
      } catch (_) {
        return null;
      }
    }
    return path;
  }

  Future<void> _download(String url, String path) async {
    final tmp = '$path.part';
    await _dio.download(
      url,
      tmp,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    final part = File(tmp);
    if (!await part.exists()) {
      throw StateError('download_failed:$url');
    }
    await part.rename(path);
  }
}
