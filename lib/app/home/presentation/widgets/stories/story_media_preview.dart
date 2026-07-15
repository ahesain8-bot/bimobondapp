import 'dart:io';

import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-bleed story media preview (TikTok-style cover fit).
class StoryMediaPreview extends StatefulWidget {
  const StoryMediaPreview({required this.file, required this.type, super.key});

  final File file;
  final String type;

  @override
  State<StoryMediaPreview> createState() => _StoryMediaPreviewState();
}

class _StoryMediaPreviewState extends State<StoryMediaPreview> {
  VideoPlayerController? _videoController;

  bool get _isVideo => widget.type == 'VIDEO';

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          if (!mounted) return;
          _videoController!
            ..setLooping(true)
            ..play();
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) {
        return const ColoredBox(
          color: Colors.black,
          child: Center(child: CustomLoadingWidget(size: 48)),
        );
      }
      return SizedBox.expand(
        child: ColoredBox(
          color: Colors.black,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: ColoredBox(
        color: Colors.black,
        child: Image.file(
          widget.file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
