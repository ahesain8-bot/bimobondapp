import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/utils/app_media_cache_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/fake_livekit_service.dart'
    show LiveKitConnectionState, LiveKitService;
import '../../domain/entities/live_entity.dart';
import '../di/live_viewer_injector.dart' as di;
import 'fallback_media.dart';

/// Renders the active live's remote video.
///
/// There is exactly one LiveKit [Room] in the process and every page of the
/// feed's PageView builds one of these. Only the page the viewer is actually
/// watching may observe that room: an off-screen instance that attaches to it
/// registers listeners and issues subscription calls against media it is not
/// showing. Binding is therefore gated on [isActive] and torn down the moment
/// the page stops being active.
///
/// Subscription quality is left entirely to `adaptiveStream`. livekit_client
/// 2.11 merges any manual `setVideoQuality` / `setVideoDimensions` preference
/// with the dimensions it computes from the mounted renderer and sends the
/// *smaller* of the two, so a manual value can only ever cap the picture — it
/// cannot raise it. Letting the SDK measure the real renderer is both simpler
/// and strictly higher quality.
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
  String? _lastTrackDiagnostic;
  bool _trackRebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    _liveKit = di.sl<LiveKitService>();
    if (widget.isActive) {
      _bindLiveKit();
      if (!widget.liveKitOnly) _init();
    }
  }

  @override
  void didUpdateWidget(covariant LiveVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final liveChanged = oldWidget.live.id != widget.live.id;
    final activeChanged = oldWidget.isActive != widget.isActive;
    if (!liveChanged && !activeChanged) return;

    if (widget.isActive) {
      _bindLiveKit();
      if (!widget.liveKitOnly) {
        if (liveChanged) {
          _disposeController();
          _init();
        } else if (_controller == null) {
          _init();
        } else {
          _controller?.play();
        }
      }
      return;
    }

    _unbindLiveKit();
    _controller?.pause();
    _disposeController();
    if (mounted) {
      setState(() {
        _initializing = false;
        _buffering = false;
      });
    }
  }

  @override
  void dispose() {
    _unbindLiveKit();
    _disposeController();
    super.dispose();
  }

  // ── LiveKit binding ───────────────────────────────────────────────────────

  void _bindLiveKit() {
    final liveKit = _liveKit;
    if (liveKit == null || _liveKitSub != null) return;
    _liveKitSub = liveKit.stateStream.listen(_onLiveKitState);
    _attachRoomIfOwned();
  }

  /// Attaches only to the room that belongs to *this* live.
  ///
  /// The page becomes active before the service has finished swapping rooms,
  /// so for a short window `liveKit.room` is still the previous live's. The
  /// room name is the live id, which makes ownership checkable without
  /// reaching into the SDK.
  void _attachRoomIfOwned() {
    final liveKit = _liveKit;
    if (liveKit == null) return;
    final room = liveKit.room;
    if (room == null || liveKit.roomName != widget.live.id) return;
    _attachRoom(room);
  }

  void _unbindLiveKit() {
    _liveKitSub?.cancel();
    _liveKitSub = null;
    _detachRoom();
  }

  void _onLiveKitState(LiveKitConnectionState state) {
    if (!mounted || !widget.isActive) return;
    final liveKit = _liveKit;
    if (liveKit == null) return;

    switch (state) {
      case LiveKitConnectionState.connected:
        _attachRoomIfOwned();
        if (!widget.liveKitOnly &&
            _controller == null &&
            !_initializing &&
            !_hasError) {
          _init();
        }
      case LiveKitConnectionState.reconnecting:
      case LiveKitConnectionState.connecting:
        // A native reconnect keeps the Room, its participants and its
        // subscriptions alive. Detaching here would destroy a renderer that is
        // about to resume with the same track and replace the last frame with
        // the poster for no reason.
        break;
      case LiveKitConnectionState.disconnected:
      case LiveKitConnectionState.failed:
        _detachRoom();
        _requestSafeRebuild();
    }
  }

  void _attachRoom(Room room) {
    if (identical(_room, room)) return;
    _detachRoom();
    _room = room;
    room.addListener(_onRoomChanged);
    _refreshTrack();
  }

  void _detachRoom() {
    final room = _room;
    _room = null;
    if (room != null) room.removeListener(_onRoomChanged);
    if (_track != null) {
      debugPrint(
        '[VIDEO-DIAG] renderer released liveId=${widget.live.id}',
      );
    }
    _track = null;
    _lastTrackDiagnostic = null;
  }

  void _onRoomChanged() => _refreshTrack();

  /// Resolves the single track this player renders.
  ///
  /// Muted publications are kept: the host turning their camera off must not
  /// tear the renderer down and rebuild it a moment later, and
  /// `VideoTrackRenderer` already paints [placeholderBuilder] while no frames
  /// arrive. Only a genuinely different track — or no subscribed track at all
  /// — changes what is mounted.
  void _refreshTrack() {
    final room = _room;
    final next = room == null ? null : _firstSubscribedVideoTrack(room);
    _logTrackDiagnostic(room, next);
    if (identical(next, _track)) return;
    if (next != null) {
      debugPrint(
        '[VIDEO-DIAG] renderer mounting liveId=${widget.live.id}'
        ' sid=${next.sid}'
        ' replacing=${_track?.sid ?? "none"}',
      );
    }
    _track = next;
    _requestSafeRebuild();
  }

  void _requestSafeRebuild() {
    if (!mounted) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    final isBuilding =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!isBuilding) {
      setState(() {});
      return;
    }

    if (_trackRebuildScheduled) return;
    _trackRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackRebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _logTrackDiagnostic(Room? room, RemoteVideoTrack? track) {
    var videoPublications = 0;
    var subscribedVideoPublications = 0;
    final participants = room?.remoteParticipants.values;
    if (participants != null) {
      for (final participant in participants) {
        for (final publication in participant.videoTrackPublications) {
          videoPublications++;
          if (publication.subscribed) subscribedVideoPublications++;
        }
      }
    }
    final signature =
        '${room?.connectionState.name}|${room?.remoteParticipants.length ?? 0}'
        '|$videoPublications|$subscribedVideoPublications|${track != null}';
    if (_lastTrackDiagnostic == signature) return;
    _lastTrackDiagnostic = signature;
    debugPrint(
      '[LiveKit] room=${room?.connectionState.name ?? "none"}'
      ' remoteParticipants=${room?.remoteParticipants.length ?? 0}'
      ' videoTrack=${track != null}'
      ' subscribed=$subscribedVideoPublications/$videoPublications',
    );
  }

  RemoteVideoTrack? _firstSubscribedVideoTrack(Room room) {
    for (final participant in room.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        final track = pub.track;
        if (pub.subscribed && track != null) return track;
      }
    }
    return null;
  }

  // ── HTTP fallback (non-LiveKit sources only) ──────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────

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
    // Mount as soon as LiveKit gives us a subscribed remote track. Receiver
    // stats are not a reliable readiness signal on every platform, and
    // livekit_client 2.11 exposes no first-frame callback: the honest signal
    // is "renderer attached to a subscribed track", with the poster painted
    // underneath until the decoder produces something.
    final track = _track;
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
