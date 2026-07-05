import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_my_sounds_usecase.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_sounds_usecase.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_trending_sounds_usecase.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/upload_sound_usecase.dart';
import 'package:bimobondapp/app/sounds/presentation/di/sounds_injector.dart' as sounds_di;
import 'package:bimobondapp/core/navigation/sound_navigation.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_duration_probe.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_list_tile.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SoundPickerSheet extends StatefulWidget {
  const SoundPickerSheet({
    super.key,
    this.initialSelection,
  });

  final SoundEntity? initialSelection;

  static Future<SoundEntity?> show(
    BuildContext context, {
    SoundEntity? initialSelection,
  }) async {
    await SoundAudioPreview.stop();
    if (!context.mounted) return null;
    return GlassBottomSheet.showContent<SoundEntity?>(
      context,
      isScrollControlled: true,
      adaptTheme: true,
      child: SoundPickerSheet(initialSelection: initialSelection),
    );
  }

  @override
  State<SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<SoundPickerSheet>
    with SingleTickerProviderStateMixin {
  static const _debounce = Duration(milliseconds: 350);

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<SoundEntity> _trending = [];
  List<SoundEntity> _browse = [];
  List<SoundEntity> _mine = [];

  bool _loadingTrending = true;
  bool _loadingBrowse = true;
  bool _loadingMine = true;
  bool _uploading = false;

  SoundEntity? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(_onSearchChanged);
    unawaited(_loadTrending());
    unawaited(_loadBrowse());
    unawaited(_loadMine());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    unawaited(SoundAudioPreview.stop());
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    setState(() {});
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (_tabController.index == 1) {
        unawaited(_loadBrowse());
      }
    });
  }

  Future<void> _loadTrending() async {
    setState(() {
      _loadingTrending = true;
      _error = null;
    });
    final result = await sounds_di.sl<GetTrendingSoundsUseCase>()(
      const GetTrendingSoundsParams(limit: 30),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loadingTrending = false;
        _error = failure.message;
      }),
      (sounds) => setState(() {
        _loadingTrending = false;
        _trending = sounds;
      }),
    );
  }

  Future<void> _loadBrowse() async {
    setState(() {
      _loadingBrowse = true;
      _error = null;
    });
    final query = _searchController.text.trim();
    final result = await sounds_di.sl<GetSoundsUseCase>()(
      GetSoundsParams(
        page: 1,
        limit: 30,
        search: query.isEmpty ? null : query,
        sort: SoundSort.trending,
      ),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loadingBrowse = false;
        _error = failure.message;
      }),
      (page) => setState(() {
        _loadingBrowse = false;
        _browse = page.sounds;
      }),
    );
  }

  Future<void> _loadMine() async {
    setState(() {
      _loadingMine = true;
      _error = null;
    });
    final result = await sounds_di.sl<GetMySoundsUseCase>()(
      const GetMySoundsParams(page: 1, limit: 30),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loadingMine = false;
        _error = failure.message;
      }),
      (page) => setState(() {
        _loadingMine = false;
        _mine = page.sounds;
      }),
    );
  }

  Future<void> _pickFromDevice() async {
    const audioGroup = XTypeGroup(
      label: 'audio',
      mimeTypes: <String>[
        'audio/mpeg',
        'audio/wav',
        'audio/aac',
        'audio/mp4',
        'audio/ogg',
        'audio/webm',
      ],
      extensions: <String>['mp3', 'wav', 'aac', 'm4a', 'ogg', 'webm'],
    );

    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[audioGroup]);
    if (file == null || !mounted) return;

    final path = file.path;
    if (path.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final audioFile = File(path);
      final duration = await SoundDurationProbe.probeSeconds(audioFile);
      final result = await sounds_di.sl<UploadSoundUseCase>()(
        UploadSoundParams(audio: audioFile, duration: duration),
      );
      if (!mounted) return;
      result.fold(
        (failure) {
          setState(() => _uploading = false);
          PopupDialogs.showErrorDialog(context, failure.message);
        },
        (sound) {
          setState(() {
            _uploading = false;
            _selected = sound;
            _mine = [sound, ..._mine];
          });
          Navigator.of(context).pop(sound);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      PopupDialogs.showErrorFrom(context, e);
    }
  }

  Future<void> _openSoundPage(SoundEntity sound) async {
    final picked = await openSoundDetail(
      context,
      soundId: sound.id,
      pickMode: true,
      preview: sound,
    );
    if (!mounted || picked == null) return;
    Navigator.of(context).pop(picked);
  }

  List<SoundEntity> _currentList() {
    return switch (_tabController.index) {
      0 => _trending,
      1 => _browse,
      _ => _mine,
    };
  }

  bool _currentLoading() {
    return switch (_tabController.index) {
      0 => _loadingTrending,
      1 => _loadingBrowse,
      _ => _loadingMine,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: maxHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.p16,
              AppSizes.p8,
              AppSizes.p8,
              AppSizes.p8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomText(
                    l10n.soundPickerTitle,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_selected != null)
                  TextButton(
                    onPressed: () => setState(() => _selected = null),
                    child: Text(l10n.soundClearSelection),
                  ),
                IconButton(
                  onPressed: _uploading ? null : _pickFromDevice,
                  tooltip: l10n.soundPickFromFiles,
                  icon: _uploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CustomLoadingWidget(size: 20),
                        )
                      : const Icon(LucideIcons.folderOpen),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.soundSearchHint,
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) {
                if (_tabController.index != 1) {
                  _tabController.animateTo(1);
                }
                unawaited(_loadBrowse());
              },
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.soundTabTrending),
              Tab(text: l10n.soundTabBrowse),
              Tab(text: l10n.soundTabMine),
            ],
          ),
          Expanded(
            child: _buildList(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AppLocalizations l10n) {
    if (_currentLoading()) {
      return const Center(child: CustomLoadingWidget());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: CustomText(
            _error!,
            variant: TextVariant.secondary,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sounds = _currentList();
    if (sounds.isEmpty) {
      return Center(
        child: CustomText(
          l10n.soundPickerEmpty,
          variant: TextVariant.secondary,
        ),
      );
    }

    return ListView.separated(
      itemCount: sounds.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 76,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
      ),
      itemBuilder: (context, index) {
        final sound = sounds[index];
        final isSelected = _selected?.id == sound.id;
        return SoundListTile(
          sound: sound,
          isSelected: isSelected,
          onTap: () => unawaited(_openSoundPage(sound)),
        );
      },
    );
  }
}
