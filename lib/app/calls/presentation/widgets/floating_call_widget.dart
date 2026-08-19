import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/app/calls/services/livekit_call_service.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FloatingCallWidget extends StatefulWidget {
  final CallEntity call;
  final LiveKitCallService livekitService;
  final String timerText;
  final bool isMuted;
  final VoidCallback onMaximize;

  const FloatingCallWidget({
    super.key,
    required this.call,
    required this.livekitService,
    required this.timerText,
    required this.isMuted,
    required this.onMaximize,
  });

  @override
  State<FloatingCallWidget> createState() => _FloatingCallWidgetState();
}

class _FloatingCallWidgetState extends State<FloatingCallWidget> {
  Offset _position = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final caller = widget.call.getDisplayUser(currentUserId);
    final displayName = caller.displayName;
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
        onTap: widget.onMaximize,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(24),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.95)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: showRemoteVideo
                          ? VideoTrackRenderer(
                              track,
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 14,
                                height: 14,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                  'assets/images/app_icon.png',
                                  width: 14,
                                  height: 14,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              displayName,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
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
                              '${widget.timerText} • Bimo-Bond',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
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
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.06)),
                        ),
                        child: Icon(
                          widget.isMuted ? LucideIcons.micOff : LucideIcons.mic,
                          color: widget.isMuted
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black87),
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
                      child: Icon(
                        LucideIcons.maximize2,
                        color: isDark ? Colors.white : const Color(0xFF4F46E5),
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
