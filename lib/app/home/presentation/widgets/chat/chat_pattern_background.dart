import 'package:bimobondapp/core/theme/chat_wallpaper_preset.dart';
import 'package:bimobondapp/core/theme/cubit/chat_wallpaper_cubit.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_wallpaper_pattern_layer.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatPatternBackground extends StatelessWidget {
  const ChatPatternBackground({
    required this.backgroundColor,
    required this.child,
    this.wallpaperUrl,
    super.key,
  });

  final Color backgroundColor;
  final Widget child;
  final String? wallpaperUrl;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatWallpaperCubit, ChatWallpaperState>(
      builder: (context, wallpaperState) {
        final preset = ChatWallpaperPresets.byId(wallpaperState.presetId);
        final effectiveUrl = wallpaperUrl ?? wallpaperState.activeWallpaperUrl;

        Widget backgroundLayer;
        if (effectiveUrl != null && effectiveUrl.trim().isNotEmpty) {
          final rawUrl = effectiveUrl.trim();
          final formattedUrl = rawUrl.startsWith('http')
              ? rawUrl
              : '${ApiConstants.baseUrl}$rawUrl';

          backgroundLayer = Image.network(
            formattedUrl,
            key: ValueKey(formattedUrl),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => ChatWallpaperPatternLayer(
              preset: preset,
              backgroundColor: backgroundColor,
            ),
          );
        } else {
          backgroundLayer = ChatWallpaperPatternLayer(
            preset: preset,
            backgroundColor: backgroundColor,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            backgroundLayer,
            child,
          ],
        );
      },
    );
  }
}
