import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CallControls extends StatelessWidget {
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final bool isVideoCall;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback? onSwitchCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback? onAddParticipant;
  final VoidCallback? onToggleCallType;
  final VoidCallback onEndCall;
  final bool isDark;

  const CallControls({
    super.key,
    required this.isMuted,
    required this.isCameraOff,
    required this.isSpeakerOn,
    required this.isVideoCall,
    required this.onToggleMute,
    required this.onToggleCamera,
    this.onSwitchCamera,
    required this.onToggleSpeaker,
    this.onAddParticipant,
    this.onToggleCallType,
    required this.onEndCall,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = isDark || Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(36),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mic Mute / Unmute
            _AnimatedControlButton(
              icon: isMuted ? LucideIcons.micOff : LucideIcons.mic,
              label: isMuted ? 'Unmute' : 'Mute',
              isActive: isMuted,
              activeBgColor: const Color(0xFFEF4444),
              isDarkTheme: isDarkTheme,
              onTap: onToggleMute,
            ),
            const SizedBox(width: 12),

            // Camera On / Off
            _AnimatedControlButton(
              icon: isCameraOff ? LucideIcons.videoOff : LucideIcons.video,
              label: isCameraOff ? 'Cam Off' : 'Cam On',
              isActive: isCameraOff,
              activeBgColor: const Color(0xFFEF4444),
              isDarkTheme: isDarkTheme,
              onTap: onToggleCamera,
            ),
            const SizedBox(width: 12),

            // Switch Camera (Front/Back)
            if (isVideoCall && !isCameraOff && onSwitchCamera != null) ...[
              _AnimatedControlButton(
                icon: LucideIcons.switchCamera,
                label: 'Flip',
                isDarkTheme: isDarkTheme,
                onTap: onSwitchCamera!,
              ),
              const SizedBox(width: 12),
            ],

            // Speakerphone Toggle
            _AnimatedControlButton(
              icon: isSpeakerOn ? LucideIcons.volume2 : LucideIcons.volumeX,
              label: isSpeakerOn ? 'Speaker' : 'Earpiece',
              isActive: !isSpeakerOn,
              activeBgColor: Colors.blueGrey,
              isDarkTheme: isDarkTheme,
              onTap: onToggleSpeaker,
            ),
            const SizedBox(width: 12),

            // Switch between Voice / Video
            if (onToggleCallType != null) ...[
              _AnimatedControlButton(
                icon: isVideoCall ? LucideIcons.phone : LucideIcons.video,
                label: isVideoCall ? 'To Audio' : 'To Video',
                isDarkTheme: isDarkTheme,
                onTap: onToggleCallType!,
              ),
              const SizedBox(width: 12),
            ],

            // Add Participant
            if (onAddParticipant != null) ...[
              _AnimatedControlButton(
                icon: LucideIcons.userPlus,
                label: 'Add',
                isDarkTheme: isDarkTheme,
                onTap: onAddParticipant!,
              ),
              const SizedBox(width: 12),
            ],

            // Visually Prominent End Call Button
            _AnimatedControlButton(
              icon: LucideIcons.phoneOff,
              label: 'End',
              isEndCall: true,
              isDarkTheme: isDarkTheme,
              onTap: onEndCall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color activeBgColor;
  final bool isEndCall;
  final bool isDarkTheme;

  const _AnimatedControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeBgColor = const Color(0xFFEF4444),
    this.isEndCall = false,
    required this.isDarkTheme,
  });

  @override
  State<_AnimatedControlButton> createState() => _AnimatedControlButtonState();
}

class _AnimatedControlButtonState extends State<_AnimatedControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.isEndCall ? 48.0 : 42.0;

    Color bgColor;
    Color iconColor;

    if (widget.isEndCall) {
      bgColor = const Color(0xFFEF4444);
      iconColor = Colors.white;
    } else if (widget.isActive) {
      bgColor = widget.activeBgColor;
      iconColor = Colors.white;
    } else {
      bgColor = Colors.white.withValues(alpha: 0.18);
      iconColor = Colors.white;
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            boxShadow: widget.isEndCall
                ? [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              widget.icon,
              color: iconColor,
              size: widget.isEndCall ? 22 : 20,
            ),
          ),
        ),
      ),
    );
  }
}
