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

class LiveVideoPlayer extends StatefulWidget {
  final LiveEntity live;
  final bool isActive;

  final BoxFit fit;

  const LiveVideoPlayer({
    super.key,
    required this.live,
    this.isActive = true,
    this.fit = BoxFit.cover,
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
  EventsListener<RoomEvent>? _roomEvents;
  RemoteVideoTrack? _track;
  String? _subscribedSid;
  String? _activeTrackSid;
  String? _rendererBindSid;

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
    final boundSid = _activeTrackSid ?? _track?.sid;
    RemoteTrackPublication<RemoteVideoTrack>? latest;
    for (final p in roomObj.remoteParticipants.values) {
      for (final vp in p.videoTrackPublications) {
        if (!vp.subscribed) continue;
        latest = vp;
        if (boundSid != null &&
            (vp.sid == boundSid || vp.track?.sid == boundSid)) {
          return vp;
        }
      }
    }
    return latest;
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
      if (mounted) setState(() {});
    }
  }

  void _attachRoom(Room room) {
    if (_room == room) return;
    _detachRoom();
    _room = room;
    room.addListener(_onRoomChanged);
    final listener = room.createListener();
    _roomEvents = listener;
    listener
      ..on<TrackSubscribedEvent>(_onTrackSubscribed)
      ..on<TrackUnsubscribedEvent>(_onTrackUnsubscribed)
      ..on<TrackUnpublishedEvent>(_onTrackUnpublished);
    _syncTrackFromRoom();
  }

  void _detachRoom() {
    final listener = _roomEvents;
    _roomEvents = null;
    if (listener != null) unawaited(listener.dispose());
    final room = _room;
    _room = null;
    if (room != null) room.removeListener(_onRoomChanged);
    _track = null;
    _subscribedSid = null;
    _activeTrackSid = null;
    _rendererBindSid = null;
  }

  void _onRoomChanged() {
    _syncTrackFromRoom();
  }

  void _onTrackSubscribed(TrackSubscribedEvent event) {
    if (event.track is! RemoteVideoTrack) return;
    final track = event.track as RemoteVideoTrack;
    _adoptTrack(
      track,
      subscribedSid: event.publication.sid,
      source: 'TrackSubscribedEvent',
    );
  }

  void _onTrackUnsubscribed(TrackUnsubscribedEvent event) {
    if (event.track is! RemoteVideoTrack) return;
    _dropTrackIfCurrent(event.track.sid ?? event.publication.sid);
  }

  void _onTrackUnpublished(TrackUnpublishedEvent event) {
    _dropTrackIfCurrent(event.publication.sid);
  }

  void _syncTrackFromRoom() {
    final room = _room;
    if (room == null) {
      _dropTrackIfCurrent(_activeTrackSid ?? _track?.sid);
      return;
    }
    final latest = _latestSubscribedVideoTrack(room);
    if (latest != null &&
        (_track == null ||
            (!identical(latest, _track) && latest.sid != _track!.sid))) {
      _adoptTrack(
        latest,
        subscribedSid: latest.sid,
        source: 'room_sync',
      );
      return;
    }
    if (_track != null && _isBoundTrackActive(room, _track!)) {
      return;
    }
    _adoptTrack(
      latest,
      subscribedSid: latest?.sid,
      source: 'room_sync',
    );
  }

  bool _isBoundTrackActive(Room room, RemoteVideoTrack track) {
    final sid = track.sid ?? _activeTrackSid;
    for (final participant in room.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        if (!pub.subscribed) continue;
        final candidate = pub.track;
        if (identical(candidate, track)) return true;
        if (sid != null &&
            (pub.sid == sid || candidate?.sid == sid)) {
          return true;
        }
      }
    }
    return false;
  }

  RemoteVideoTrack? _latestSubscribedVideoTrack(Room room) {
    RemoteVideoTrack? last;
    for (final participant in room.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        if (!pub.subscribed || pub.track is! RemoteVideoTrack) continue;
        last = pub.track as RemoteVideoTrack;
      }
    }
    return last;
  }

  void _dropTrackIfCurrent(String? sid) {
    if (sid == null || sid.isEmpty) return;
    if (sid != _activeTrackSid &&
        sid != _subscribedSid &&
        sid != _track?.sid) {
      return;
    }
    _adoptTrack(null, subscribedSid: null, source: 'drop:$sid');
  }

  void _adoptTrack(
    RemoteVideoTrack? track, {
    required String? subscribedSid,
    required String source,
  }) {
    final nextSid = track?.sid ?? subscribedSid;
    if (identical(track, _track) &&
        nextSid == _activeTrackSid &&
        nextSid == _rendererBindSid) {
      _subscribedSid = subscribedSid ?? nextSid;
      return;
    }
    _track = track;
    _subscribedSid = subscribedSid ?? nextSid;
    _activeTrackSid = nextSid;
    _rendererBindSid = nextSid;
    _logOwnershipInvariant(source: source);
    if (mounted) setState(() {});
  }

  void _logOwnershipInvariant({String? source}) {
    final subscribed = _subscribedSid ?? 'null';
    final active = _activeTrackSid ?? 'null';
    final renderer = _rendererBindSid ?? 'null';
    debugPrint('SUBSCRIBED sid=$subscribed');
    debugPrint('ACTIVE_TRACK sid=$active');
    debugPrint('RENDERER_BIND sid=$renderer');
    if (subscribed != active || active != renderer) {
      debugPrint(
        '🔴 TRACK_OWNERSHIP_MISMATCH'
        '${source == null ? '' : ' source=$source'}'
        ' subscribed=$subscribed active=$active renderer=$renderer',
      );
    }
  }

  @override
  void didUpdateWidget(covariant LiveVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live.id != widget.live.id) {
      _disposeController();
      if (widget.isActive) _init();
    } else if (oldWidget.isActive != widget.isActive) {
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
    final room = widget.isActive ? _room : null;
    final track = room == null ? null : _track;
    if (track != null) {
      return ColoredBox(
        color: Colors.black,
        child: VideoTrackRenderer(
          track,
          key: ValueKey('viewer-host-${track.sid ?? track.hashCode}'),
          fit: widget.fit == BoxFit.cover
              ? VideoViewFit.cover
              : VideoViewFit.contain,
          placeholderBuilder: (_) => AnimatedVideoPlaceholder(
            seed: widget.live.id,
            category: widget.live.category,
            hostInitial: widget.live.hostName,
          ),
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
