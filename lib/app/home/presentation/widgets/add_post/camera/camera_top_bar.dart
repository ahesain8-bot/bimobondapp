import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.onClose,
    required this.durationLabel,
    required this.onDurationTap,
    required this.soundLabel,
    this.onSoundTap,
    this.showDuration = true,
    this.isLiveMode = false,
  });

  final VoidCallback onClose;
  final String durationLabel;
  final VoidCallback onDurationTap;
  final String soundLabel;
  final VoidCallback? onSoundTap;
  final bool showDuration;
  final bool isLiveMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(LucideIcons.x, color: Colors.white),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: isLiveMode ? null : onSoundTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLiveMode ? LucideIcons.type : LucideIcons.music,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          soundLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
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
          if (showDuration)
            TextButton(
              onPressed: onDurationTap,
              child: Text(
                durationLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
