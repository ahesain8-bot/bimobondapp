import 'dart:io';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';

/// Opens a full-screen zoomable preview for a chat image URL or local path.
Future<void> showChatImagePreview(
  BuildContext context, {
  required String imageUrl,
}) {
  final trimmed = imageUrl.trim();
  if (trimmed.isEmpty) return Future.value();

  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _ChatImagePreviewPage(imageUrl: trimmed),
        );
      },
    ),
  );
}

class _ChatImagePreviewPage extends StatelessWidget {
  const _ChatImagePreviewPage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
          Center(
            child: InteractiveViewer(
              minScale: 0.75,
              maxScale: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _PreviewImage(imageUrl: imageUrl),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolved = MediaUtils.resolveAbsoluteUrl(imageUrl);
    final localFile = File(resolved);
    if (localFile.existsSync()) {
      return Image.file(
        localFile,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    if (isValidNetworkImageUrl(resolved)) {
      return SafeNetworkImage(
        imageUrl: resolved,
        fit: BoxFit.contain,
        loadingSize: 48,
      );
    }

    return const Icon(
      Icons.broken_image_outlined,
      color: Colors.white54,
      size: 56,
    );
  }
}
