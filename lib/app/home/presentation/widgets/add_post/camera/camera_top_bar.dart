import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_tool_icons.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style top bar: flip (physical left), sound pill (center), close (right).
class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.onFlip,
    required this.onClose,
    required this.soundLabel,
    this.onSoundTap,
    this.isLiveMode = false,
    this.addSoundLabel = 'Add sound',
  });

  final VoidCallback onFlip;
  final VoidCallback onClose;
  final String soundLabel;
  final VoidCallback? onSoundTap;
  final bool isLiveMode;
  final String addSoundLabel;

  @override
  Widget build(BuildContext context) {
    final displayLabel =
        soundLabel.trim().isEmpty ? addSoundLabel : soundLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          _TopCircleButton(
            icon: LucideIcons.switchCamera,
            onTap: onFlip,
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: isLiveMode ? null : onSoundTap,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLiveMode ? LucideIcons.type : LucideIcons.music2,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          displayLabel,
                          style: CameraToolIcons.labelStyle.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _TopCircleButton(
            icon: LucideIcons.x,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(4),
        decoration: CameraToolIcons.circleDecoration(),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
