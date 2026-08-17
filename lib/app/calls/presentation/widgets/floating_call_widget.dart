import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/app/calls/presentation/pages/active_call_screen.dart';
import 'package:bimobondapp/app/calls/services/livekit_call_service.dart';
import 'package:bimobondapp/core/routes/app_router.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FloatingCallWidget extends StatefulWidget {
  final CallEntity call;
  final LiveKitCallService livekitService;
  final String timerText;
  final bool isMuted;

  const FloatingCallWidget({
    super.key,
    required this.call,
    required this.livekitService,
    required this.timerText,
    required this.isMuted,
  });

  @override
  State<FloatingCallWidget> createState() => _FloatingCallWidgetState();
}

class _FloatingCallWidgetState extends State<FloatingCallWidget> {
  Offset _position = const Offset(20, 100);

  void _onMaximizeCall(BuildContext context) {
    final nav = AppRouter.rootNavigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (routeContext) => BlocProvider.value(
            value: context.read<CallBloc>(),
            child: const ActiveCallScreen(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final caller = widget.call.initiatedBy;
    final displayName = caller.fullName?.isNotEmpty == true
        ? caller.fullName!
        : caller.username;
    final isVideo = widget.call.isVideo;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onTap: () => _onMaximizeCall(context),
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(24),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: StreamBuilder<List<Participant>>(
              stream: widget.livekitService.onParticipantsChanged,
              initialData: widget.livekitService.allParticipants,
              builder: (context, snapshot) {
                final participants = snapshot.data ?? [];
                final localParticipant =
                    widget.livekitService.room?.localParticipant;
                final Participant? remoteParticipant = participants
                    .where((p) => p.sid != localParticipant?.sid)
                    .firstOrNull ??
                    localParticipant;

                TrackPublication? videoPub;
                if (remoteParticipant != null && remoteParticipant.sid.isNotEmpty) {
                  videoPub =
                      remoteParticipant.videoTrackPublications.firstOrNull;
                }
                final track = videoPub?.track;
                final trackMuted = videoPub?.muted ?? true;

                final showRemoteVideo =
                    isVideo && track != null && track is VideoTrack && !trackMuted;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mini Video Preview or Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1E293B),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: showRemoteVideo
                          ? VideoTrackRenderer(
                              track as VideoTrack,
                              fit: VideoViewFit.cover,
                            )
                          : SafeNetworkAvatar(
                              imageUrl: caller.avatarUrl,
                              radius: 21,
                              fallbackText: displayName,
                            ),
                    ),
                    const SizedBox(width: 10),

                    // Caller Name & Call Duration / Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.timerText,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Mute Quick Action
                    GestureDetector(
                      onTap: () {
                        context.read<CallBloc>().add(const ToggleMuteEvent());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isMuted
                              ? const Color(0xFFEF4444)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          widget.isMuted ? LucideIcons.micOff : LucideIcons.mic,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Maximize Icon
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                      ),
                      child: const Icon(
                        LucideIcons.maximize2,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
