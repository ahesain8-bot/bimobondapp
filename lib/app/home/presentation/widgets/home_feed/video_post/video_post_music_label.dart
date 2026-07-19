import 'package:bimobondapp/core/widgets/blurred_icon_badge.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VideoPostMusicLabel extends StatelessWidget {
  const VideoPostMusicLabel({
    required this.soundName,
    this.onTap,
    super.key,
  });

  final String? soundName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = soundName ?? l10n.cameraOriginalSound;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(right: 10, left: 10, bottom: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlurredIconBadge(
              icon: LucideIcons.music,
              diameter: 24,
              iconSize: 12,
              iconColor: Colors.white.withValues(alpha: 0.9),
              blurSigma: 10,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
