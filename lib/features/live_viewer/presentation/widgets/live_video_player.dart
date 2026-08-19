import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/fake_livekit_service.dart'
    show LiveKitConnectionState, LiveKitService;
import '../../domain/entities/live_entity.dart';
import '../providers/live_dependencies.dart';
import 'fallback_media.dart';

/// Fullscreen live video.
///
/// Plays the host's WebRTC stream through LiveKit ([VideoTrackRenderer]) once
/// the viewer room has a subscribed remote video track. Falls back to the
/// thumbnail / animated placeholder while connecting. An http(s) [streamUrl]
/// (mock/HLS) is still played with `video_player` as a secondary path.
///
/// Only initializes the player when [isActive] to keep vertical swipe smooth
/// and avoid dispose races.
class LiveVideoPlayer extends ConsumerStatefulWidget {
  final LiveEntity live;
  final bool isActive;

  /// How media fills its parent. Prefer [BoxFit.fitWidth] for PK panes
  /// so content is not excessively zoomed/cropped.
  final BoxFit fit;

  const LiveVideoPlayer({
    super.key,
    required this.live,
    this.isActive = true,
    this.fit = BoxFit.cover,
  });

  @override
  ConsumerState<LiveVideoPlayer> createState() => _LiveVideoPlayerState();
}

class _LiveVideoPlayerState extends ConsumerState<LiveVideoPlayer> {
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
    final liveKit = ref.read(liveKitServiceProvider);
    _liveKit = liveKit;
    _liveKitSub = liveKit.stateStream.listen(_onLiveKitState);
    // Do NOT _attachRoom here — initState for neighbor pages in PageView
    // runs while the proxy still points at the currently-active session's
    // room. Attaching here would render the wrong live's last frame when
    // this page becomes active. Instead, rely on _onLiveKitState (fired
    // by _setProxyDelegates when activate() switches the proxy) to attach
    // the correct room at the right time.
    if (widget.isActive) _init();

    // ============================================================
    // [M2 VIDEO-QUALITY 480p FLOOR] Permanent production fix.
    //
    // PRODUCT RULE (from M2 spec):
    //   • NEVER publish, request, or select a layer below 480p.
    //   • Host publishes exactly 2 simulcast layers:
    //       HIGH = 1280×720 @30fps 2500 kbps
    //       LOW  =  854×480 @30fps 1200 kbps
    //     (no 360p / 180p fallback layers exist on host side).
    //   • Viewer adaptiveStream MUST stay enabled (keeps SFU
    //     bandwidth-layer selection + visibility-based disabled flag).
    //
    // CLEAN PUBLIC-API IMPLEMENTATION (no SDK fork, no timers):
    //   1. Extract helper `_findVideoPub()` — locates the host's
    //      subscribed RemoteTrackPublication<RemoteVideoTrack>.
    //   2. Extract helper `_applyQualityFloor(bool isActive)` — uses
    //      ONLY LiveKit 2.11.0 PUBLIC API (setVideoDimensions +
    //      setVideoQuality):
    //        isActive=true → setVideoDimensions(1280×720) +
    //                        setVideoQuality(HIGH)
    //          → SFU receives MAX-dims = 720p. Since only 2 layers
    //            exist, SFU bandwidth-estimate will pick the LARGEST
    //            layer that FITS within 1280×720: either HIGH (good
    //            network) or LOW 480p (weak network). Since 360p/180p
    //            layers simply do not exist in host publish, the SFU
    //            CANNOT fall below 480p — hard guarantee.
    //        isActive=false (PageView offscreen) → setVideoDimensions
    //                         (854×480) [MINIMUM layer, per user rule
    //                         "Do NOT switch inactive items to 360p /
    //                          180p — keep minimum 480p always"].
    //          → Saves 1300 kbps (2500 - 1200) per offscreen item,
    //            prevents multi-PageView decoder / bandwidth
    //            contention, eliminates buffering on vertical swipe.
    //   3. Call `_applyQualityFloor(widget.isActive)` AFTER FIRST
    //      LAYOUT via addPostFrameCallback (so RenderBox exists) AND
    //      also from:
    //        • didUpdateWidget on isActive transitions (PageView
    //          active↔inactive flips), AND
    //        • _onLiveKitState when reconnecting (Room just became
    //          connected → re-apply the floor after re-subscribe).
    //      No Timer.periodic, no per-frame work, no repeated
    //      setVideoDimensions calls — userPreference set once per
    //      state transition, which SDK deduplicates internally via
    //      `if (newValue == _userPreference?.dimensions) return;`
    //      (remote.dart L318 setVideoDimensions early return).
    //
    // The adaptiveStream VisibilityObserver still runs and still
    // measures RenderBox size.  resolveVideoSettings (track_settings
    // L44) will pick smaller(userPref, observerDim).  userPref is
    // 1280×720 (fullscreen) or 854×480 (offscreen).  observerDim on
    // mid-tier DPR 2.6 = ~936 px wide.  Area(936×2024) = 1.9M >
    // Area(854×480)=0.41M → userPref 480p IS SMALLER → 480p wins
    // resolve.  High-end DPR 3.5 = width 1260 → userPref 1280 wins
    // → 720p on good devices.  On all devices: NEVER below 480p
    // because userPref floor = 480p and host has no lower layers.
    //
    // DEBUG-QOS instrumentation preserved for runtime evidence.
    // ============================================================
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Apply floor after first layout — guarantees the
      // post-frame transition at least once after first layout.
      unawaited(_applyQualityFloor(widget.isActive));
    });
  }

  /// First subscribed RemoteVideoTrack publication from any remote
  /// participant in the attached Room (the host's camera).
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

  /// Applies the M2 480p MINIMUM quality floor using ONLY 2.11.0
  /// public SDK APIs (setVideoDimensions / setVideoQuality).
  /// Called once per state transition, NOT repeatedly — the SDK
  /// already deduplicates no-op calls at the top of both methods.
  ///
  /// isActive=true → request HIGH layer dims (1280×720):
  ///   SFU will adapt freely between the 2 host layers:
  ///     • HIGH=1280×720 on good network
  ///     • LOW = 854×480 on medium/weak
  ///   No other layers exist so selection CANNOT drop below 480p.
  ///
  /// isActive=false (PageView offscreen) → clamp to MIN 480p only:
  ///   Saves ~1300 kbps per offscreen decoder vs keeping 720p,
  ///   eliminates multi-decoder contention during fast swipe,
  ///   AND complies with "Do NOT switch inactive items to 360/180p"
  ///   because 854×480 is the published MINIMUM layer.
  Future<void> _applyQualityFloor(bool isActive) async {
    final pub = _findVideoPub();
    if (pub == null) return;
    try {
      final dims = isActive
          ? const VideoDimensions(1280, 720)
          : const VideoDimensions(854, 480);
      final quality = isActive ? VideoQuality.HIGH : VideoQuality.LOW;
      debugPrint('[VIDEO-FIX] VIEWER-FLOOR: liveId=${widget.live.id}  isActive=$isActive  → setVideoDimensions(${dims.width}x${dims.height}) + setVideoQuality(${quality.name.toUpperCase()})');
      // setVideoDimensions first (dimensions override quality enum in
      // buildUpdateTrackSettings — track_settings.dart L129-133), then
      // apply quality enum so both signals reach the SFU signaling.
      await pub.setVideoDimensions(dims);
      await pub.setVideoQuality(quality);
    } catch (_) {
      // quality floor application is best-effort
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

  /// LiveKit room appeared / reconnected → start rendering its remote video.
  /// Also triggers the secondary `video_player` fallback path when the
  /// LiveKit service supplies an HTTP(S) mock `streamUrl`.
  ///
  /// The proxy is shared and always points at the active session's room.
  /// Only the active widget (isActive=true) will _init() and render video;
  /// offscreen widgets attach the room but don't render.
  void _onLiveKitState(LiveKitConnectionState state) {
    if (!mounted) return;
    final liveKit = _liveKit;
    if (liveKit == null) return;

    if (state == LiveKitConnectionState.connected) {
      // ALWAYS re-attach to the proxy's current room — the proxy
      // delegate may have been switched by activate()/_adoptPreloaded().
      // Even offscreen widgets attach so that when they become active
      // the video is already rendering (no black flash).
      final room = liveKit.room;
      if (room != null && room != _room) _attachRoom(room);
      // Only the active widget initializes the video_player fallback
      // path (for http mock streams). LiveKit video rendering happens
      // via VideoTrackRenderer which is always alive once attached.
      if (widget.isActive &&
          _controller == null &&
          !_initializing &&
          !_hasError) {
        _init();
      }
      // Re-apply 480p floor whenever Room (re)connects — a fresh
      // subscription means a brand-new RemoteTrackPublication whose
      // userPreference defaults to HIGH / no-dims. Reset to our floor.
      unawaited(_applyQualityFloor(widget.isActive));
    } else if (state == LiveKitConnectionState.disconnected ||
        state == LiveKitConnectionState.failed) {
      _detachRoom();
      // Sync only buffering/state fields, no unnecessary rebuild of the
      // entire VideoTrackRenderer.
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

  /// Room emits on every event (participant/track subscribed, etc.).
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

  /// First subscribed remote video track (host camera), or null.
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
      if (widget.isActive) _init();
    } else if (oldWidget.isActive != widget.isActive) {
      unawaited(_applyQualityFloor(widget.isActive));
      if (widget.isActive) {
        // Do NOT _attachRoom here — didUpdateWidget runs during the
        // build phase, BEFORE _onPageChanged → activate() switches the
        // proxy delegate. Reading _liveKit?.room here would return the
        // OLD room, causing the widget to render the previous live's
        // last frame for a few ms before _onLiveKitState fires with the
        // new room. Instead, rely on _onLiveKitState (triggered by
        // _setProxyDelegates → proxy emits 'connected') to attach the
        // correct room.
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
    // LiveKit uses `wss://` URLs — those are rendered via VideoTrackRenderer,
    // NOT video_player (ExoPlayer rejects non-http(s) protocols). Only run the
    // video_player path for actual http(s) mock/HLS streams.
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
    // Primary path: host WebRTC video over LiveKit.
    // Use _room directly (not widget.isActive ? _room : null) so that
    // when the proxy switches rooms, the video appears instantly for
    // the active widget. Offscreen widgets have isActive=false which
    // is handled by the caller (LiveRoomPage) not rendering this widget
    // at all when not active.
    final room = _room;
    final track = room == null ? null : _track;
    if (track != null) {
      // Stack: placeholder in background, VideoTrackRenderer on top.
      // This prevents the black flash that occurs during the transition
      // from AnimatedVideoPlaceholder to VideoTrackRenderer — the
      // placeholder stays visible behind the renderer until the first
      // video frame is drawn, then the renderer covers it completely.
      return Stack(
        fit: StackFit.expand,
        children: [
          // Background placeholder — stays visible until video covers it
          AnimatedVideoPlaceholder(
            seed: widget.live.id,
            category: widget.live.category,
            hostInitial: widget.live.hostName,
          ),
          // Video renderer on top
          VideoTrackRenderer(
            track,
            fit: widget.fit == BoxFit.cover
                ? VideoViewFit.cover
                : VideoViewFit.contain,
            // No placeholder needed — the background Stack handles it
            placeholderBuilder: (_) => const SizedBox.shrink(),
          ),
        ],
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
          placeholder: (_, __) => AnimatedVideoPlaceholder(
            seed: widget.live.id,
            category: widget.live.category,
            hostInitial: widget.live.hostName,
          ),
          errorWidget: (_, __, ___) => AnimatedVideoPlaceholder(
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
