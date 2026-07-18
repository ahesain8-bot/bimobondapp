import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

String formatSoundDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
}

String formatSoundUseCount(int count, AppLocalizations l10n) {
  if (count >= 1000000) {
    return l10n.soundUseCountMillions((count / 1000000).toStringAsFixed(1));
  }
  if (count >= 1000) {
    return l10n.soundUseCountThousands((count / 1000).toStringAsFixed(1));
  }
  return l10n.soundUseCount(count);
}

class SoundListTile extends StatefulWidget {
  const SoundListTile({
    super.key,
    required this.sound,
    required this.isSelected,
    required this.onTap,
    this.onUseTap,
    this.showUseButton = false,
  });

  final SoundEntity sound;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onUseTap;
  final bool showUseButton;

  @override
  State<SoundListTile> createState() => _SoundListTileState();
}

class _SoundListTileState extends State<SoundListTile> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _syncPlayingState();
  }

  void _syncPlayingState() {
    _isPlaying = SoundAudioPreview.isPlaying(widget.sound.id);
  }

  Future<void> _togglePreview() async {
    await SoundAudioPreview.toggle(
      widget.sound.id,
      widget.sound.resolvedAudioUrl,
    );
    if (!mounted) return;
    setState(_syncPlayingState);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sound = widget.sound;

    return Material(
      color: widget.isSelected
          ? colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: AppSizes.p12,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _togglePreview,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.85),
                        colorScheme.secondary.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Icon(
                    _isPlaying ? LucideIcons.pause : LucideIcons.music,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sound.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sound.author} · ${formatSoundDuration(sound.duration)} · ${formatSoundUseCount(sound.useCount, l10n)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.showUseButton && widget.onUseTap != null)
                TextButton(
                  onPressed: widget.onUseTap,
                  child: Text(l10n.soundUseThis),
                )
              else if (widget.isSelected)
                Icon(LucideIcons.check, color: colorScheme.primary, size: 20)
              else
                Icon(
                  LucideIcons.chevronRight,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
