import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_sound_detail_usecase.dart';
import 'package:bimobondapp/app/sounds/presentation/di/sounds_injector.dart'
    as sounds_di;
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_local_catalog_store.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_detail_widgets.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_theme.dart';
import 'package:bimobondapp/core/navigation/sound_navigation.dart';
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class SoundDetailScreen extends StatefulWidget {
  const SoundDetailScreen({
    super.key,
    required this.soundId,
    this.pickMode = false,
    this.previewSound,
    this.preferredSegmentId,
  });

  final String soundId;
  final bool pickMode;
  final SoundEntity? previewSound;

  /// When opened from a post that already has a clip, reuse that segment (Mode A).
  final String? preferredSegmentId;

  @override
  State<SoundDetailScreen> createState() => _SoundDetailScreenState();
}

class _SoundDetailScreenState extends State<SoundDetailScreen> {
  SoundDetailEntity? _detail;
  bool _loading = true;
  String? _error;
  bool _isSaved = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_load());
    unawaited(_loadSaved());
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    unawaited(SoundAudioPreview.stop());
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim().toLowerCase();
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
  }

  Future<void> _loadSaved() async {
    final saved = await SoundLocalCatalogStore.isFavorite(widget.soundId);
    if (!mounted) return;
    setState(() => _isSaved = saved);
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
        await _loadSaved();
      },
    );
  }

  Future<void> _startPreview(SoundEntity sound) async {
    await SoundAudioPreview.toggle(sound.id, sound.resolvedAudioUrl);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _togglePreview(SoundEntity sound) async {
    await SoundAudioPreview.toggle(sound.id, sound.resolvedAudioUrl);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleSave(SoundEntity sound) async {
    final saved = await SoundLocalCatalogStore.toggleFavorite(sound);
    if (!mounted) return;
    setState(() => _isSaved = saved);
  }

  Future<void> _share(SoundEntity sound) async {
    final l10n = AppLocalizations.of(context)!;
    await SharePlus.instance.share(
      ShareParams(
        text: '${sound.name} · ${sound.author}\n${l10n.soundUseThisSound}',
      ),
    );
  }

  void _useSound(SoundEntity sound) {
    if (widget.pickMode) {
      popSoundDetail(context, sound);
      return;
    }
    final segmentId = widget.preferredSegmentId?.trim();
    popSoundDetail(context);
    context.pushNamed(
      'add_post_camera',
      extra: {
        'initialSound': sound,
        if (segmentId != null && segmentId.isNotEmpty)
          'initialSoundSegmentId': segmentId,
      },
    );
  }

  void _addToStory(SoundEntity sound) {
    if (widget.pickMode) {
      popSoundDetail(context, sound);
      return;
    }
    final segmentId = widget.preferredSegmentId?.trim();
    popSoundDetail(context);
    context.pushNamed(
      'add_post_camera',
      extra: {
        'initialSound': sound,
        'isStory': true,
        if (segmentId != null && segmentId.isNotEmpty)
          'initialSoundSegmentId': segmentId,
      },
    );
  }

  void _openCreator(SoundEntity sound) {
    final creator = sound.creator;
    if (creator == null || creator.id.trim().isEmpty) return;
    unawaited(
      openUserProfile(
        context,
        userId: creator.id,
        username: creator.username,
        fullName: creator.fullName,
        avatarUrl: creator.avatarUrl,
      ),
    );
  }

  SoundEntity? get _displaySound => _detail?.sound ?? widget.previewSound;

  List<SoundPostPreviewEntity> get _filteredPosts {
    final posts = _detail?.posts ?? const <SoundPostPreviewEntity>[];
    if (_searchQuery.isEmpty) return posts;
    return posts
        .where((p) => (p.username ?? '').toLowerCase().contains(_searchQuery))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return SoundPickerTheme(
      child: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          final scheme = Theme.of(context).colorScheme;
          final sound = _displaySound;
          final authState = context.watch<AuthBloc>().state;
          final myAvatar = authState is AuthSuccess
              ? authState.user.avatarUrl
              : null;

          return Scaffold(
            backgroundColor: scheme.surface,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SoundDetailTopBar(
                    searchController: _searchController,
                    onBack: () => popSoundDetail(context),
                    onShare: sound == null
                        ? () {}
                        : () => unawaited(_share(sound)),
                  ),
                  Expanded(
                    child: _loading && _detail == null
                        ? const Center(child: CustomLoadingWidget(size: 40))
                        : _error != null && _detail == null
                            ? _buildError(l10n, scheme)
                            : _buildBody(l10n, scheme),
                  ),
                  if (sound != null)
                    SoundDetailBottomBar(
                      avatarUrl: myAvatar,
                      onAddToStory: () => _addToStory(sound),
                      onUseSound: () => _useSound(sound),
                      useLabel: widget.pickMode
                          ? l10n.soundUseThis
                          : l10n.soundUseSoundCta,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: AppSizes.p16),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: Text(l10n.notificationsRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ColorScheme scheme) {
    final sound = _displaySound;
    if (sound == null) return const SizedBox.shrink();

    final isPlaying = SoundAudioPreview.isPlaying(sound.id);
    final posts = _filteredPosts;

    return RefreshIndicator(
      color: scheme.primary,
      backgroundColor: scheme.surface,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SoundDetailMetaSection(
              sound: sound,
              isPlaying: isPlaying,
              isSaved: _isSaved,
              onTogglePreview: () => unawaited(_togglePreview(sound)),
              onToggleSave: () => unawaited(_toggleSave(sound)),
              onCreatorTap: sound.creator?.id.trim().isNotEmpty == true
                  ? () => _openCreator(sound)
                  : null,
            ),
          ),
          if (_detail == null || posts.isEmpty)
            const SliverToBoxAdapter(child: SoundDetailEmptyPosts())
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 8),
              sliver: SliverToBoxAdapter(
                child: SoundDetailVideoGrid(
                  posts: posts,
                  showOriginalOnFirst: sound.isOriginal && _searchQuery.isEmpty,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
