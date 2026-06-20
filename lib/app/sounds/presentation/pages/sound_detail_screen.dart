import 'dart:async';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_sound_detail_usecase.dart';
import 'package:bimobondapp/app/sounds/presentation/di/sounds_injector.dart' as sounds_di;
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_detail_widgets.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_list_tile.dart';
import 'package:bimobondapp/core/navigation/sound_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SoundDetailScreen extends StatefulWidget {
  const SoundDetailScreen({
    super.key,
    required this.soundId,
    this.pickMode = false,
    this.previewSound,
  });

  final String soundId;
  final bool pickMode;
  final SoundEntity? previewSound;

  @override
  State<SoundDetailScreen> createState() => _SoundDetailScreenState();
}

class _SoundDetailScreenState extends State<SoundDetailScreen>
    with SingleTickerProviderStateMixin {
  SoundDetailEntity? _detail;
  bool _loading = true;
  String? _error;
  late final AnimationController _discController;

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    _discController.dispose();
    unawaited(SoundAudioPreview.stop());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sounds_di.sl<GetSoundDetailUseCase>()(
      GetSoundDetailParams(soundId: widget.soundId),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (detail) async {
        setState(() {
          _loading = false;
          _detail = detail;
        });
        await _startPreview(detail.sound);
      },
    );
  }

  Future<void> _startPreview(SoundEntity sound) async {
    await SoundAudioPreview.toggle(sound.id, sound.resolvedAudioUrl);
    if (!mounted) return;
    if (SoundAudioPreview.isPlaying(sound.id)) {
      unawaited(_discController.repeat());
    }
    setState(() {});
  }

  Future<void> _togglePreview(SoundEntity sound) async {
    final wasPlaying = SoundAudioPreview.isPlaying(sound.id);
    await SoundAudioPreview.toggle(sound.id, sound.resolvedAudioUrl);
    if (!mounted) return;
    if (wasPlaying) {
      _discController.stop();
    } else {
      unawaited(_discController.repeat());
    }
    setState(() {});
  }

  void _useSound(SoundEntity sound) {
    if (widget.pickMode) {
      popSoundDetail(context, sound);
      return;
    }
    popSoundDetail(context);
    context.pushNamed(
      'add_post_camera',
      extra: {'initialSound': sound},
    );
  }

  SoundEntity? get _displaySound => _detail?.sound ?? widget.previewSound;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: _loading && _detail == null
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _error != null && _detail == null
                  ? _buildError(l10n)
                  : _buildBody(l10n),
            ),
            if (_displaySound != null && (_detail != null || !widget.pickMode))
              _buildBottomBar(l10n, _displaySound!),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => popSoundDetail(context),
            icon: const DirectionalBackIcon(color: Colors.white, size: 24),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: AppSizes.p16),
            FilledButton(onPressed: _load, child: Text(l10n.notificationsRetry)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final detail = _detail;
    final sound = _displaySound;
    if (sound == null) return const SizedBox.shrink();

    final isPlaying = SoundAudioPreview.isPlaying(sound.id);

    final originalSound = detail?.originalSound;

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: Colors.grey.shade900,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: SoundSpinningDisc(
              rotation: _discController,
              size: 128,
              coverUrl: sound.resolvedCoverUrl,
              isPlaying: isPlaying,
              onTap: () => _togglePreview(sound),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            sound.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sound.author,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatSoundDuration(sound.duration)} · ${formatSoundUseCount(sound.useCount, l10n)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
          if (originalSound != null) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => openSoundDetail(
                  context,
                  soundId: originalSound.id,
                  pickMode: widget.pickMode,
                  preview: originalSound,
                ),
                icon: const Icon(LucideIcons.link2, size: 16, color: Colors.white70),
                label: Text(
                  l10n.soundOriginalLink(originalSound.name),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            l10n.soundVideosUsing,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (detail == null || detail.posts.isEmpty)
            Text(
              l10n.soundNoVideosYet,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            )
          else
            SoundDetailVideoGrid(posts: detail.posts),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n, SoundEntity sound) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: FilledButton(
        onPressed: () => _useSound(sound),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        child: Text(
          l10n.soundUseThisSound,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
