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
    final room = liveKit.room;
    if (room != null) _attachRoom(room);
    if (widget.isActive) _init();

    // ============================================================
    // [M2 VIDEO-QUALITY] PERMANENT smallest fix — overrides the
    // LiveKit SDK adaptiveStream first-frame 0×0 thumbnail race.
    //
    // ROOT CAUSE (confirmed from 2.11.0 track_settings.dart L44
    // resolveVideoSettings): adaptiveStream merges user-preferred
    // quality vs VisibilityObserver-measured RenderBox dimensions
    // and ALWAYS PICKS THE SMALLER.  If the observer fires BEFORE
    // layout completes (PageView stack first-frame + Animated-
    // VideoPlaceholder interleave), measured dims = 0×0 → SFU is
    // sent 0×0 dimensions and forwards the LOW/MEDIUM simulcast
    // layer FOREVER, even after later layout fills the screen.
    //
    // FIX (production-safe, smallest surface):
    //   1. Fire on PostFrameCallback so RenderBox is laid out.
    //   2. Measure actual logical W×H (NOT the SDK's cached value).
    //   3. If size implies full-screen (W≥350 && H≥350):
    //        a. setVideoDimensions(1280×720) — manual dims request
    //           that equals HIGH layer dimensions.
    //        b. setVideoQuality(HIGH) — user-preference enum HIGH.
    //      When explicit dims are set, resolveVideoSettings still
    //      compares vs. VisibilityObserver dims but since we now
    //      match HIGH layer, even if observer catches up, "smaller"
    //      is identical (no revert to 360p).
    //   4. If size < 350 (thumbnail / collapsed player): do NOTHING.
    //      adaptiveStream correctly continues degrading to 360p/180p
    //      for those views — we do NOT break adaptive behavior on
    //      small views, only un-stick the full-screen stuck case.
    //   5. After 450ms (RTP layer switch latency), read decoder
    //      stats once and fire a repeat setVideoDimensions ONLY if
    //      decoded W<900 (i.e. SFU still not on HIGH; 1 retry is
    //      enough, network re-downgrades on real poor bandwidth are
    //      handled by SFU later).
    //
    // DEBUG-QOS instrumentation preserved per Stage 3 order for
    // evidence capture (removed "PROBE" semantics; renamed to FIX).
    // ============================================================
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final rb = context.findRenderObject() as RenderBox?;
        final size = rb?.hasSize == true ? rb!.size : Size.zero;
        final px = MediaQuery.of(context).devicePixelRatio;
        final track = _track;

        // Find first subscribed remote video publication for explicit fix.
        // 2.11.0 correct type: RemoteTrackPublication<RemoteVideoTrack>
        //   (class "RemoteVideoPublication" does NOT exist in this SDK).
        RemoteTrackPublication<RemoteVideoTrack>? pub;
        final roomObj = _room;
        if (roomObj != null) {
          outer:
          for (final p in roomObj.remoteParticipants.values) {
            for (final vp in p.videoTrackPublications) {
              if (vp.subscribed) {
                pub = vp;
                break outer;
              }
            }
          }
        }

        // Decoder stats BEFORE fix — evidence baseline.
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
              decKbps = track.currentBitrate == null ? null : (track.currentBitrate! / 1000).round();
            }
          } catch (e) {
            statsErr = e.toString();
          }
        }

        final pubW = pub?.dimensions?.width;
        final pubH = pub?.dimensions?.height;

        final before = pub?.videoQuality;
        final beforeDims = pub?.videoDimensions;
        final fullscreen = size.width > 350 && size.height > 350;
        debugPrint(
          '[DEBUG-QOS] VIEWER-RENDERER (before-fix):'
          '  liveId=${widget.live.id}'
          '  logicalPx=${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}'
          '  pixelRatio=${px.toStringAsFixed(2)}'
          '  physicalPx=${(size.width * px).toStringAsFixed(0)}x${(size.height * px).toStringAsFixed(0)}'
          '  isAttached=${rb?.attached ?? false}'
          '  pubDims(WxH)=${pubW ?? "?"}x${pubH ?? "?"}'
          '  decoderStatsFrame(WxH)=${decW ?? "?"}x${decH ?? "?"}'
          '  decoderFps=${decFps ?? "?"}'
          '  decoderCodec=${decMime ?? "?"}'
          '  decoderBitrateKbps=${decKbps ?? "?"}'
          '  decoderStatsErr=${statsErr ?? "none"}'
          '  pub.videoQualityGetterPrefBefore=${before?.name.toUpperCase() ?? "null"}'
          '  pub.videoDimensionsGetterBefore=${beforeDims == null ? "null" : "${beforeDims.width}x${beforeDims.height}"}'
          '  fullScreen?=$fullscreen',
        );

        // ── PERMANENT fix action (only on fullscreen) ───────────
        if (pub != null && fullscreen) {
          try {
            const target = VideoDimensions(1280, 720);
            debugPrint(
              '[VIDEO-FIX] VIEWER-RENDERER fullscreen detected →'
              ' setVideoDimensions(${target.width}x${target.height})'
              ' + setVideoQuality(HIGH)',
            );
            // Order matters: dimensions first (resolves to smaller),
            // then quality enum HIGH (sends both signals to SFU).
            await pub.setVideoDimensions(target);
            await pub.setVideoQuality(VideoQuality.HIGH);
            // Wait ≥ 1 RTT + RTP key-frame for SFU to forward HIGH.
            await Future<void>.delayed(const Duration(milliseconds: 450));
            final after = pub.videoQuality;
            final afterDims = pub.videoDimensions;
            // Re-read decoder stats AFTER fix.
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
                  aftDecKbps = track.currentBitrate == null ? null : (track.currentBitrate! / 1000).round();
                }
              } catch (_) {}
            }
            // 1 retry if decoded width still < 900 (i.e. not on HIGH).
            if (track != null && (aftDecW == null || aftDecW < 900)) {
              debugPrint(
                '[VIDEO-FIX] VIEWER-RENDERER after 450ms decoder still'
                ' W=${aftDecW ?? "?"} (HIGH=1280); retry setVideoDimensions once',
              );
              await Future<void>.delayed(const Duration(milliseconds: 200));
              await pub.setVideoDimensions(target);
              await pub.setVideoQuality(VideoQuality.HIGH);
            }
            debugPrint(
              '[DEBUG-QOS] VIEWER-RENDERER (after-fix):'
              '  pub.videoQualityGetterAfter=${after.name.toUpperCase()}'
              '  pub.videoDimensionsGetterAfter=${afterDims == null ? "null" : "${afterDims.width}x${afterDims.height}"}'
              '  EXPLICIT_DIMS_CHANGED? ${beforeDims != afterDims ? "YES" : "NO (dims already set or SFU will forward via quality enum)"}'
              '  QUALITY_ENUM_CHANGED? ${before != after ? "YES" : "NO (already HIGH)"}'
              '  decoderFrameAfterFix(WxH)=${aftDecW ?? "?"}x${aftDecH ?? "?"}'
              '  decoderCodecAfter=$aftDecMime'
              '  decoderBitrateAfterKbps=${aftDecKbps ?? "?"}',
            );
          } catch (e) {
            debugPrint('[VIDEO-FIX] VIEWER-RENDERER fix apply failed: $e');
          }
        } else {
          debugPrint(
            '[VIDEO-FIX] VIEWER-RENDERER: NOT applying fix —'
            ' fullScreen=$fullscreen (pub!=null?=${pub != null}).'
            ' adaptiveStream continues normal degrade for small/thumbnail view.',
          );
        }
      } catch (e) {
        debugPrint('[DEBUG-QOS] VIEWER-RENDERER (err): $e');
      }
    });
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
      if (widget.isActive) {
        if (_controller == null) {
          _init();
        } else {
          _controller?.play();
        }
      } else {
        _controller?.pause();
        // Release decoder while off-screen.
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
