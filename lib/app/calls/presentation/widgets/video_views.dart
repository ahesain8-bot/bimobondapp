import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Corner positions for draggable local video preview.
enum PreviewCorner { topLeft, topRight, bottomLeft, bottomRight }

class RemoteVideoView extends StatelessWidget {
  final Participant? participant;
  final String? fallbackName;
  final String? fallbackAvatarUrl;
  final bool isCameraOff;
  final bool isMuted;

  const RemoteVideoView({
    super.key,
    this.participant,
    this.fallbackName,
    this.fallbackAvatarUrl,
    this.isCameraOff = false,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    TrackPublication? videoPub;
    if (participant != null) {
      videoPub = participant!.videoTrackPublications.firstOrNull;
    }

    final track = videoPub?.track;
    final trackMuted = videoPub?.muted ?? true;

    final name = participant?.name.isNotEmpty == true
        ? participant!.name
        : (fallbackName ?? 'Remote User');

    final showVideo = track != null &&
        track is VideoTrack &&
        !trackMuted &&
        !isCameraOff;

    return Stack(
      children: [
        Positioned.fill(
          child: showVideo
              ? VideoTrackRenderer(track)
              : _buildFallbackAvatar(context, name),
        ),

        // Mute or camera status indicator overlay
        if (isMuted || isCameraOff)
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMuted) ...[
                    const Icon(LucideIcons.micOff, color: Colors.redAccent, size: 14),
                    const SizedBox(width: 4),
                  ],
                  if (isCameraOff) ...[
                    const Icon(LucideIcons.videoOff, color: Colors.redAccent, size: 14),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackAvatar(BuildContext context, String name) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.05),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: SafeNetworkAvatar(
                imageUrl: fallbackAvatarUrl,
                radius: 54,
                fallbackText: name,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocalVideoView extends StatefulWidget {
  final Participant? localParticipant;
  final String? localName;
  final String? localAvatarUrl;
  final bool isCameraOff;
  final bool isMuted;
  final VoidCallback? onDoubleTapSwap;

  const LocalVideoView({
    super.key,
    this.localParticipant,
    this.localName,
    this.localAvatarUrl,
    this.isCameraOff = false,
    this.isMuted = false,
    this.onDoubleTapSwap,
  });

  @override
  State<LocalVideoView> createState() => _LocalVideoViewState();
}

class _LocalVideoViewState extends State<LocalVideoView> {
  PreviewCorner _corner = PreviewCorner.topRight;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  final double _cardWidth = 88.0;
  final double _cardHeight = 128.0;
  final double _margin = 16.0;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + _margin + 50; // below top header
    final bottomPadding = mediaQuery.padding.bottom + _margin + 90; // above controls
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // Target positions for 4 corners
    Offset targetOffset;
    switch (_corner) {
      case PreviewCorner.topLeft:
        targetOffset = Offset(_margin, topPadding);
        break;
      case PreviewCorner.topRight:
        targetOffset = Offset(screenWidth - _cardWidth - _margin, topPadding);
        break;
      case PreviewCorner.bottomLeft:
        targetOffset = Offset(_margin, screenHeight - _cardHeight - bottomPadding);
        break;
      case PreviewCorner.bottomRight:
        targetOffset = Offset(screenWidth - _cardWidth - _margin, screenHeight - _cardHeight - bottomPadding);
        break;
    }

    final currentOffset = _isDragging ? _dragOffset : targetOffset;

    TrackPublication? videoPub;
    if (widget.localParticipant != null) {
      videoPub = widget.localParticipant!.videoTrackPublications.firstOrNull;
    }

    final track = videoPub?.track;
    final trackMuted = videoPub?.muted ?? true;
    final showVideo = track != null &&
        track is VideoTrack &&
        !trackMuted &&
        !widget.isCameraOff;

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      left: currentOffset.dx,
      top: currentOffset.dy,
      width: _cardWidth,
      height: _cardHeight,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
            _dragOffset = currentOffset;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _dragOffset += details.delta;
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
            _corner = _calculateClosestCorner(
              _dragOffset,
              screenWidth,
              screenHeight,
              topPadding,
              bottomPadding,
            );
          });
        },
        onDoubleTap: widget.onDoubleTapSwap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (showVideo)
                Positioned.fill(
                  child: VideoTrackRenderer(
                    track,
                    fit: VideoViewFit.cover,
                  ),
                )
              else
                Center(
                  child: SafeNetworkAvatar(
                    imageUrl: widget.localAvatarUrl,
                    radius: 20,
                    fallbackText: widget.localName ?? 'Me',
                  ),
                ),

              // Mic Mute indicator icon in corner
              if (widget.isMuted)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.micOff,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),

              // Label tag
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'You',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreviewCorner _calculateClosestCorner(
    Offset position,
    double screenWidth,
    double screenHeight,
    double topPadding,
    double bottomPadding,
  ) {
    final isLeft = position.dx + (_cardWidth / 2) < screenWidth / 2;
    final isTop = position.dy + (_cardHeight / 2) < screenHeight / 2;

    if (isTop && isLeft) return PreviewCorner.topLeft;
    if (isTop && !isLeft) return PreviewCorner.topRight;
    if (!isTop && isLeft) return PreviewCorner.bottomLeft;
    return PreviewCorner.bottomRight;
  }
}
