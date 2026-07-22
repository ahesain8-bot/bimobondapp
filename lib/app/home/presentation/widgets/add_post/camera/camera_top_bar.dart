import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_tool_icons.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.onClose,
    required this.soundLabel,
    this.onSoundTap,
    this.onClearSound,
    this.onFlip,
    this.isLiveMode = false,
    this.addSoundLabel = 'Add sound',
    this.showSound = true,
  });

  final VoidCallback onClose;
  final String soundLabel;
  final VoidCallback? onSoundTap;
  final VoidCallback? onClearSound;
  final VoidCallback? onFlip;
  final bool isLiveMode;
  final String addSoundLabel;
  final bool showSound;

  @override
  Widget build(BuildContext context) {
    final displayLabel =
        soundLabel.trim().isEmpty ? addSoundLabel : soundLabel;
    final canClear = !isLiveMode && onClearSound != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Row(
        children: [
          _TopCircleButton(
            icon: LucideIcons.x,
            onTap: onClose,
          ),
          Expanded(
            child: showSound
                ? Center(
                    child: GestureDetector(
                      onTap: isLiveMode ? null : onSoundTap,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 240),
                        padding: EdgeInsetsDirectional.only(
                          start: 16,
                          end: canClear ? 10 : 16,
                          top: 10,
                          bottom: 10,
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
                              isLiveMode
                                  ? LucideIcons.type
                                  : LucideIcons.music2,
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
                            if (canClear) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onClearSound,
                                behavior: HitTestBehavior.opaque,
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(
                                    LucideIcons.x,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (onFlip != null)
            _TopCircleButton(
              icon: LucideIcons.switchCamera,
              onTap: onFlip!,
              customIcon: TikTokSideIcons.flip(size: 26),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({
    required this.icon,
    required this.onTap,
    this.customIcon,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Widget? customIcon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: customIcon ?? Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
