import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/call_controls.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/call_status.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VoiceCallScreen extends StatefulWidget {
  final CallEntity call;
  final String timerText;
  final bool isOutgoingRinging;
  final bool isMuted;
  final bool isSpeakerOn;
  final CallUiStatusState statusState;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onAddParticipant;
  final VoidCallback onSwitchToVideo;
  final VoidCallback onEndCall;
  final VoidCallback onMinimize;

  const VoiceCallScreen({
    super.key,
    required this.call,
    required this.timerText,
    required this.isOutgoingRinging,
    required this.isMuted,
    required this.isSpeakerOn,
    required this.statusState,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onAddParticipant,
    required this.onSwitchToVideo,
    required this.onEndCall,
    required this.onMinimize,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _rippleAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeInOut),
    );

    if (widget.isOutgoingRinging ||
        widget.statusState == CallUiStatusState.calling ||
        widget.statusState == CallUiStatusState.ringing) {
      _rippleController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceCallScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOutgoingRinging ||
        widget.statusState == CallUiStatusState.calling ||
        widget.statusState == CallUiStatusState.ringing) {
      if (!_rippleController.isAnimating) {
        _rippleController.repeat(reverse: true);
      }
    } else {
      if (_rippleController.isAnimating) {
        _rippleController.stop();
        _rippleController.reset();
      }
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final caller = widget.call.initiatedBy;
    final displayName = caller.fullName?.isNotEmpty == true
        ? caller.fullName!
        : caller.username;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Background Ambient Radial Glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1.2,
                    colors: isDark
                        ? [
                            const Color(0x404F46E5),
                            const Color(0xFF0F172A),
                          ]
                        : [
                            const Color(0x186366F1),
                            Colors.white,
                          ],
                  ),
                ),
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Header Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Minimize / Back Button
                      IconButton(
                        onPressed: widget.onMinimize,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          child: Icon(
                            LucideIcons.chevronDown,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Center Caller Profile Section
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pulsing Ripple Avatar Container
                      AnimatedBuilder(
                        animation: _rippleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _rippleController.isAnimating
                                ? _rippleAnimation.value
                                : 1.0,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isDark
                                        ? const Color(0xFF6366F1)
                                        : const Color(0xFF4F46E5))
                                    .withValues(
                                  alpha: _rippleController.isAnimating ? 0.45 : 0.2,
                                ),
                                blurRadius: 36,
                                spreadRadius: _rippleController.isAnimating ? 12 : 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: SafeNetworkAvatar(
                              imageUrl: caller.avatarUrl,
                              radius: 55,
                              fallbackText: displayName,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Caller Name & Handle
                      Text(
                        displayName,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '@${caller.username}',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black54,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Timer Text directly under User Name
                      Text(
                        widget.statusState == CallUiStatusState.connected
                            ? widget.timerText
                            : (widget.statusState == CallUiStatusState.calling
                                ? (Localizations.localeOf(context).languageCode == 'ar' ? 'جاري الاتصال...' : 'Calling...')
                                : (widget.statusState == CallUiStatusState.ringing
                                    ? (Localizations.localeOf(context).languageCode == 'ar' ? 'جاري الرنين...' : 'Ringing...')
                                    : widget.timerText)),
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF818CF8)
                              : const Color(0xFF4F46E5),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Controls Bar
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                  child: CallControls(
                    isMuted: widget.isMuted,
                    isCameraOff: true,
                    isSpeakerOn: widget.isSpeakerOn,
                    isVideoCall: false,
                    onToggleMute: widget.onToggleMute,
                    onToggleCamera: widget.onSwitchToVideo,
                    onToggleSpeaker: widget.onToggleSpeaker,
                    onAddParticipant: widget.onAddParticipant,
                    onToggleCallType: widget.onSwitchToVideo,
                    onEndCall: widget.onEndCall,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
