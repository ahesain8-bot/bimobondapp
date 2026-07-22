import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/ar_camera/ar_color_filter_matrix.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_ar_effects_layer.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/gallery_ar_effects_layer.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:bimobondapp/core/utils/video_trim_segment.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

class MediaStudioPreview extends StatefulWidget {
  const MediaStudioPreview({
    super.key,
    required this.file,
    required this.isVideo,
    this.filter,
    this.effect,
    this.arFilterId = 'none',
    this.arFilterIntensity = 1.0,
    this.applyArColorPreview = true,
    this.paused = false,
    this.muted = false,
    this.trimSegments = const [],
  });

  final File file;
  final bool isVideo;

  /// Pauses video playback (e.g. while a sub-editor like Trim/Text is open on
  /// top) so its audio doesn't play behind the other screen.
  final bool paused;

  /// Mutes video audio (e.g. a second preview instance behind the text editor).
  final bool muted;

  /// Kept ranges of the clip (from the Trim editor). When non-empty the preview
  /// plays only these ranges — trimmed-out parts are skipped — so what you see
  /// matches the exported result.
  final List<VideoTrimSegment> trimSegments;
  final AwesomeFilter? filter;
  final CameraEffectDefinition? effect;

  /// AR color grade id from [ArFilterCatalog] (`whitening`, `warm`, …).
  final String arFilterId;
  final double arFilterIntensity;

  /// False when pixels already include the baked AR grade.
  final bool applyArColorPreview;

  @override
  State<MediaStudioPreview> createState() => _MediaStudioPreviewState();
}

class _MediaStudioPreviewState extends State<MediaStudioPreview> {
  VideoPlayerController? _videoController;
  Size _mediaSize = Size.zero;
  bool _videoFailed = false;
  bool _isVideoLoading = false;
  File? _loopPoster;

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
      _loopPoster = null;
      _videoFailed = false;
      if (_treatAsVideo) {
        _initVideo();
      } else {
        _loadImageSize();
      }
    } else if (oldWidget.filter?.name != widget.filter?.name &&
        oldWidget.effect?.slug != widget.effect?.slug) {
      setState(() {});
    }

    if (oldWidget.paused != widget.paused ||
        oldWidget.muted != widget.muted) {
      final controller = _videoController;
      if (controller != null && controller.value.isInitialized) {
        if (oldWidget.muted != widget.muted) {
          unawaited(controller.setVolume(widget.muted ? 0.0 : 1.0));
        }
        if (oldWidget.paused != widget.paused) {
          if (widget.paused) {
            unawaited(controller.pause());
          } else {
            // Re-assert volume after resume — some platforms reset it on play.
            unawaited(() async {
              await controller.setVolume(widget.muted ? 0.0 : 1.0);
              await controller.play();
            }());
          }
        }
      }
    }

    if (!listEquals(oldWidget.trimSegments, widget.trimSegments)) {
      final controller = _videoController;
      if (controller != null &&
          controller.value.isInitialized &&
          widget.trimSegments.isNotEmpty) {
        controller.seekTo(widget.trimSegments.first.start);
      }
    }
  }

  /// Skips trimmed-out gaps during playback so the preview matches the export.
  void _enforceTrim() {
    final controller = _videoController;
    final ranges = widget.trimSegments;
    if (controller == null ||
        ranges.isEmpty ||
        !controller.value.isInitialized ||
        !controller.value.isPlaying) {
      return;
    }
    final pos = controller.value.position;
    final inRange = ranges.any((s) => pos >= s.start && pos < s.end);
    if (!inRange) {
      final next = ranges.firstWhere(
        (s) => s.start > pos,
        orElse: () => ranges.first,
      );
      controller.seekTo(next.start);
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

    // mixWithOthers so studio soundtrack (SoundAudioPreview) can play under
    // the looping video without ExoPlayer stealing focus / freezing frames.
    final controller = VideoPlayerController.file(
      widget.file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
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
    controller.addListener(_enforceTrim);

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      if (widget.trimSegments.isNotEmpty) {
        await controller.seekTo(widget.trimSegments.first.start);
      }
      await controller.play();
      if (widget.paused) await controller.pause();
      setState(() {
        _mediaSize = controller.value.size;
        _isVideoLoading = false;
      });
      // Poster sits behind the player so ExoPlayer's loop seek (or a 1-frame
      // black tail) doesn't flash the black ColoredBox behind the texture.
      unawaited(_loadLoopPoster());
    } catch (_) {
      if (mounted) {
        setState(() {
          _videoFailed = true;
          _isVideoLoading = false;
        });
      }
    }
  }

  Future<void> _loadLoopPoster() async {
    try {
      final thumb = await VideoThumbnailUtils.generateThumbnailFile(
        widget.file,
        maxHeight: 720,
      );
      if (!mounted || thumb == null) return;
      setState(() => _loopPoster = thumb);
    } catch (_) {}
  }

  Future<void> _loadImageSize() async {
    if (VideoThumbnailUtils.isVideoFile(widget.file)) {
      _initVideo();
      return;
    }
    // Do NOT decode the full photo here — that races Image.file and causes a
    // black flash. Effects use layout size; Image.file paints immediately.
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAwesomeFilter =
        widget.filter != null && widget.filter!.name != AwesomeFilter.None.name;
    final arColorId = ArFilterCatalog.isColorFilter(widget.arFilterId)
        ? widget.arFilterId
        : null;
    final arColorFilter = widget.applyArColorPreview
        ? ArColorFilterMatrix.preview(
            arColorId,
            intensity: widget.arFilterIntensity,
          )
        : null;
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
        final poster = _loopPoster;
        media = ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (poster != null)
                Image.file(
                  poster,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                ),
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      media = LayoutBuilder(
        builder: (context, constraints) {
          // Decode at display size only — no full-res decode, no black wait.
          final dpr = MediaQuery.of(context).devicePixelRatio;
          const maxDecodeEdge = 720;
          final targetW = (constraints.maxWidth * dpr).round().clamp(1, maxDecodeEdge);
          return Image.file(
            widget.file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            cacheWidth: targetW,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Colors.black,
              child: Center(
                child: Icon(LucideIcons.imageOff, color: Colors.white38),
              ),
            ),
          );
        },
      );
    }

    if (arColorFilter != null) {
      media = ColorFiltered(colorFilter: arColorFilter, child: media);
    } else if (hasAwesomeFilter) {
      media = ColorFiltered(colorFilter: widget.filter!.preview, child: media);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        SizedBox.expand(child: media),
        if (activeEffect != null && activeEffect.requiresFaceDetection)
          GalleryArEffectsLayer(
            file: widget.file,
            isVideo: _treatAsVideo,
            effect: activeEffect,
            mediaSize: _mediaSize == Size.zero
                ? MediaQuery.sizeOf(context)
                : _mediaSize,
            previewFit: BoxFit.cover,
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
