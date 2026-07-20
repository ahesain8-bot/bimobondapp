import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

String formatSoundDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatSoundUseCount(int count, AppLocalizations l10n) {
  if (count >= 1000000) {
    return l10n.soundPostsCountMillions((count / 1000000).toStringAsFixed(1));
  }
  if (count >= 1000) {
    return l10n.soundPostsCountThousands((count / 1000).toStringAsFixed(1));
  }
  return l10n.soundPostsCount(count);
}

class SoundListTile extends StatefulWidget {
  const SoundListTile({
    super.key,
    required this.sound,
    required this.isSelected,
    required this.onTap,
    this.onScissorsTap,
    this.onFavoriteTap,
    this.isFavorite = false,
    this.onUseTap,
    this.showUseButton = false,
  });

  final SoundEntity sound;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onScissorsTap;
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;
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

  @override
  void didUpdateWidget(covariant SoundListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sound.id != widget.sound.id ||
        oldWidget.isSelected != widget.isSelected) {
      _syncPlayingState();
    }
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

  String? get _coverUrl {
    final cover = widget.sound.resolvedCoverUrl;
    if (cover != null && cover.isNotEmpty) return cover;
    final avatar = widget.sound.creator?.avatarUrl?.trim();
    if (avatar == null || avatar.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(avatar);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final sound = widget.sound;
    final selected = widget.isSelected;
    final posts = sound.postCount ?? sound.useCount;
    final cover = _coverUrl;
    final placeholderBg = scheme.surfaceContainerHighest;
    final silhouetteBg = Color.alphaBlend(
      onSurface.withValues(alpha: 0.12),
      placeholderBg,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: 10,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _togglePreview,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? SoundPickerTheme.accentOf(context)
                          : Colors.transparent,
                      width: 2,
                    ),
                    color: placeholderBg,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (cover != null && cover.isNotEmpty)
                        SafeNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                        )
                      else
                        ColoredBox(
                          color: silhouetteBg,
                          child: Icon(
                            LucideIcons.user,
                            color: scheme.onSurface.withValues(alpha: 0.35),
                            size: 28,
                          ),
                        ),
                      if (_isPlaying)
                        ColoredBox(
                          color: onSurface.withValues(alpha: 0.35),
                          child: Icon(
                            LucideIcons.pause,
                            color: scheme.surface,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sound.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? SoundPickerTheme.accentOf(context)
                            : onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${sound.author} · ${formatSoundUseCount(posts, l10n)} · ${formatSoundDuration(sound.duration)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: onSurface.withValues(alpha: 0.45),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
              if (widget.showUseButton && widget.onUseTap != null)
                TextButton(
                  onPressed: widget.onUseTap,
                  child: Text(l10n.soundUseThis),
                )
              else if (selected) ...[
                IconButton(
                  onPressed: widget.onScissorsTap,
                  tooltip: l10n.soundTrimTooltip,
                  icon: Icon(
                    LucideIcons.scissors,
                    size: 22,
                    color: onSurface.withValues(alpha: 0.87),
                  ),
                ),
                IconButton(
                  onPressed: widget.onFavoriteTap,
                  tooltip: l10n.soundFavoriteTooltip,
                  icon: Icon(
                    widget.isFavorite ? Icons.bookmark : LucideIcons.bookmark,
                    size: 22,
                    color: widget.isFavorite
                        ? SoundPickerTheme.accentOf(context)
                        : onSurface.withValues(alpha: 0.87),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
