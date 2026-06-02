import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_wallpaper_preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Tiled wallpaper layer using the app primary color on [backgroundColor].
class ChatWallpaperPatternLayer extends StatelessWidget {
  const ChatWallpaperPatternLayer({
    required this.preset,
    required this.backgroundColor,
    super.key,
  });

  final ChatWallpaperPreset preset;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Opacity(
        opacity: ChatLayoutConstants.chatPatternFillOpacity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tileSize = preset.tileSize;
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            if (!width.isFinite ||
                !height.isFinite ||
                width <= 0 ||
                height <= 0) {
              return const SizedBox.shrink();
            }

            final columnCount = (width / tileSize).ceil() + 1;
            final rowCount = (height / tileSize).ceil() + 1;

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (var row = 0; row < rowCount; row++)
                  for (var column = 0; column < columnCount; column++)
                    Positioned(
                      left: column * tileSize,
                      top: row * tileSize,
                      child: SvgPicture.asset(
                        preset.assetPath,
                        width: tileSize,
                        height: tileSize,
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
