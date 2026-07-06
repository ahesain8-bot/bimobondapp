import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_ar_effects_layer.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/gallery_ar_effects_layer.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

class MediaStudioPreview extends StatefulWidget {
  const MediaStudioPreview({
    super.key,
    required this.file,
    required this.isVideo,
    required this.filter,
    this.effect,
  });

  final File file;
  final bool isVideo;
  final AwesomeFilter filter;
  final CameraEffectDefinition? effect;

  @override
  State<MediaStudioPreview> createState() => _MediaStudioPreviewState();
}

class _MediaStudioPreviewState extends State<MediaStudioPreview> {
  VideoPlayerController? _videoController;
  Size _mediaSize = Size.zero;
  bool _videoFailed = false;
  bool _isVideoLoading = false;

  bool get _treatAsVideo =>
      widget.isVideo || VideoThumbnailUtils.isVideoFile(widget.file);

  @override
  void initState() {
    super.initState();
    if (_treatAsVideo) {
      _initVideo();
    } else {
      _loadImageSize();
    }
  }

  @override
  void didUpdateWidget(MediaStudioPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _videoController?.dispose();
      _videoController = null;
      _videoFailed = false;
      if (_treatAsVideo) {
        _initVideo();
      } else {
        _loadImageSize();
      }
    } else if (oldWidget.filter.name != widget.filter.name ||
        oldWidget.effect?.id != widget.effect?.id) {
      setState(() {});
    }
  }

  Future<void> _initVideo() async {
    if (!await widget.file.exists()) {
      if (mounted) setState(() => _videoFailed = true);
      return;
    }

    setState(() {
      _isVideoLoading = true;
      _videoFailed = false;
    });

    final controller = VideoPlayerController.file(widget.file);
    _videoController = controller;

    void onUpdate() {
      if (!mounted) return;
      if (controller.value.hasError) {
        setState(() {
          _videoFailed = true;
          _isVideoLoading = false;
        });
      } else if (controller.value.isInitialized) {
        setState(() {
          _mediaSize = controller.value.size;
          _isVideoLoading = false;
        });
      }
    }

    controller.addListener(onUpdate);

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(1);
      await controller.play();
      setState(() {
        _mediaSize = controller.value.size;
        _isVideoLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _videoFailed = true;
          _isVideoLoading = false;
        });
      }
    }
  }

  Future<void> _loadImageSize() async {
    if (VideoThumbnailUtils.isVideoFile(widget.file)) {
      _initVideo();
      return;
    }

    try {
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _mediaSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });
      frame.image.dispose();
    } catch (_) {
      if (mounted) setState(() => _videoFailed = true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = widget.filter.name != AwesomeFilter.None.name;
    final activeEffect = widget.effect;

    Widget media;
    if (_treatAsVideo) {
      final controller = _videoController;
      if (_isVideoLoading) {
        media = const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        );
      } else if (_videoFailed ||
          controller == null ||
          !controller.value.isInitialized) {
        media = _VideoFallbackThumb(file: widget.file);
      } else {
        media = FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      }
    } else {
      media = Image.file(
        widget.file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Colors.black,
          child: Center(
            child: Icon(LucideIcons.imageOff, color: Colors.white38),
          ),
        ),
      );
    }

    if (hasFilter) {
      media = ColorFiltered(colorFilter: widget.filter.preview, child: media);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        SizedBox.expand(child: media),
        if (activeEffect != null &&
            activeEffect.requiresFaceDetection &&
            _mediaSize != Size.zero)
          GalleryArEffectsLayer(
            file: widget.file,
            isVideo: _treatAsVideo,
            effect: activeEffect,
            mediaSize: _mediaSize,
          ),
        if (activeEffect != null && activeEffect.isScreenEffect)
          CameraScreenEffectsLayer(effect: activeEffect),
      ],
    );
  }
}

class _VideoFallbackThumb extends StatefulWidget {
  const _VideoFallbackThumb({required this.file});

  final File file;

  @override
  State<_VideoFallbackThumb> createState() => _VideoFallbackThumbState();
}

class _VideoFallbackThumbState extends State<_VideoFallbackThumb> {
  File? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final thumb = await VideoThumbnailUtils.generateThumbnailFile(
      widget.file,
      maxHeight: 720,
    );
    if (mounted) setState(() => _thumb = thumb);
  }

  @override
  Widget build(BuildContext context) {
    if (_thumb != null) {
      return Image.file(_thumb!, fit: BoxFit.cover);
    }
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Icon(LucideIcons.film, color: Colors.white38, size: 40),
      ),
    );
  }
}
