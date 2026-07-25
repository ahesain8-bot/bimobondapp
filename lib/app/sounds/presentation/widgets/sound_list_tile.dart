import 'dart:async';
import 'dart:math' as math;

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
  Timer? _playPoll;

  @override
  void initState() {
    super.initState();
    _syncPlayingState();
    _updatePlayPolling();
  }

  @override
  void didUpdateWidget(covariant SoundListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sound.id != widget.sound.id ||
        oldWidget.isSelected != widget.isSelected) {
      _syncPlayingState();
      _updatePlayPolling();
    }
  }

  @override
  void dispose() {
    _playPoll?.cancel();
    super.dispose();
  }

  void _syncPlayingState() {
    _isPlaying = SoundAudioPreview.isPlaying(widget.sound.id);
  }

  void _updatePlayPolling() {
    _playPoll?.cancel();
    _playPoll = null;
    if (!widget.isSelected) return;
    _playPoll = Timer.periodic(const Duration(milliseconds: 280), (_) {
      if (!mounted) return;
      final playing = SoundAudioPreview.isPlaying(widget.sound.id);
      if (playing != _isPlaying) {
        setState(() => _isPlaying = playing);
      }
    });
  }

  Future<void> _togglePreview() async {
    final id = widget.sound.id;
    final wasPlaying = SoundAudioPreview.isPlaying(id);
    await SoundAudioPreview.stop();
    if (!wasPlaying) {
      await SoundAudioPreview.playAt(id, widget.sound.resolvedAudioUrl);
    }
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
    final accent = SoundPickerTheme.accentOf(context);
    final posts = sound.postCount ?? sound.useCount;
    final cover = _coverUrl;
    final placeholderBg = scheme.surfaceContainerHighest;
    final silhouetteBg = Color.alphaBlend(
      onSurface.withValues(alpha: 0.12),
      placeholderBg,
    );
    final showBars = selected || _isPlaying;

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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: ColoredBox(
                      color: placeholderBg,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (cover != null && cover.isNotEmpty)
                            SafeNetworkImage(
                              imageUrl: cover,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(26),
                            )
                          else
                            ColoredBox(
                              color: silhouetteBg,
                              child: Icon(
                                LucideIcons.music2,
                                color: scheme.onSurface.withValues(alpha: 0.35),
                                size: 22,
                              ),
                            ),
                          if (_isPlaying)
                            ColoredBox(
                              color: onSurface.withValues(alpha: 0.35),
                              child: Icon(
                                LucideIcons.pause,
                                color: scheme.surface,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showBars) ...[
                          _TikTokMusicBars(
                            active: _isPlaying,
                            color: accent,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            sound.name,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: selected ? accent : onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${sound.author} · ${formatSoundUseCount(posts, l10n)} · ${formatSoundDuration(sound.duration)}',
                      style: TextStyle(
                        fontSize: 11.5,
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
                    size: 20,
                    color: onSurface.withValues(alpha: 0.87),
                  ),
                ),
                IconButton(
                  onPressed: widget.onFavoriteTap,
                  tooltip: l10n.soundFavoriteTooltip,
                  icon: Icon(
                    widget.isFavorite ? Icons.bookmark : LucideIcons.bookmark,
                    size: 20,
                    color: widget.isFavorite
                        ? accent
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

/// Small equalizer bars beside the title (TikTok-style).
class _TikTokMusicBars extends StatefulWidget {
  const _TikTokMusicBars({
    required this.active,
    required this.color,
  });

  final bool active;
  final Color color;

  @override
  State<_TikTokMusicBars> createState() => _TikTokMusicBarsState();
}

class _TikTokMusicBarsState extends State<_TikTokMusicBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _heights = <double>[0.45, 1.0, 0.65, 0.85];
  static const _phases = <double>[0.0, 0.35, 0.7, 0.15];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _TikTokMusicBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.35;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) {
              final wave = widget.active
                  ? (math.sin(
                          (_controller.value * 2 * math.pi) +
                              (_phases[i] * 2 * math.pi),
                        ) +
                        1) /
                      2
                  : 0.35;
              final h = (4.0 + (_heights[i] * 10.0 * wave)).clamp(3.0, 14.0);
              return Container(
                width: 2,
                height: h,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
