import 'dart:async';

import 'package:bimobondapp/app/gifts/presentation/utils/gift_lottie_cache.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';

/// TikTok-style gift overlay — prefers preloaded Lottie for instant playback.
///
/// Important: never wrap [VideoPlayer] in `saveLayer` / [BlendMode.screen].
/// That combination hard-crashes many Android GPUs when a second texture
/// (live feed + gift MP4) is blended.
class GiftAnimationOverlay extends StatefulWidget {
  const GiftAnimationOverlay({
    required this.animationUrl,
    this.thumbnailUrl,
    this.senderName,
    this.giftName,
    this.onCompleted,
    super.key,
  });

  final String animationUrl;
  final String? thumbnailUrl;
  final String? senderName;
  final String? giftName;
  final VoidCallback? onCompleted;

  static OverlayEntry? _activeEntry;

  /// Inserts above every route layer (root overlay, after gift sheet closes).
  static Future<void> show(
    BuildContext context, {
    required String animationUrl,
    String? thumbnailUrl,
    String? senderName,
    String? giftName,
  }) {
    final resolved = MediaUtils.resolveAbsoluteUrl(animationUrl);
    if (resolved.trim().isEmpty) return Future.value();

    // Kick off / reuse cached Lottie load before the first frame paints.
    if (GiftLottieCache.looksLikeLottieUrl(resolved)) {
      unawaited(GiftLottieCache.instance.load(resolved));
    }

    // Prefer the root navigator overlay so gifts sit above sheets/dialogs.
    final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return Future.value();

    // Only one gift animation at a time — avoids dual VideoPlayers / crash.
    _dismissActive();

    final completer = Completer<void>();
    late OverlayEntry entry;

    void remove() {
      if (identical(_activeEntry, entry)) {
        _activeEntry = null;
      }
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (entry.mounted) {
          try {
            entry.remove();
          } catch (_) {}
        }
        if (!completer.isCompleted) completer.complete();
      });
    }

    entry = OverlayEntry(
      maintainState: false,
      opaque: false,
      builder: (context) => GiftAnimationOverlay(
        animationUrl: resolved,
        thumbnailUrl: thumbnailUrl == null || thumbnailUrl.trim().isEmpty
            ? null
            : MediaUtils.resolveAbsoluteUrl(thumbnailUrl),
        senderName: senderName,
        giftName: giftName,
        onCompleted: remove,
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
    return completer.future;
  }

  static void _dismissActive() {
    final active = _activeEntry;
    _activeEntry = null;
    if (active == null) return;
    if (active.mounted) {
      try {
        active.remove();
      } catch (_) {}
    }
  }

  @override
  State<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

enum _GiftMediaKind { lottie, video, image }

class _GiftAnimationOverlayState extends State<GiftAnimationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  AnimationController? _lottieController;
  VideoPlayerController? _videoController;
  LottieComposition? _composition;
  bool _finished = false;
  bool _lottieFailed = false;
  bool _videoFailed = false;
  late final _GiftMediaKind _kind;
  late final bool _isWebp;

  static bool _looksLikeWebp(String url) {
    final lower = url.toLowerCase().split('?').first.trim();
    return lower.endsWith('.webp');
  }

  @override
  void initState() {
    super.initState();
    _isWebp = _looksLikeWebp(widget.animationUrl);
    _kind = _detectKind(widget.animationUrl);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();

    switch (_kind) {
      case _GiftMediaKind.lottie:
        unawaited(_playLottie());
        break;
      case _GiftMediaKind.video:
        unawaited(_initVideo());
        break;
      case _GiftMediaKind.image:
        // Animated WebP often needs a bit longer on screen.
        final hold = _isWebp
            ? const Duration(milliseconds: 2800)
            : const Duration(milliseconds: 1600);
        Future<void>.delayed(hold, _finish);
        break;
    }
  }

  _GiftMediaKind _detectKind(String url) {
    final lower = url.toLowerCase().split('?').first.trim();
    // Explicit .lottie / .json before video heuristics.
    if (lower.endsWith('.lottie') || lower.endsWith('.json')) {
      return _GiftMediaKind.lottie;
    }
    if (GiftLottieCache.looksLikeVideoUrl(url)) return _GiftMediaKind.video;
    if (GiftLottieCache.looksLikeLottieUrl(url)) return _GiftMediaKind.lottie;
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return _GiftMediaKind.image;
    }
    // Prefer Lottie for gift animation paths — faster than video decode.
    return _GiftMediaKind.lottie;
  }

  Future<void> _playLottie() async {
    final composition = await GiftLottieCache.instance.load(
      widget.animationUrl,
    );
    if (!mounted) return;

    if (composition == null) {
      setState(() => _lottieFailed = true);
      Future<void>.delayed(const Duration(milliseconds: 1600), _finish);
      return;
    }

    final controller = AnimationController(
      vsync: this,
      duration: composition.duration,
    );
    _lottieController = controller;
    setState(() => _composition = composition);

    await controller.forward();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _finish();
  }

  Future<void> _initVideo() async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.animationUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoController = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        _videoController = null;
        return;
      }
      await controller.setLooping(false);
      await controller.setVolume(1);
      setState(() {});
      await controller.play();

      void onTick() {
        final value = controller!.value;
        if (!value.isInitialized || value.duration == Duration.zero) return;
        if (value.position >=
            value.duration - const Duration(milliseconds: 80)) {
          controller.removeListener(onTick);
          _finish();
        }
      }

      controller.addListener(onTick);
      final d = controller.value.duration;
      final timeout = d > Duration.zero ? d : const Duration(seconds: 3);
      Future<void>.delayed(
        timeout + const Duration(milliseconds: 400),
        _finish,
      );
    } catch (_) {
      try {
        await controller?.dispose();
      } catch (_) {}
      _videoController = null;
      if (!mounted) return;
      setState(() => _videoFailed = true);
      Future<void>.delayed(const Duration(milliseconds: 1600), _finish);
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;

    // Tear down video texture before removing the overlay entry.
    final video = _videoController;
    _videoController = null;
    if (video != null) {
      unawaited(() async {
        try {
          await video.pause();
        } catch (_) {}
        try {
          await video.dispose();
        } catch (_) {}
        widget.onCompleted?.call();
      }());
      return;
    }

    widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _lottieController?.dispose();
    final video = _videoController;
    _videoController = null;
    video?.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Gift assets are authored at 1080×1080 — keep a 1:1 stage, full width.
    final giftSize = size.width.clamp(0.0, size.height);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _finish,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          // Square gift stage anchored to the bottom; slides up on enter.
          Positioned(
            left: (size.width - giftSize) / 2,
            bottom: 0,
            width: giftSize,
            height: giftSize,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _entranceController,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entranceController,
                  curve: Curves.easeOut,
                ),
                child: Opacity(
                  opacity: 0.95,
                  child: _withEdgeFade(
                    SizedBox(
                      width: giftSize,
                      height: giftSize,
                      child: _buildMedia(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fades the top 20%; softens the bottom slightly while keeping it more opaque.
  Widget _withEdgeFade(Widget child) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00000000),
          Color(0xFF000000),
          Color(0xFF000000),
          // Bottom stays mostly visible (higher opacity than a full fade-out).
          Color(0xE6FFFFFF),
        ],
        stops: [0.0, 0.20, 0.90, 1.0],
      ).createShader(bounds),
      child: RepaintBoundary(child: child),
    );
  }

  Widget _buildMedia() {
    switch (_kind) {
      case _GiftMediaKind.lottie:
        final composition = _composition;
        final controller = _lottieController;
        if (composition != null && controller != null) {
          return _lottieScreenBlend(
            Lottie(
              composition: composition,
              controller: controller,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              addRepaintBoundary: true,
            ),
          );
        }
        if (_lottieFailed) return _fallbackVisual();
        return const SizedBox.shrink();
      case _GiftMediaKind.video:
        if (_videoFailed) return _fallbackVisual();
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) {
          return const SizedBox.shrink();
        }
        // Parent stage is 1:1 (1080×1080); cover the square.
        return _giftLightenFilter(
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        );
      case _GiftMediaKind.image:
        return _giftLightenFilter(_fallbackVisual(url: widget.animationUrl));
    }
  }

  /// Brightens gift media so it reads lighter over the feed.
  Widget _giftLightenFilter(Widget child) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        // Boost RGB + lift blacks slightly.
        1.22, 0, 0, 0, 18,
        0, 1.22, 0, 0, 18,
        0, 0, 1.22, 0, 18,
        0, 0, 0, 1, 0,
      ]),
      child: child,
    );
  }

  /// Soft screen-style look for Lottie only (no Texture / VideoPlayer).
  Widget _lottieScreenBlend(Widget child) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1.28,
        0,
        0,
        0,
        12,
        0,
        1.28,
        0,
        0,
        12,
        0,
        0,
        1.28,
        0,
        12,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: child,
    );
  }

  Widget _fallbackVisual({String? url}) {
    final thumb = (url ?? widget.thumbnailUrl)?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      return SafeNetworkImage(
        imageUrl: thumb,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }
    return const Center(
      child: Icon(Icons.card_giftcard, size: 120, color: Colors.white),
    );
  }
}
