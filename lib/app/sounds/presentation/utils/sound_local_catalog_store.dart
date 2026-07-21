import 'dart:convert';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local favorites + recent sound catalog for the TikTok-style picker.
class SoundLocalCatalogStore {
  SoundLocalCatalogStore._();

  static const _favoritesKey = 'sound_picker_favorites_v1';
  static const _recentKey = 'sound_picker_recent_v1';
  static const _maxRecent = 40;

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<List<SoundEntity>> listFavorites() async {
    final prefs = await _prefs;
    return _decodeList(prefs.getStringList(_favoritesKey));
  }

  static Future<List<SoundEntity>> listRecent() async {
    final prefs = await _prefs;
    return _decodeList(prefs.getStringList(_recentKey));
  }

  static Future<bool> isFavorite(String soundId) async {
    final id = soundId.trim();
    if (id.isEmpty) return false;
    final list = await listFavorites();
    return list.any((s) => s.id == id);
  }

  static Future<bool> toggleFavorite(SoundEntity sound) async {
    final prefs = await _prefs;
    final list = await listFavorites();
    final id = sound.id.trim();
    final index = list.indexWhere((s) => s.id == id);
    if (index >= 0) {
      list.removeAt(index);
      await prefs.setStringList(_favoritesKey, _encodeList(list));
      return false;
    }
    list.insert(0, sound);
    await prefs.setStringList(_favoritesKey, _encodeList(list));
    return true;
  }

  static Future<void> pushRecent(SoundEntity sound) async {
    final prefs = await _prefs;
    final list = await listRecent();
    list.removeWhere((s) => s.id == sound.id);
    list.insert(0, sound);
    if (list.length > _maxRecent) {
      list.removeRange(_maxRecent, list.length);
    }
    await prefs.setStringList(_recentKey, _encodeList(list));
  }

  static List<String> _encodeList(List<SoundEntity> sounds) {
    return sounds.map((s) => jsonEncode(s.toJson())).toList();
  }

  static List<SoundEntity> _decodeList(List<String>? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final out = <SoundEntity>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item);
        if (map is Map) {
          out.add(SoundEntity.fromJson(Map<String, dynamic>.from(map)));
        }
      } catch (_) {
        // Skip corrupt entries.
      }
    }
    return out;
  }
}
