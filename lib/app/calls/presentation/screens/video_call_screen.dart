import 'dart:async';
import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/services/livekit_call_service.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/call_controls.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/call_status.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/video_views.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VideoCallScreen extends StatefulWidget {
  final CallEntity call;
  final LiveKitCallService livekitService;
  final String timerText;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final CallUiStatusState statusState;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onAddParticipant;
  final VoidCallback onSwitchToVoice;
  final VoidCallback onEndCall;
  final VoidCallback onMinimize;

  const VideoCallScreen({
    super.key,
    required this.call,
    required this.livekitService,
    required this.timerText,
    required this.isMuted,
    required this.isCameraOff,
    required this.isSpeakerOn,
    required this.statusState,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onSwitchCamera,
    required this.onToggleSpeaker,
    required this.onAddParticipant,
    required this.onSwitchToVoice,
    required this.onEndCall,
    required this.onMinimize,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isSwapped = false; // Double-tap swap state

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final caller = widget.call.getDisplayUser(
      currentUserId,
      isOutgoing: widget.statusState == CallUiStatusState.calling ||
          widget.statusState == CallUiStatusState.ringing,
    );
    final displayName = caller.displayName;

    return StreamBuilder<List<Participant>>(
      stream: widget.livekitService.onParticipantsChanged,
      initialData: widget.livekitService.allParticipants,
      builder: (context, snapshot) {
        final participants = snapshot.data ?? [];
        final localParticipant = widget.livekitService.room?.localParticipant;
        final Participant? remoteParticipant = participants
            .where((p) => p.sid != localParticipant?.sid)
            .firstOrNull ??
            localParticipant;

        // Standard or swapped participant selection
        final mainParticipant =
            _isSwapped ? localParticipant : remoteParticipant;
        final previewParticipant =
            _isSwapped ? remoteParticipant : localParticipant;

        final isMainCameraOff = _isSwapped ? widget.isCameraOff : false;
        final isPreviewCameraOff = _isSwapped ? false : widget.isCameraOff;

        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: _toggleControls,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // Main Full Screen Video
                Positioned.fill(
                  child: RemoteVideoView(
                    participant: mainParticipant,
                    fallbackName: _isSwapped ? 'You' : displayName,
                    fallbackAvatarUrl:
                        _isSwapped ? null : caller.avatarUrl,
                    isCameraOff: isMainCameraOff,
                    isMuted: _isSwapped ? widget.isMuted : false,
                  ),
                ),

                // Local Camera Corner Preview (Draggable, Double-tap to Swap)
                LocalVideoView(
                  localParticipant: previewParticipant,
                  localName: _isSwapped ? displayName : 'You',
                  localAvatarUrl: _isSwapped ? caller.avatarUrl : null,
                  isCameraOff: isPreviewCameraOff,
                  isMuted: _isSwapped ? false : widget.isMuted,
                  onDoubleTapSwap: () {
                    setState(() {
                      _isSwapped = !_isSwapped;
                    });
                  },
                ),

                // Top Bar (Animated Opacity fade in/out)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  top: _showControls ? 0 : -80,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: widget.onMinimize,
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                              child: const Icon(
                                LucideIcons.chevronDown,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      width: 16,
                                      height: 16,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Image.asset(
                                        'assets/images/app_icon.png',
                                        width: 16,
                                        height: 16,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.statusState == CallUiStatusState.connected
                                    ? widget.timerText
                                    : (widget.statusState == CallUiStatusState.calling
                                        ? (Localizations.localeOf(context).languageCode == 'ar' ? 'جاري الاتصال...' : 'Calling...')
                                        : (widget.statusState == CallUiStatusState.ringing
                                            ? (Localizations.localeOf(context).languageCode == 'ar' ? 'يرن...' : 'Ringing...')
                                            : widget.timerText)),
                                style: const TextStyle(
                                  color: Color(0xFFA5B4FC),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Controls Bar (Animated Opacity fade in/out)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  bottom: _showControls ? 24 : -100,
                  left: 16,
                  right: 16,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showControls ? 1.0 : 0.0,
                    child: Center(
                      child: CallControls(
                        isMuted: widget.isMuted,
                        isCameraOff: widget.isCameraOff,
                        isSpeakerOn: widget.isSpeakerOn,
                        isVideoCall: true,
                        onToggleMute: widget.onToggleMute,
                        onToggleCamera: widget.onToggleCamera,
                        onSwitchCamera: widget.onSwitchCamera,
                        onToggleSpeaker: widget.onToggleSpeaker,
                        onAddParticipant: widget.onAddParticipant,
                        onToggleCallType: widget.onSwitchToVoice,
                        onEndCall: widget.onEndCall,
                        isDark: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
