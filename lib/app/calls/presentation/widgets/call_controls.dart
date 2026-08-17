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

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final labelUnmute = isArabic ? 'إلغاء الكتم' : 'Unmute';
    final labelMute = isArabic ? 'كتم' : 'Mute';
    final labelCamOff = isArabic ? 'إيقاف' : 'Cam Off';
    final labelCamOn = isArabic ? 'تشغيل' : 'Cam On';
    final labelFlip = isArabic ? 'قلب' : 'Flip';
    final labelSpeaker = isArabic ? 'مكبر الصوت' : 'Speaker';
    final labelNormalSound = isArabic ? 'صوت عادي' : 'Normal';
    final labelCloseSound = isArabic ? 'إغلاق الصوت' : 'Sound Off';
    final labelToAudio = isArabic ? 'صوتي' : 'To Audio';
    final labelToVideo = isArabic ? 'فيديو' : 'To Video';
    final labelAdd = isArabic ? 'إضافة' : 'Add';
    final labelEnd = isArabic ? 'إنهاء' : 'End';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkTheme
            ? const Color(0xFF1E293B).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDarkTheme
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.06),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
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
              label: isMuted ? labelUnmute : labelMute,
              isActive: isMuted,
              activeBgColor: const Color(0xFFEF4444),
              isDarkTheme: isDarkTheme,
              onTap: onToggleMute,
            ),
            const SizedBox(width: 12),

            // Camera On / Off (Only for Video Calls)
            if (isVideoCall) ...[
              _AnimatedControlButton(
                icon: isCameraOff ? LucideIcons.videoOff : LucideIcons.video,
                label: isCameraOff ? labelCamOff : labelCamOn,
                isActive: isCameraOff,
                activeBgColor: const Color(0xFFEF4444),
                isDarkTheme: isDarkTheme,
                onTap: onToggleCamera,
              ),
              const SizedBox(width: 12),
            ],

            // Switch Camera (Front/Back)
            if (isVideoCall && !isCameraOff && onSwitchCamera != null) ...[
              _AnimatedControlButton(
                icon: LucideIcons.switchCamera,
                label: labelFlip,
                isDarkTheme: isDarkTheme,
                onTap: onSwitchCamera!,
              ),
              const SizedBox(width: 12),
            ],

            // Speakerphone / Sound Toggle
            _AnimatedControlButton(
              icon: isSpeakerOn
                  ? LucideIcons.volume2
                  : (isVideoCall ? LucideIcons.volumeX : LucideIcons.volume1),
              label: isSpeakerOn
                  ? labelSpeaker
                  : (isVideoCall ? labelCloseSound : labelNormalSound),
              isActive: isVideoCall ? !isSpeakerOn : isSpeakerOn,
              activeBgColor: isVideoCall
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF6366F1),
              isDarkTheme: isDarkTheme,
              onTap: onToggleSpeaker,
            ),
            const SizedBox(width: 12),

            // Switch between Voice / Video (Only for Video Calls)
            if (isVideoCall && onToggleCallType != null) ...[
              _AnimatedControlButton(
                icon: isVideoCall ? LucideIcons.phone : LucideIcons.video,
                label: isVideoCall ? labelToAudio : labelToVideo,
                isDarkTheme: isDarkTheme,
                onTap: onToggleCallType!,
              ),
              const SizedBox(width: 12),
            ],

            // Add Participant
            if (onAddParticipant != null) ...[
              _AnimatedControlButton(
                icon: LucideIcons.userPlus,
                label: labelAdd,
                isDarkTheme: isDarkTheme,
                onTap: onAddParticipant!,
              ),
              const SizedBox(width: 12),
            ],

            // Visually Prominent End Call Button
            _AnimatedControlButton(
              icon: LucideIcons.phone,
              label: labelEnd,
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
      bgColor = widget.isDarkTheme
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.black.withValues(alpha: 0.06);
      iconColor = widget.isDarkTheme ? Colors.white : Colors.black87;
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
