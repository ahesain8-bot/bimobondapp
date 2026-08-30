import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/utils/app_media_cache_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/fake_livekit_service.dart'
    show LiveKitConnectionState, LiveKitService;
import '../../domain/entities/live_entity.dart';
import '../di/live_viewer_injector.dart' as di;
import 'fallback_media.dart';

class LiveVideoPlayer extends StatefulWidget {
  final LiveEntity live;
  final bool isActive;

  final BoxFit fit;
  final bool compact;
  final bool liveKitOnly;

  const LiveVideoPlayer({
    super.key,
    required this.live,
    this.isActive = true,
    this.fit = BoxFit.cover,
    this.compact = false,
    this.liveKitOnly = false,
  });

  @override
  State<LiveVideoPlayer> createState() => _LiveVideoPlayerState();
}

class _LiveVideoPlayerState extends State<LiveVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _buffering = false;
  bool _hasError = false;
  int _gen = 0;

  LiveKitService? _liveKit;
  StreamSubscription<LiveKitConnectionState>? _liveKitSub;
  Room? _room;
  RemoteVideoTrack? _track;

  @override
  void initState() {
    super.initState();
    final liveKit = di.sl<LiveKitService>();
    _liveKit = liveKit;
    _liveKitSub = liveKit.stateStream.listen(_onLiveKitState);
    final room = liveKit.room;
    if (room != null) _attachRoom(room);
    if (widget.isActive && !widget.liveKitOnly) _init();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final rb = context.findRenderObject() as RenderBox?;
        final size = rb?.hasSize == true ? rb!.size : Size.zero;
        final px = MediaQuery.of(context).devicePixelRatio;
        final track = _track;
        final pub = _findVideoPub();

        int? decW;
        int? decH;
        num? decFps;
        String? decMime;
        num? decKbps;
        String? statsErr;
        if (track != null) {
          try {
            final s = await track.getReceiverStats();
            if (s != null) {
              decW = s.frameWidth?.toInt();
              decH = s.frameHeight?.toInt();
              decFps = s.framesPerSecond;
              decMime = s.mimeType;
              decKbps = track.currentBitrate == null
                  ? null
                  : (track.currentBitrate! / 1000).round();
            }
          } catch (e) {
            statsErr = e.toString();
          }
        }
        debugPrint(
          '[DEBUG-QOS] VIEWER-RENDERER (before-floor):'
          '  liveId=${widget.live.id}'
          '  isActive=${widget.isActive}'
          '  logicalPx=${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}'
          '  pixelRatio=${px.toStringAsFixed(2)}'
          '  physicalPx=${(size.width * px).toStringAsFixed(0)}x${(size.height * px).toStringAsFixed(0)}'
          '  pubDims(WxH)=${pub?.dimensions?.width ?? "?"}x${pub?.dimensions?.height ?? "?"}'
          '  decoder(WxH)=${decW ?? "?"}x${decH ?? "?"}'
          '  decoderFps=${decFps ?? "?"}'
          '  decoderCodec=${decMime ?? "?"}'
          '  decoderBitrateKbps=${decKbps ?? "?"}'
          '  decoderErr=${statsErr ?? "none"}',
        );
      } catch (e) {
        debugPrint('[DEBUG-QOS] VIEWER-RENDERER (before-floor err): $e');
      } finally {
        unawaited(_applyQualityFloor(widget.isActive));
      }
    });
  }

  RemoteTrackPublication<RemoteVideoTrack>? _findVideoPub() {
    final roomObj = _room;
    if (roomObj == null) return null;
    for (final p in roomObj.remoteParticipants.values) {
      for (final vp in p.videoTrackPublications) {
        if (vp.subscribed) return vp;
      }
    }
    return null;
  }

  Future<void> _applyQualityFloor(bool isActive) async {
    final pub = _findVideoPub();
    if (pub == null) return;
    try {
      final hints = _liveKit?.mediaHints;
      final capWidth = hints?.subscribeWidth ?? 1280;
      final capHeight = hints?.subscribeHeight ?? 720;
      final dims = isActive
          ? widget.compact
                ? const VideoDimensions(640, 960)
                : VideoDimensions(capWidth, capHeight)
          : const VideoDimensions(854, 480);
      final quality = isActive
          ? widget.compact
                ? VideoQuality.MEDIUM
                : VideoQuality.HIGH
          : VideoQuality.LOW;
      debugPrint(
        '[VIDEO-FIX] VIEWER-FLOOR: liveId=${widget.live.id}'
        '  isActive=$isActive'
        '  → setVideoDimensions(${dims.width}x${dims.height})'
        ' + setVideoQuality(${quality.name.toUpperCase()})',
      );
      await pub.setVideoDimensions(dims);
      await pub.setVideoQuality(quality);

      await Future<void>.delayed(const Duration(milliseconds: 500));
      final track = _track;
      int? aftDecW;
      int? aftDecH;
      String? aftDecMime;
      num? aftDecKbps;
      if (track != null) {
        try {
          final s2 = await track.getReceiverStats();
          if (s2 != null) {
            aftDecW = s2.frameWidth?.toInt();
            aftDecH = s2.frameHeight?.toInt();
            aftDecMime = s2.mimeType;
            aftDecKbps = track.currentBitrate == null
                ? null
                : (track.currentBitrate! / 1000).round();
          }
        } catch (_) {}
      }
      final afterDims = pub.videoDimensions;
      debugPrint(
        '[DEBUG-QOS] VIEWER-RENDERER (after-floor):'
        '  liveId=${widget.live.id}'
        '  pub.videoDimensionsAfter=${afterDims == null ? "null" : "${afterDims.width}x${afterDims.height}"}'
        '  decoderFrameAfter(WxH)=${aftDecW ?? "?"}x${aftDecH ?? "?"}'
        '  decoderCodecAfter=$aftDecMime'
        '  decoderBitrateAfterKbps=$aftDecKbps'
        '  SUBSCRIBE_CAP_RESULT=${aftDecW == null || aftDecH == null ? "NOT_YET_DECODED" : "${aftDecW}x$aftDecH (cap ${dims.width}x${dims.height})"}',
      );
    } catch (e) {
      debugPrint('[VIDEO-FIX] VIEWER-FLOOR apply failed: $e');
    }
  }

  @override
  void dispose() {
    _liveKitSub?.cancel();
    _liveKitSub = null;
    _detachRoom();
    _disposeController();
    super.dispose();
  }

  void _onLiveKitState(LiveKitConnectionState state) {
    if (!mounted) return;
    final liveKit = _liveKit;
    if (liveKit == null) return;

    if (state == LiveKitConnectionState.connected) {
      final room = liveKit.room;
      if (room != null && room != _room) _attachRoom(room);
      if (!widget.liveKitOnly &&
          widget.isActive &&
          _controller == null &&
          !_initializing &&
          !_hasError) {
        _init();
      }
      unawaited(_applyQualityFloor(widget.isActive));
    } else if (state == LiveKitConnectionState.disconnected ||
        state == LiveKitConnectionState.failed) {
      _detachRoom();
      if (mounted && (_buffering || _initializing)) setState(() {});
    }
  }

  void _attachRoom(Room room) {
    if (_room == room) return;
    _detachRoom();
    _room = room;
    room.addListener(_onRoomChanged);
    _refreshTrack();
  }

  void _detachRoom() {
    final room = _room;
    _room = null;
    if (room != null) room.removeListener(_onRoomChanged);
    _track = null;
  }

  void _onRoomChanged() {
    _refreshTrack();
  }

  void _refreshTrack() {
    final room = _room;
    final next = room == null ? null : _firstSubscribedVideoTrack(room);
    if (identical(next, _track)) return;
    _track = next;
    if (mounted) setState(() {});
  }

  RemoteVideoTrack? _firstSubscribedVideoTrack(Room room) {
    for (final participant in room.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        if (pub.subscribed && pub.track is RemoteVideoTrack) {
          return pub.track as RemoteVideoTrack;
        }
      }
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant LiveVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live.id != widget.live.id) {
      _disposeController();
      if (widget.isActive && !widget.liveKitOnly) _init();
    } else if (oldWidget.isActive != widget.isActive ||
        oldWidget.compact != widget.compact) {
      unawaited(_applyQualityFloor(widget.isActive));
      if (widget.isActive && !widget.liveKitOnly) {
        if (_controller == null) {
          _init();
        } else {
          _controller?.play();
        }
      } else {
        _controller?.pause();
        _disposeController();
        if (mounted) {
          setState(() {
            _initializing = false;
            _buffering = false;
          });
        }
      }
    }
  }

  Future<void> _init() async {
    if (widget.liveKitOnly) return;
    final gen = ++_gen;
    if (!mounted) return;

    setState(() {
      _initializing = true;
      _hasError = false;
      _buffering = false;
    });

    final liveEntityUrl = widget.live.streamUrl;
    final liveKitServiceUrl = _liveKit?.streamUrl;
    final url = liveEntityUrl != null && liveEntityUrl.isNotEmpty
        ? liveEntityUrl
        : liveKitServiceUrl;
    final isHttp =
        url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));
    if (url == null || url.isEmpty || !isHttp) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _initializing = false;
        _buffering = false;
        _hasError = false;
      });
      return;
    }

    VideoPlayerController? controller;
    try {
      final cachedFile = await AppMediaCacheManager.getCachedVideoFile(url);
      controller = cachedFile != null
          ? VideoPlayerController.file(cachedFile)
          : VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted || gen != _gen || !widget.isActive) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(1);
      controller.addListener(_onVideoTick);
      _controller = controller;
      await controller.play();
      if (!mounted || gen != _gen) return;
      setState(() => _initializing = false);
    } catch (_) {
      await controller?.dispose();
      if (!mounted || gen != _gen) return;
      setState(() {
        _initializing = false;
        _hasError = true;
      });
    }
  }

  void _onVideoTick() {
    final c = _controller;
    if (c == null || !mounted) return;
    final buffering = c.value.isBuffering;
    if (buffering != _buffering) {
      setState(() => _buffering = buffering);
    }
  }

  void _disposeController() {
    _gen++;
    final c = _controller;
    _controller = null;
    c?.removeListener(_onVideoTick);
    c?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMedia(),
        if (widget.isActive && (_initializing || _buffering)) _buildBuffering(),
        if (_hasError && widget.isActive) _buildErrorBanner(),
      ],
    );
  }

  Widget _buildMedia() {
    final room = widget.isActive ? _room : null;
    final track = room == null ? null : _track;
    if (track != null) {
      return ColoredBox(
        color: Colors.black,
        child: VideoTrackRenderer(
          track,
          fit: widget.fit == BoxFit.cover
              ? VideoViewFit.cover
              : VideoViewFit.contain,
          placeholderBuilder: (_) => _buildPlaceholderMedia(),
        ),
      );
    }

    final controller = _controller;
    if (!_hasError && controller != null && controller.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }

    return _buildPlaceholderMedia();
  }

  Widget _buildPlaceholderMedia() {
    final thumbnailUrl = widget.live.thumbnailUrl;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return ColoredBox(
        color: Colors.black,
        child: CachedNetworkImage(
          imageUrl: thumbnailUrl,
          cacheManager: AppMediaCacheManager.instance,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          memCacheWidth: 720,
          placeholder: (_, _) => AnimatedVideoPlaceholder(
            seed: widget.live.id,
            category: widget.live.category,
            hostInitial: widget.live.hostName,
          ),
          errorWidget: (_, _, _) => AnimatedVideoPlaceholder(
            seed: widget.live.id,
            category: widget.live.category,
            hostInitial: widget.live.hostName,
          ),
        ),
      );
    }

    return AnimatedVideoPlaceholder(
      seed: widget.live.id,
      category: widget.live.category,
      hostInitial: widget.live.hostName,
    );
  }

  Widget _buildBuffering() {
    return const Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_tethering_error,
              color: AppColors.warning,
              size: 28,
            ),
            const SizedBox(height: 8),
            const Text(
              'Unable to load stream',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: _init,
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
