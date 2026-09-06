import 'dart:async';

import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/presentation/utils/gift_lottie_cache.dart';
import 'package:bimobondapp/app/gifts/presentation/utils/gift_media_cache.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';

/// TikTok-style gift overlay — prefers preloaded Lottie for instant playback.
///
/// Never wrap [VideoPlayer] in [BlendMode.screen] / unrestricted `saveLayer`
/// blends — that hard-crashes many Android GPUs over a live feed. LARGE gifts
/// may use [BlendMode.dstIn] only for a top alpha dissolve into the room.
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
  static String? _activeUrl;
  static bool _activeIsLarge = false;

  /// Recently finished media URLs — blocks late socket duplicates from replaying.
  static final Map<String, DateTime> _recentlyPlayedUrls = {};
  static const Duration _recentDedupeWindow = Duration(seconds: 12);

  /// LARGE is the default size: only an explicit SMALL/MEDIUM opts out.
  ///
  /// Needed before a [State] exists, because a LARGE gift stays on screen
  /// until it is tapped and therefore has to survive the events that follow.
  static bool _isLargeSize(dynamic size) {
    final raw = size is String ? size.trim().toUpperCase() : size;
    if (raw == GiftCatalogSize.small || raw == 'SMALL') return false;
    if (raw == GiftCatalogSize.medium || raw == 'MEDIUM') return false;
    return true;
  }

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

    // Warm disk + memory before the first frame paints.
    GiftMediaCache.instance.prefetchGiftUrls(
      animationUrl: resolved,
      thumbnailUrl: thumbnailUrl,
    );

    // Prefer the root navigator overlay so gifts sit above sheets/dialogs.
    final overlay =
        Navigator.maybeOf(context, rootNavigator: true)?.overlay ??
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
    final duplicateKey =
        dedupeKey != null && dedupeKey.isNotEmpty && dedupeKey == _activeKey;
    // A LARGE gift can stay on screen longer than follow-up socket events;
    // keys may disagree (profile name vs 'User') while the media URL matches.
    final duplicateLargeMedia = _activeIsLarge && resolved == _activeUrl;
    if (_activeEntry != null && (duplicateKey || duplicateLargeMedia)) {
      return Future.value();
    }

    // Drop late duplicates of a gift that just finished (lives + auction).
    _pruneRecentlyPlayed();
    final lastPlayed = _recentlyPlayedUrls[resolved];
    if (lastPlayed != null &&
        DateTime.now().difference(lastPlayed) < _recentDedupeWindow) {
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
        _activeUrl = null;
        _activeIsLarge = false;
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
    _activeUrl = resolved;
    _activeIsLarge = _isLargeSize(size);
    _recentlyPlayedUrls[resolved] = DateTime.now();
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
    _activeUrl = null;
    _activeIsLarge = false;
    if (active == null) return;
    // Unmounted entries are removed too — see `remove()` above.
    try {
      active.remove();
    } catch (_) {}
  }

  static void _pruneRecentlyPlayed() {
    final cutoff = DateTime.now().subtract(_recentDedupeWindow);
    _recentlyPlayedUrls.removeWhere((_, at) => at.isBefore(cutoff));
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
  bool _videoDisposeInFlight = false;
  int _videoGeneration = 0;
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
        // Still / animated image: short hold, then dismiss (no loop).
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

    // Play once — do not loop (lives + auction).
    await controller.forward();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _finish();
  }

  Future<void> _initVideo() async {
    final generation = ++_videoGeneration;
    VideoPlayerController? controller;
    try {
      // Prefer a local file — streaming MP4 beside LiveKit/AR textures is a
      // common Android OOM kill. Cache on first receive, play from disk after.
      final local = await GiftMediaCache.instance.resolveVideoFile(
        widget.animationUrl,
      );
      if (!mounted || generation != _videoGeneration || _finished) {
        return;
      }
      final options = VideoPlayerOptions(mixWithOthers: true);
      controller = local != null
          ? VideoPlayerController.file(local, videoPlayerOptions: options)
          : VideoPlayerController.networkUrl(
              Uri.parse(widget.animationUrl),
              videoPlayerOptions: options,
            );
      _videoController = controller;
      await controller.initialize().timeout(const Duration(seconds: 8));
      if (!mounted || generation != _videoGeneration || _finished) {
        await controller.dispose();
        if (identical(_videoController, controller)) {
          _videoController = null;
        }
        return;
      }
      // Play once — no looping for LARGE/MEDIUM (lives + auction).
      await controller.setLooping(false);
      await controller.setVolume(1);
      setState(() {});
      await controller.play();

      void onTick() {
        final value = controller!.value;
        if (!value.isInitialized || value.duration == Duration.zero) return;
        if (value.isCompleted || value.position >= value.duration) {
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
        return;
      }
      if (value.hasError) {
        timer.cancel();
        _finish();
        return;
      }
      if (value.isCompleted ||
          (value.duration > Duration.zero &&
              value.position >= value.duration)) {
        timer.cancel();
        return;
      }
      // A player can report a stable position while it is opening the stream,
      // waiting for buffered data, or briefly transitioning its play state.
      // None of those states means the animation has ended.
      if (value.isBuffering || !value.isPlaying) {
        lastPosition = value.position;
        stalledFor = Duration.zero;
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
    _videoGeneration++;

    // Tear down video texture before removing the overlay entry.
    final video = _videoController;
    _videoController = null;
    if (video != null) {
      _videoDisposeInFlight = true;
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
    _videoGeneration++;
    final video = _videoController;
    _videoController = null;
    // Avoid double-dispose if [_finish] is already tearing the player down.
    if (video != null && !_videoDisposeInFlight) {
      try {
        video.dispose();
      } catch (_) {}
    }
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

    final double stageWidth;
    final double stageHeight;
    if (isSmall) {
      stageWidth = stageHeight = (screenSize.width * 0.28).clamp(80.0, 120.0);
    } else if (isMedium) {
      stageWidth = stageHeight = (screenSize.width * 0.72).clamp(240.0, 340.0);
    } else {
      // LARGE gifts keep the existing bounded square stage. The media widget
      // fits its source into this stage without changing the source itself.
      stageWidth = stageHeight = screenSize.width.clamp(0.0, screenSize.height);
    }

    final media = SizedBox(
      key: const ValueKey('gift-animation-stage'),
      width: stageWidth,
      height: stageHeight,
      child: _buildMedia(),
    );
    // Only LARGE gets a top transparency fade into the live/auction feed.
    // SMALL/MEDIUM stay fully opaque.
    final stage = isLarge ? _withLargeTopFade(media) : media;

    Widget animatedStage;
    if (isLarge) {
      animatedStage = SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
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

    // LARGE: flush to bottom of the screen (bottom: 0).
    final double? topPosition;
    final double? bottomPosition;
    final double? leftPosition;
    final double? rightPosition;

    if (isSmall) {
      topPosition = null;
      // Sits above the comment feed and the highest-price card. A flat 350
      // pushed the badge past the middle of a short screen, so it scales and
      // is then clamped to the range that keeps it clear of both on a phone.
      bottomPosition = (screenSize.height * 0.41).clamp(200.0, 380.0);
      leftPosition = isRtl ? null : 16.0;
      rightPosition = isRtl ? 16.0 : null;
    } else if (isMedium) {
      topPosition = (screenSize.height - stageHeight) / 2;
      bottomPosition = null;
      leftPosition = (screenSize.width - stageWidth) / 2;
      rightPosition = null;
    } else {
      // Flush to the bottom edge (lives + auction share this overlay).
      topPosition = null;
      bottomPosition = 0;
      leftPosition = (screenSize.width - stageWidth) / 2;
      rightPosition = null;
    }

    // The root overlay must also preserve the established tap-to-dismiss
    // behavior. Translucent hit testing lets the route controls underneath
    // continue to receive their normal interactions while this entry calls
    // `_finish` for the existing gift-dismiss gesture.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _finish,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: leftPosition,
            right: rightPosition,
            top: topPosition,
            bottom: bottomPosition,
            width: stageWidth,
            height: stageHeight,
            child: animatedStage,
          ),
        ],
      ),
    );
  }

  /// Dissolves the upper ~10% of a LARGE gift into the live/auction video.
  ///
  /// [BlendMode.dstIn] multiplies the gift's own alpha by the gradient's, so the
  /// top edge is truly transparent over the room and the body stays opaque.
  /// Applies to Lottie, image, **and** MP4 (occasion gifts like lions) — a dark
  /// scrim overlay was used before and never looked like transparency.
  Widget _withLargeTopFade(Widget child) => _withTopBlend(child);

  /// Dissolves the upper ~10% of a LARGE gift into the feed behind it.
  Widget _withTopBlend(Widget child) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        // Clear ramp across the top 10% of stage height.
        colors: [
          Color(0x00000000),
          Color(0x33000000),
          Color(0x99000000),
          Color(0xFF000000),
          Color(0xFF000000),
        ],
        stops: [0.0, 0.03, 0.07, 0.10, 1.0],
      ).createShader(bounds),
      // Isolate the media layer so dstIn masks a Flutter layer, not a raw
      // platform texture blend (safer than BlendMode.screen over live).
      child: RepaintBoundary(child: child),
    );
  }

  BoxFit get _mediaFit => BoxFit.cover;

  Widget _buildMedia() {
    switch (_kind) {
      case _GiftMediaKind.lottie:
        final composition = _composition;
        final controller = _lottieController;
        if (composition != null && controller != null) {
          return Lottie(
            composition: composition,
            controller: controller,
            fit: _mediaFit,
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
        // Fit the media into the bounded stage while preserving its full
        // authored aspect ratio.
        return FittedBox(
          fit: _mediaFit,
          alignment: Alignment.center,
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
        fit: _mediaFit,
        alignment: Alignment.center,
        transparentPlaceholder: _isLarge,
      );
    }
    return const Center(
      child: Icon(Icons.card_giftcard, size: 120, color: Colors.white),
    );
  }

  bool get _isLarge => !_isSmall && !_isMedium;
}
