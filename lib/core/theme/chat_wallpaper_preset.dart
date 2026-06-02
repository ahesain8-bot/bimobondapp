import 'package:bimobondapp/core/theme/chat_wallpaper_id.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

class ChatWallpaperPreset {
  const ChatWallpaperPreset({
    required this.id,
    required this.assetPath,
    required this.tileSize,
  });

  final ChatWallpaperId id;
  final String assetPath;
  final double tileSize;

  String label(AppLocalizations l10n) {
    switch (id) {
      case ChatWallpaperId.plus:
        return l10n.chatWallpaperPlus;
      case ChatWallpaperId.squares:
        return l10n.chatWallpaperSquares;
      case ChatWallpaperId.maze:
        return l10n.chatWallpaperMaze;
    }
  }
}

abstract final class ChatWallpaperPresets {
  ChatWallpaperPresets._();

  static const List<ChatWallpaperPreset> all = [
    ChatWallpaperPreset(
      id: ChatWallpaperId.plus,
      assetPath: 'assets/svgs/chat_pattern_plus.svg',
      tileSize: 40,
    ),
    ChatWallpaperPreset(
      id: ChatWallpaperId.squares,
      assetPath: 'assets/svgs/chat_pattern_squares.svg',
      tileSize: 32,
    ),
    ChatWallpaperPreset(
      id: ChatWallpaperId.maze,
      assetPath: 'assets/svgs/chat_pattern_maze.svg',
      tileSize: 48,
    ),
  ];

  static ChatWallpaperPreset byId(ChatWallpaperId id) {
    return all.firstWhere((preset) => preset.id == id);
  }

  static ChatWallpaperId? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final preset in all) {
      if (preset.id.name == value) return preset.id;
    }
    return null;
  }
}
