import 'dart:async';

import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
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
    this.size,
    this.onCompleted,
    super.key,
  });

  final String animationUrl;
  final String? thumbnailUrl;
  final String? senderName;
  final String? giftName;
  final dynamic size;
  final VoidCallback? onCompleted;

  static OverlayEntry? _activeEntry;
  static Object? _activeOwner;
  static VoidCallback? _activeDismiss;
  static String? _activeKey;

  /// Inserts above every route layer (root overlay, after gift sheet closes).
  ///
  /// [owner] is mandatory: the entry lives in the *root* overlay, so without a
  /// known owner nothing can take it back down and the animation outlives the
  /// screen that asked for it.
  static Future<void> show(
    BuildContext context, {
    required String animationUrl,
    required Object owner,
    String? dedupeKey,
    String? thumbnailUrl,
    String? senderName,
    String? giftName,
    dynamic size,
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

    // The entry lives in the root overlay, so it outlives its route unless the
    // route is still there to take it down. A gift landing while the room is
    // being popped would otherwise play on the screen the pop reveals.
    final route = ModalRoute.of(context);
    if (route != null && !route.isActive) return Future.value();

    // One physical send reaches the room as up to three socket events (the
    // gift comment, `auctionGiftCombo`, and `auctionUpdated.lastGift`). They
    // arrive seconds apart, so a duplicate used to dismiss the animation that
    // was still playing and start it over — the occasion gifts are 15s MP4s,
    // and that is what cut them off after about a second and churned an
    // ExoPlayer texture over the live feed. A duplicate is now a no-op.
    if (dedupeKey != null &&
        dedupeKey.isNotEmpty &&
        dedupeKey == _activeKey &&
        _activeEntry != null) {
      return Future.value();
    }

    // Only one gift animation at a time — avoids dual VideoPlayers / crash.
    _dismissActive();

    final completer = Completer<void>();
    late OverlayEntry entry;
    var removed = false;

    void remove() {
      if (identical(_activeEntry, entry)) {
        _activeEntry = null;
        _activeOwner = null;
        _activeDismiss = null;
        _activeKey = null;
      }
      if (removed) return;
      removed = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // Deliberately not gated on `entry.mounted`: an entry inserted while
        // the overlay could not rebuild itself is never mounted, and skipping
        // it here left it in the overlay to play on the next route.
        try {
          entry.remove();
        } catch (_) {}
        if (!completer.isCompleted) completer.complete();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
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
        size: size,
        onCompleted: remove,
      ),
    );

    _activeEntry = entry;
    _activeOwner = owner;
    _activeDismiss = remove;
    _activeKey = dedupeKey;
    overlay.insert(entry);

    // Second safety net behind the owner's own dismiss: tie the entry to the
    // route that requested it. A gift that arrives while the host is leaving
    // must not survive the pop and play on the screen underneath.
    if (route != null) {
      unawaited(route.popped.then((_) => dismiss(owner: owner)));
    }

    return completer.future;
  }

  /// Removes the active animation owned by [owner], so one live room cannot
  /// tear down another room's animation during navigation.
  static void dismiss({required Object owner}) {
    if (!identical(_activeOwner, owner)) return;
    _dismissActive();
  }

  static void _dismissActive() {
    final dismiss = _activeDismiss;
    if (dismiss != null) {
      dismiss();
      return;
    }

    final active = _activeEntry;
    _activeEntry = null;
    _activeOwner = null;
    _activeKey = null;
    if (active == null) return;
    // Unmounted entries are removed too — see `remove()` above.
    try {
      active.remove();
    } catch (_) {}
  }

  @override
  State<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

enum _GiftMediaKind { lottie, video, image }

/// How often the video watchdog samples the playback position.
const Duration _kVideoWatchdogTick = Duration(milliseconds: 500);

/// How long the position may stand still before the gift is treated as over.
/// Occasion gifts stream from the same host as the live feed, so a second or
/// two of rebuffering mid-animation is normal and must not end the overlay.
const Duration _kVideoMaxStall = Duration(seconds: 6);

class _GiftAnimationOverlayState extends State<GiftAnimationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  AnimationController? _lottieController;
  VideoPlayerController? _videoController;
  LottieComposition? _composition;
  bool _finished = false;
  bool _lottieFailed = false;
  bool _videoFailed = false;
  Timer? _finishTimer;
  Timer? _stallTimer;
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
        _scheduleFinish(hold);
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
    final composition = await GiftLottieCache.instance
        .load(widget.animationUrl)
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (!mounted) return;

    if (composition == null) {
      setState(() => _lottieFailed = true);
      _scheduleFinish(const Duration(milliseconds: 1600));
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
      await controller.initialize().timeout(const Duration(seconds: 8));
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
      _armStallWatchdog(controller);
    } catch (_) {
      try {
        await controller?.dispose();
      } catch (_) {}
      _videoController = null;
      if (!mounted) return;
      setState(() => _videoFailed = true);
      _scheduleFinish(const Duration(milliseconds: 1600));
    }
  }

  /// Ends the overlay when playback stops making progress — not on a clock.
  ///
  /// This used to be a single timer armed at `play()` for `duration + 400ms`.
  /// A 15s occasion MP4 that spends three seconds buffering therefore lost
  /// three seconds off its own animation, and a slow start cut it off outright.
  /// Sampling the position instead means a stream that is still advancing is
  /// still playing, however long the network takes to feed it.
  void _armStallWatchdog(VideoPlayerController controller) {
    _stallTimer?.cancel();
    var lastPosition = controller.value.position;
    var stalledFor = Duration.zero;
    _stallTimer = Timer.periodic(_kVideoWatchdogTick, (timer) {
      if (!mounted || _finished) {
        timer.cancel();
        return;
      }
      final value = controller.value;
      if (!value.isInitialized) {
        timer.cancel();
        _finish();
        return;
      }
      if (value.position > lastPosition) {
        lastPosition = value.position;
        stalledFor = Duration.zero;
        return;
      }
      stalledFor += _kVideoWatchdogTick;
      if (stalledFor >= _kVideoMaxStall) {
        timer.cancel();
        _finish();
      }
    });
  }

  void _scheduleFinish(Duration delay) {
    _finishTimer?.cancel();
    _finishTimer = Timer(delay, _finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _finishTimer?.cancel();
    _finishTimer = null;
    _stallTimer?.cancel();
    _stallTimer = null;

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
    _finishTimer?.cancel();
    _finishTimer = null;
    _stallTimer?.cancel();
    _stallTimer = null;
    _lottieController?.dispose();
    final video = _videoController;
    _videoController = null;
    video?.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  bool get _isSmall {
    final s = widget.size;
    if (s == GiftCatalogSize.small) return true;
    if (s is String && s.trim().toUpperCase() == 'SMALL') return true;
    return false;
  }

  bool get _isMedium {
    final s = widget.size;
    if (s == GiftCatalogSize.medium) return true;
    if (s is String && s.trim().toUpperCase() == 'MEDIUM') return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isSmall = _isSmall;
    final isMedium = _isMedium;
    final isLarge = !isSmall && !isMedium;

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final double stageSize;
    if (isSmall) {
      stageSize = (screenSize.width * 0.28).clamp(80.0, 120.0);
    } else if (isMedium) {
      stageSize = (screenSize.width * 0.72).clamp(240.0, 340.0);
    } else {
      stageSize = screenSize.width.clamp(0.0, screenSize.height);
    }

    final media = SizedBox(
      width: stageSize,
      height: stageSize,
      child: _buildMedia(),
    );
    final stage = _kind == _GiftMediaKind.video
        ? RepaintBoundary(child: media)
        : _withEdgeFade(media);

    Widget animatedStage;
    if (isLarge) {
      animatedStage = SlideTransition(
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
          child: stage,
        ),
      );
    } else {
      animatedStage = ScaleTransition(
        scale: Tween<double>(begin: 0.75, end: 1.0).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutBack,
          ),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOut,
          ),
          child: stage,
        ),
      );
    }

    // Position calculation:
    // - SMALL: very small, left-aligned above comments and highest price card (bottom: 230px, left/right: 16px)
    // - MEDIUM: center of screen
    // - LARGE: bottom of screen
    final double? topPosition;
    final double? bottomPosition;
    final double? leftPosition;
    final double? rightPosition;

    if (isSmall) {
      topPosition = null;
      bottomPosition = 350.0; // Positioned on top of comments area and on top of highest price card
      leftPosition = isRtl ? null : 16.0;
      rightPosition = isRtl ? 16.0 : null;
    } else if (isMedium) {
      topPosition = (screenSize.height - stageSize) / 2;
      bottomPosition = null;
      leftPosition = (screenSize.width - stageSize) / 2;
      rightPosition = null;
    } else {
      topPosition = null;
      bottomPosition = 0;
      leftPosition = (screenSize.width - stageSize) / 2;
      rightPosition = null;
    }

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
          Positioned(
            left: leftPosition,
            right: rightPosition,
            top: topPosition,
            bottom: bottomPosition,
            width: stageSize,
            height: stageSize,
            child: animatedStage,
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
          return Lottie(
            composition: composition,
            controller: controller,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            addRepaintBoundary: true,
          );
        }
        if (_lottieFailed) return _fallbackVisual();
        // Thumbnail is a failure fallback only — drawing it while the
        // composition loads reads as a static gift, then a late animation.
        return const SizedBox.expand();
      case _GiftMediaKind.video:
        if (_videoFailed) return _fallbackVisual();
        final controller = _videoController;
        if (controller == null || !controller.value.isInitialized) {
          // Same rule as the Lottie branch: nothing stands in while
          // `initialize()` opens the stream and decodes the first frame.
          return const SizedBox.expand();
        }
        // Parent stage is 1:1 (1080×1080); cover the square.
        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      case _GiftMediaKind.image:
        return _fallbackVisual(url: widget.animationUrl);
    }
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
