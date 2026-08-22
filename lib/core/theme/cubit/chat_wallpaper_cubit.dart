import 'package:bimobondapp/core/theme/chat_wallpaper_id.dart';
import 'package:bimobondapp/core/theme/chat_wallpaper_preset.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatWallpaperState extends Equatable {
  final ChatWallpaperId presetId;
  final String? activeWallpaperUrl;

  const ChatWallpaperState({
    this.presetId = ChatWallpaperId.plus,
    this.activeWallpaperUrl,
  });

  ChatWallpaperState copyWith({
    ChatWallpaperId? presetId,
    String? activeWallpaperUrl,
    bool clearUrl = false,
  }) {
    return ChatWallpaperState(
      presetId: presetId ?? this.presetId,
      activeWallpaperUrl: clearUrl ? null : (activeWallpaperUrl ?? this.activeWallpaperUrl),
    );
  }

  @override
  List<Object?> get props => [presetId, activeWallpaperUrl];
}

class ChatWallpaperCubit extends Cubit<ChatWallpaperState> {
  static const String _prefKey = 'chat_wallpaper_id';
  static const String _prefUrlKey = 'chat_wallpaper_url';

  ChatWallpaperCubit(this._prefs) : super(_loadWallpaper(_prefs));

  final SharedPreferences _prefs;

  static ChatWallpaperState _loadWallpaper(SharedPreferences prefs) {
    final presetId =
        ChatWallpaperPresets.tryParse(prefs.getString(_prefKey)) ??
            ChatWallpaperId.plus;
    final url = prefs.getString(_prefUrlKey);
    return ChatWallpaperState(presetId: presetId, activeWallpaperUrl: url);
  }

  void setWallpaper(ChatWallpaperId id) {
    _prefs.setString(_prefKey, id.name);
    _prefs.remove(_prefUrlKey);
    emit(state.copyWith(presetId: id, clearUrl: true));
  }

  void setNetworkWallpaper(String? url) {
    if (url == null || url.trim().isEmpty) {
      _prefs.remove(_prefUrlKey);
      emit(state.copyWith(clearUrl: true));
    } else {
      _prefs.setString(_prefUrlKey, url.trim());
      emit(state.copyWith(activeWallpaperUrl: url.trim()));
    }
  }
}
