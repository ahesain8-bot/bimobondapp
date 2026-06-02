import 'package:bimobondapp/core/theme/chat_wallpaper_id.dart';
import 'package:bimobondapp/core/theme/chat_wallpaper_preset.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatWallpaperCubit extends Cubit<ChatWallpaperId> {
  static const String _prefKey = 'chat_wallpaper_id';

  ChatWallpaperCubit(this._prefs)
      : super(_loadWallpaper(_prefs));

  final SharedPreferences _prefs;

  static ChatWallpaperId _loadWallpaper(SharedPreferences prefs) {
    return ChatWallpaperPresets.tryParse(prefs.getString(_prefKey)) ??
        ChatWallpaperId.plus;
  }

  void setWallpaper(ChatWallpaperId id) {
    if (state == id) return;
    _prefs.setString(_prefKey, id.name);
    emit(id);
  }
}
