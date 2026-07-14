import 'dart:async';

import 'package:bimobondapp/app/gifts/presentation/utils/gift_lottie_cache.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';

/// TikTok-style gift overlay — prefers preloaded Lottie for instant playback.
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

  /// Inserts above the current route (after the gift sheet is closed).
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

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return Future.value();

    final completer = Completer<void>();
    late OverlayEntry entry;

    void remove() {
      if (entry.mounted) entry.remove();
      if (!completer.isCompleted) completer.complete();
    }

    entry = OverlayEntry(
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

    overlay.insert(entry);
    return completer.future;
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
  late final _GiftMediaKind _kind;

  @override
  void initState() {
    super.initState();
    _kind = _detectKind(widget.animationUrl);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();

    switch (_kind) {
      case _GiftMediaKind.lottie:
        unawaited(_playLottie());
        break;
      case _GiftMediaKind.video:
        unawaited(_initVideo());
        break;
      case _GiftMediaKind.image:
        Future<void>.delayed(const Duration(milliseconds: 1600), _finish);
        break;
    }
  }

  _GiftMediaKind _detectKind(String url) {
    if (GiftLottieCache.looksLikeVideoUrl(url)) return _GiftMediaKind.video;
    if (GiftLottieCache.looksLikeLottieUrl(url)) return _GiftMediaKind.lottie;
    final lower = url.toLowerCase().split('?').first;
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
    final composition =
        await GiftLottieCache.instance.load(widget.animationUrl);
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
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.animationUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoController = controller;
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(false);
      await controller.setVolume(1);
      setState(() {});
      await controller.play();

      void onTick() {
        final value = controller.value;
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
      Future<void>.delayed(timeout + const Duration(milliseconds: 400), _finish);
    } catch (_) {
      if (!mounted) return;
      setState(() {});
      Future<void>.delayed(const Duration(milliseconds: 1600), _finish);
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _lottieController?.dispose();
    _videoController?.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final mediaSize = size.shortestSide * 0.72;

    final labelParts = <String>[
      if (widget.senderName != null && widget.senderName!.trim().isNotEmpty)
        widget.senderName!.trim(),
      if (widget.giftName != null && widget.giftName!.trim().isNotEmpty)
        'sent ${widget.giftName!.trim()}',
    ];
    final label = labelParts.join(' ');

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Transparent hit target only — no dim/fill behind the gift.
          Positioned.fill(
            child: GestureDetector(
              onTap: _finish,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _entranceController,
                curve: Curves.easeOutBack,
              ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entranceController,
                  curve: Curves.easeOut,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: mediaSize,
                      height: mediaSize,
                      child: _buildMedia(),
                    ),
                    if (label.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    switch (_kind) {
      case _GiftMediaKind.lottie:
        final composition = _composition;
        final controller = _lottieController;
        if (composition != null && controller != null) {
          return _tikTokGiftBlend(
            Lottie(
              composition: composition,
              controller: controller,
              fit: BoxFit.contain,
              addRepaintBoundary: true,
            ),
          );
        }
        // Keep clear while Lottie loads so the thumbnail doesn't flash behind.
        if (_lottieFailed) return _tikTokGiftBlend(_fallbackVisual());
        return const SizedBox.shrink();
      case _GiftMediaKind.video:
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) {
          return const SizedBox.shrink();
        }
        return _tikTokGiftBlend(
          _knockOutBlackBackground(
            FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        );
      case _GiftMediaKind.image:
        return _tikTokGiftBlend(
          _knockOutBlackBackground(
            _fallbackVisual(url: widget.animationUrl),
          ),
        );
    }
  }

  /// Screen-blend so black pixels don't cover the live feed (TikTok gift look).
  Widget _tikTokGiftBlend(Widget child) {
    return _BlendMask(
      blendMode: BlendMode.screen,
      child: child,
    );
  }

  /// Extra keying for MP4/images that bake a solid black plate.
  Widget _knockOutBlackBackground(Widget child) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0.33, 0.33, 0.33, 0, -0.05,
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
        fit: BoxFit.contain,
      );
    }
    return const Icon(Icons.card_giftcard, size: 120, color: Colors.white);
  }
}

/// Paints [child] with [blendMode] so it composites over the live feed.
class _BlendMask extends SingleChildRenderObjectWidget {
  const _BlendMask({
    required this.blendMode,
    required Widget child,
  }) : super(child: child);

  final BlendMode blendMode;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderBlendMask(blendMode);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderBlendMask renderObject,
  ) {
    renderObject.blendMode = blendMode;
  }
}

class _RenderBlendMask extends RenderProxyBox {
  _RenderBlendMask(this._blendMode);

  BlendMode _blendMode;

  set blendMode(BlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = _blendMode,
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}
