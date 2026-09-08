import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/fake_livekit_service.dart'
    show LiveKitConnectionState, LiveKitService;
import '../../domain/entities/live_entity.dart';
import '../di/live_viewer_injector.dart' as di;
import 'fallback_media.dart';
import '../../../live/presentation/widgets/room/live_audio_room_stage.dart';

class LiveVideoPlayer extends StatefulWidget {
  final LiveEntity live;
  final bool isActive;
  final bool liveKitOnly;

  final BoxFit fit;

  /// AUDIO viewer canvas. Host/start-live stages omit this.
  final VoidCallback? onRaiseHand;

  const LiveVideoPlayer({
    super.key,
    required this.live,
    this.isActive = true,
    this.liveKitOnly = false,
    this.fit = BoxFit.cover,
    this.onRaiseHand,
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
  final GlobalKey _cameraRendererKey = GlobalKey();

  LiveKitService? _liveKit;
  StreamSubscription<LiveKitConnectionState>? _liveKitSub;
  Room? _room;
  RemoteVideoTrack? _track;
  String _pubFingerprint = '';

  @override
  void initState() {
    super.initState();
    final liveKit = di.sl<LiveKitService>();
    _liveKit = liveKit;
    _liveKitSub = liveKit.stateStream.listen(_onLiveKitState);
    final room = liveKit.room;
    if (room != null) _attachRoom(room);
    if (widget.isActive) _init();

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
    RemoteTrackPublication<RemoteVideoTrack>? camera;
    RemoteTrackPublication<RemoteVideoTrack>? screen;
    for (final p in roomObj.remoteParticipants.values) {
      for (final vp in p.videoTrackPublications) {
        if (!vp.subscribed) continue;
        if (vp.source == TrackSource.screenShareVideo) {
          screen ??= vp;
        } else if (camera == null || (camera.muted && !vp.muted)) {
          camera = vp;
        }
      }
    }
    final screenLive = screen != null && !screen.muted;
    // DUAL main tile is the camera. A muted camera with a live screen share
    // is a stale SCREEN (socket still DUAL) — never keep the black camera.
    if (widget.live.scene == 'DUAL') {
      if (camera != null && !camera.muted) return camera;
      if (screenLive) return screen;
      return camera ?? screen;
    }
    // Bind screenShareVideo by TrackSource whenever that publication is live,
    // even if liveScene is still CAMERA. A muted camera must never win.
    if (screenLive &&
        (widget.live.scene == 'SCREEN' || camera == null || camera.muted)) {
      return screen;
    }
    if (widget.live.scene == 'SCREEN') return screen;
    return camera ?? screen;
  }

  RemoteVideoTrack? _screenShareTrack() {
    final roomObj = _room;
    if (roomObj == null) return null;
    for (final p in roomObj.remoteParticipants.values) {
      for (final vp in p.videoTrackPublications) {
        if (vp.subscribed &&
            vp.source == TrackSource.screenShareVideo &&
            vp.track != null) {
          return vp.track;
        }
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
          ? VideoDimensions(capWidth, capHeight)
          : const VideoDimensions(854, 480);
      final quality = isActive ? VideoQuality.HIGH : VideoQuality.LOW;
      // Skip no-op renegotiation — re-applying the same floor mid-PK stalls
      // decode and looks like a freeze/reload.
      final currentDims = pub.dimensions;
      final alreadyAtFloor =
          pub.videoQuality == quality &&
          currentDims != null &&
          currentDims.width >= dims.width &&
          currentDims.height >= dims.height;
      if (alreadyAtFloor) {
        debugPrint(
          '[VIDEO-FIX] VIEWER-FLOOR: skip (already ${dims.width}x${dims.height} ${quality.name})',
        );
        return;
      }
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
      if (widget.isActive &&
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
    _pubFingerprint = '';
  }

  void _onRoomChanged() {
    _refreshTrack();
  }

  String _videoPublicationFingerprint() {
    final room = _room;
    if (room == null) return '';
    final parts = <String>[];
    for (final participant in room.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        parts.add(
          '${pub.sid}:${pub.source.name}:${pub.subscribed}:${pub.muted}',
        );
      }
    }
    parts.sort();
    return parts.join('|');
  }

  void _refreshTrack() {
    final pub = _findVideoPub();
    final next = pub?.track;
    final fingerprint = _videoPublicationFingerprint();
    final trackChanged = !identical(next, _track);
    final pubsChanged = fingerprint != _pubFingerprint;
    if (!trackChanged && !pubsChanged) return;
    _track = next;
    _pubFingerprint = fingerprint;
    debugPrint(
      '[LiveVideoPlayer] scene=${widget.live.scene}'
      ' mainSource=${pub?.source.name}'
      ' mainSid=${pub?.sid}'
      ' muted=${pub?.muted}'
      ' pubs=$fingerprint',
    );
    final attachedPub = pub;
    if (attachedPub != null &&
        (attachedPub.source == TrackSource.screenShareVideo ||
            widget.live.scene == 'DUAL')) {
      debugPrint(
        'LIVE_SCREEN_DIAG viewer rendererAttach'
        ' scene=${widget.live.scene}'
        ' sid=${attachedPub.sid}'
        ' source=${attachedPub.source.name}'
        ' subscribed=${attachedPub.subscribed}'
        ' muted=${attachedPub.muted}',
      );
    }
    RemoteTrackPublication<RemoteVideoTrack>? cameraPub;
    RemoteTrackPublication<RemoteVideoTrack>? screenPub;
    final roomObj = _room;
    if (roomObj != null) {
      for (final participant in roomObj.remoteParticipants.values) {
        for (final candidate in participant.videoTrackPublications) {
          if (candidate.source == TrackSource.screenShareVideo) {
            screenPub ??= candidate;
          } else if (cameraPub == null ||
              (cameraPub.muted && !candidate.muted)) {
            cameraPub = candidate;
          }
        }
      }
    }
    if (cameraPub != null && screenPub != null) {
      debugPrint(
        'LIVE_SCREEN_DIAG viewer dualPubs'
        ' scene=${widget.live.scene}'
        ' cameraSid=${cameraPub.sid}'
        ' screenSid=${screenPub.sid}'
        ' cameraSubscribed=${cameraPub.subscribed}'
        ' screenSubscribed=${screenPub.subscribed}'
        ' cameraMuted=${cameraPub.muted}'
        ' screenMuted=${screenPub.muted}'
        ' mainSid=${attachedPub?.sid ?? "-"}'
        ' pipSid=${_screenShareTrack()?.sid ?? screenPub.sid}',
      );
    }
    if (mounted) setState(() {});
    if (trackChanged && widget.isActive) {
      unawaited(_applyQualityFloor(widget.isActive));
    }
  }

  @override
  void didUpdateWidget(covariant LiveVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live.id != widget.live.id) {
      _disposeController();
      if (widget.isActive) _init();
      _refreshTrack();
      unawaited(_applyQualityFloor(widget.isActive));
      return;
    }
    if (oldWidget.live.scene != widget.live.scene) {
      _refreshTrack();
      // CAMERA↔DUAL keeps the same camera publication. Re-applying the
      // subscribe floor here tore down both renderers (unsubscribed camera
      // and screen) and dropped decode to 360p in the DUAL logs.
      final mainIsCamera =
          _track != null && _track!.source != TrackSource.screenShareVideo;
      if (!mainIsCamera) {
        unawaited(_applyQualityFloor(widget.isActive));
      }
    }
    if (oldWidget.isActive != widget.isActive) {
      unawaited(_applyQualityFloor(widget.isActive));
      if (widget.isActive) {
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
    if (widget.live.isAudioOnly) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _buffering = false;
          _hasError = false;
        });
      }
      return;
    }
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
    if (widget.liveKitOnly || url == null || url.isEmpty || !isHttp) {
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
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
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
    if (widget.live.isAudioOnly) {
      return LiveAudioRoomStage(
        hostName: widget.live.hostName,
        hostAvatarUrl: widget.live.hostAvatar,
        coverUrl: widget.live.thumbnailUrl,
        paused: widget.live.paused,
        onRaiseHand: widget.onRaiseHand,
      );
    }
    final room = widget.isActive ? _room : null;
    final scene = widget.live.scene;
    final screen = _screenShareTrack();
    // Main tile follows _findVideoPub() so a live screenShareVideo wins even
    // when the scene socket is still CAMERA and the camera pub is muted.
    final track = room == null ? null : _track;
    if (track != null) {
      final isScreenShare = track.source == TrackSource.screenShareVideo;
      Widget renderer = VideoTrackRenderer(
        track,
        key: isScreenShare ? ValueKey('screen-${track.sid}') : _cameraRendererKey,
        fit: widget.fit == BoxFit.cover
            ? VideoViewFit.cover
            : VideoViewFit.contain,
        placeholderBuilder: (_) => AnimatedVideoPlaceholder(
          seed: widget.live.id,
          category: widget.live.category,
          hostInitial: widget.live.hostName,
        ),
      );
      if (widget.live.isFrontCamera && !isScreenShare) {
        renderer = Transform.flip(flipX: true, child: renderer);
      }
      final showDualPip =
          screen != null &&
          screen != track &&
          !isScreenShare &&
          scene != 'SCREEN';
      if (showDualPip) {
        renderer = Stack(
          fit: StackFit.expand,
          children: [
            renderer,
            Positioned(
              right: 12,
              bottom: 140,
              width: 120,
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: VideoTrackRenderer(screen, fit: VideoViewFit.cover),
              ),
            ),
          ],
        );
      }
      return ColoredBox(color: Colors.black, child: renderer);
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

    final thumbnailUrl = widget.live.thumbnailUrl;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return ColoredBox(
        color: Colors.black,
        child: CachedNetworkImage(
          imageUrl: thumbnailUrl,
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
