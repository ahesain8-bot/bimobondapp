import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_sounds_usecase.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_trending_sounds_usecase.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/upload_sound_usecase.dart';
import 'package:bimobondapp/app/sounds/presentation/di/sounds_injector.dart'
    as sounds_di;
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_duration_probe.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_local_catalog_store.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_pick_result.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_header.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_list.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_theme.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_trim_sheet.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class SoundPickerSheet extends StatefulWidget {
  const SoundPickerSheet({
    super.key,
    this.initialSelection,
    this.allowMuteOnTrim = false,
  });

  final SoundEntity? initialSelection;
  final bool allowMuteOnTrim;

  static Future<SoundPickResult?> show(
    BuildContext context, {
    SoundEntity? initialSelection,
    Duration initialOffset = Duration.zero,
    Duration? initialWindow,
    bool allowMuteOnTrim = false,
  }) async {
    await SoundAudioPreview.stop();
    if (!context.mounted) return null;

    // Catalog sheet first. Trim opens AFTER it closes so the check action
    // is not nested inside another modal (which broke apply on post).
    final picked = await GlassBottomSheet.open<SoundPickResult?>(
      context,
      isScrollControlled: true,
      builder: (ctx) => SoundPickerTheme(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: GlassBottomSheetShell(
            lightSurface: true,
            expand: false,
            child: SoundPickerSheet(
              initialSelection: initialSelection,
              allowMuteOnTrim: allowMuteOnTrim,
            ),
          ),
        ),
      ),
    );

    if (picked == null || !context.mounted) {
      await SoundAudioPreview.stop();
      return null;
    }
    if (!picked.needsTrim) {
      await SoundAudioPreview.stop();
      return picked;
    }

    // Wait until the catalog route is fully gone — opening trim in the same
    // frame drops the first check result (Future completes with null).
    await _waitForModalSettle(context);
    if (!context.mounted) {
      await SoundAudioPreview.stop();
      return null;
    }

    // Re-open trim on the same sound restores the last saved period.
    final restorePeriod = initialSelection?.id == picked.sound.id;
    final trim = await SoundTrimSheet.show(
      context,
      sound: picked.sound,
      windowLength: restorePeriod
          ? (initialWindow ?? const Duration(seconds: 15))
          : const Duration(seconds: 15),
      initialOffset: restorePeriod ? initialOffset : Duration.zero,
      allowMute: allowMuteOnTrim,
      initialMute: picked.muteOriginal,
    );
    await SoundAudioPreview.stop();
    if (!context.mounted) return null;
    if (trim == null) {
      // Cancelled trim — keep prior period if we were re-editing it.
      return SoundPickResult(
        sound: picked.sound,
        offset: restorePeriod ? initialOffset : Duration.zero,
        window: restorePeriod
            ? (initialWindow ?? const Duration(seconds: 15))
            : const Duration(seconds: 15),
      );
    }

    await SoundLocalCatalogStore.pushRecent(picked.sound);
    return SoundPickResult(
      sound: picked.sound,
      offset: trim.offset,
      window: trim.window,
      muteOriginal: trim.muteOriginal,
      didTrim: true,
    );
  }

  /// Lets the previous modal finish popping before another is presented.
  static Future<void> _waitForModalSettle(BuildContext context) async {
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 120));
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

  List<SoundEntity> _hot = [];
  List<SoundEntity> _forYou = [];
  List<SoundEntity> _favorites = [];
  List<SoundEntity> _recent = [];
  final Set<String> _favoriteIds = {};

  bool _loadingHot = true;
  bool _loadingForYou = true;
  bool _loadingLocal = true;
  bool _uploading = false;
  bool _showSearch = false;

  SoundEntity? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(_onSearchChanged);
    unawaited(_loadHot());
    unawaited(_loadForYou());
    unawaited(_loadLocalTabs());
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
        unawaited(_loadForYou());
      }
    });
  }

  Future<void> _loadHot() async {
    setState(() {
      _loadingHot = true;
      _error = null;
    });
    final result = await sounds_di.sl<GetTrendingSoundsUseCase>()(
      const GetTrendingSoundsParams(limit: 40),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loadingHot = false;
        _error = failure.message;
      }),
      (sounds) => setState(() {
        _loadingHot = false;
        _hot = sounds;
      }),
    );
  }

  Future<void> _loadForYou() async {
    setState(() {
      _loadingForYou = true;
      _error = null;
    });
    final query = _searchController.text.trim();
    final result = await sounds_di.sl<GetSoundsUseCase>()(
      GetSoundsParams(
        page: 1,
        limit: 40,
        search: query.isEmpty ? null : query,
        sort: SoundSort.trending,
      ),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loadingForYou = false;
        _error = failure.message;
      }),
      (page) => setState(() {
        _loadingForYou = false;
        _forYou = page.sounds;
      }),
    );
  }

  Future<void> _loadLocalTabs() async {
    setState(() => _loadingLocal = true);
    final favorites = await SoundLocalCatalogStore.listFavorites();
    final recent = await SoundLocalCatalogStore.listRecent();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _recent = recent;
      _favoriteIds
        ..clear()
        ..addAll(favorites.map((s) => s.id));
      _loadingLocal = false;
    });
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
        (sound) async {
          setState(() {
            _uploading = false;
            _selected = sound;
          });
          await _confirm(sound);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      PopupDialogs.showErrorFrom(context, e);
    }
  }

  Future<void> _onSoundTap(SoundEntity sound) async {
    final alreadySelected = _selected?.id == sound.id;
    if (alreadySelected) {
      // Second tap → choose period; check applies sound and closes the sheet.
      await SoundAudioPreview.stop();
      if (!mounted) return;
      Navigator.of(context).pop(
        SoundPickResult(sound: sound, needsTrim: true),
      );
      return;
    }

    setState(() => _selected = sound);
    unawaited(
      SoundAudioPreview.toggle(sound.id, sound.resolvedAudioUrl),
    );
  }

  Future<void> _confirm(
    SoundEntity sound, {
    Duration offset = Duration.zero,
    bool muteOriginal = false,
    bool didTrim = false,
  }) async {
    await SoundAudioPreview.stop();
    await SoundLocalCatalogStore.pushRecent(sound);
    if (!mounted) return;
    Navigator.of(context).pop(
      SoundPickResult(
        sound: sound,
        offset: offset,
        muteOriginal: muteOriginal,
        didTrim: didTrim,
      ),
    );
  }

  /// Scissors: close catalog with [needsTrim]; [show] opens trim next.
  Future<void> _openTrim(SoundEntity sound) async {
    await SoundAudioPreview.stop();
    if (!mounted) return;
    Navigator.of(context).pop(
      SoundPickResult(sound: sound, needsTrim: true),
    );
  }

  Future<void> _toggleFavorite(SoundEntity sound) async {
    final favorited = await SoundLocalCatalogStore.toggleFavorite(sound);
    if (!mounted) return;
    setState(() {
      if (favorited) {
        _favoriteIds.add(sound.id);
        _favorites = [
          sound,
          ..._favorites.where((s) => s.id != sound.id),
        ];
      } else {
        _favoriteIds.remove(sound.id);
        _favorites = _favorites.where((s) => s.id != sound.id).toList();
      }
    });
  }

  List<SoundEntity> _currentList() {
    return switch (_tabController.index) {
      0 => _hot,
      1 => _forYou,
      2 => _favorites,
      _ => _recent,
    };
  }

  bool _currentLoading() {
    return switch (_tabController.index) {
      0 => _loadingHot,
      1 => _loadingForYou,
      _ => _loadingLocal,
    };
  }

  Future<void> _retryCurrent() async {
    switch (_tabController.index) {
      case 0:
        await _loadHot();
      case 1:
        await _loadForYou();
      default:
        await _loadLocalTabs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: scheme.surface,
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SoundPickerHeader(
                tabController: _tabController,
                showSearch: _showSearch,
                searchController: _searchController,
                uploading: _uploading,
                onToggleSearch: () => setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchController.clear();
                    unawaited(_loadForYou());
                  } else {
                    _tabController.animateTo(1);
                  }
                }),
                onPickFromDevice: () => unawaited(_pickFromDevice()),
                onSearchSubmitted: () {
                  _tabController.animateTo(1);
                  unawaited(_loadForYou());
                },
              ),
              Expanded(
                child: SoundPickerList(
                  loading: _currentLoading(),
                  sounds: _currentList(),
                  selectedId: _selected?.id,
                  favoriteIds: _favoriteIds,
                  error: _error,
                  showError: _tabController.index == 0 ||
                      _tabController.index == 1,
                  onRetry: () => unawaited(_retryCurrent()),
                  onSoundTap: (sound) => unawaited(_onSoundTap(sound)),
                  onScissorsTap: (sound) => unawaited(_openTrim(sound)),
                  onFavoriteTap: (sound) => unawaited(_toggleFavorite(sound)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
