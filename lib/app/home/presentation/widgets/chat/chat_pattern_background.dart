import 'package:bimobondapp/core/theme/chat_wallpaper_id.dart';
import 'package:bimobondapp/core/theme/chat_wallpaper_preset.dart';
import 'package:bimobondapp/core/theme/cubit/chat_wallpaper_cubit.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_wallpaper_pattern_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatPatternBackground extends StatelessWidget {
  const ChatPatternBackground({
    required this.backgroundColor,
    required this.child,
    super.key,
  });

  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatWallpaperCubit, ChatWallpaperId>(
      builder: (context, wallpaperId) {
        final preset = ChatWallpaperPresets.byId(wallpaperId);
        return Stack(
          fit: StackFit.expand,
          children: [
            ChatWallpaperPatternLayer(
              preset: preset,
              backgroundColor: backgroundColor,
            ),
            child,
          ],
        );
      },
    );
  }
}
