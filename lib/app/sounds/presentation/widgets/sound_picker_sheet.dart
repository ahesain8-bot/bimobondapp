import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_my_sounds_usecase.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_sound_groups_usecase.dart';
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
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

enum _PickerShelf { group, hot, forYou, mine, favorites, recent }

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

    final picked = await GlassBottomSheet.open<SoundPickResult?>(
      context,
      isScrollControlled: true,
      builder: (ctx) => SoundPickerTheme(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
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
    if (picked.cleared) {
      await SoundAudioPreview.stop();
      return picked;
    }
    final sound = picked.sound;
    if (sound == null) {
      await SoundAudioPreview.stop();
      return null;
    }
    if (!picked.needsTrim) {
      await SoundAudioPreview.stop();
      return picked;
    }

    await _waitForModalSettle(context);
    if (!context.mounted) {
      await SoundAudioPreview.stop();
      return null;
    }

    final restorePeriod = initialSelection?.id == sound.id;
    final trim = await SoundTrimSheet.show(
      context,
      sound: sound,
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
      return SoundPickResult(
        sound: sound,
        offset: restorePeriod ? initialOffset : Duration.zero,
        window: restorePeriod
            ? (initialWindow ?? const Duration(seconds: 15))
            : const Duration(seconds: 15),
        soundSegmentId: sound.defaultSegment?.id,
      );
    }

    await SoundLocalCatalogStore.pushRecent(sound);
    return SoundPickResult(
      sound: sound,
      offset: trim.offset,
      window: trim.window,
      muteOriginal: trim.muteOriginal,
      didTrim: true,
    );
  }

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
    with TickerProviderStateMixin {
  static const _debounce = Duration(milliseconds: 350);

  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<SoundGroupEntity> _groups = [];
  List<_PickerShelf> _shelves = const [
    _PickerShelf.hot,
    _PickerShelf.forYou,
    _PickerShelf.mine,
    _PickerShelf.favorites,
    _PickerShelf.recent,
  ];
  List<String> _tabLabels = const [];

  final Map<String, List<SoundEntity>> _groupSounds = {};
  List<SoundEntity> _hot = [];
  List<SoundEntity> _forYou = [];
  List<SoundEntity> _mine = [];
  List<SoundEntity> _favorites = [];
  List<SoundEntity> _recent = [];
  final Set<String> _favoriteIds = {};

  bool _bootstrapping = true;
  bool _loadingRemote = false;
  bool _loadingLocal = true;
  bool _uploading = false;
  bool _showSearch = false;

  SoundEntity? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    unawaited(SoundAudioPreview.stop());
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController?.indexIsChanging == true) return;
    setState(() {});
    unawaited(_ensureCurrentShelfLoaded());
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      unawaited(_reloadSearchableShelf());
    });
  }

  Future<void> _bootstrap() async {
    final l10n = AppLocalizations.of(context)!;
    final groupsResult = await sounds_di.sl<GetSoundGroupsUseCase>()(
      NoParams(),
    );

    List<SoundGroupEntity> groups = const [];
    groupsResult.fold((_) {}, (g) => groups = g);

    final shelves = <_PickerShelf>[];
    final labels = <String>[];

    if (groups.isNotEmpty) {
      _groups = groups;
      for (final g in groups) {
        shelves.add(_PickerShelf.group);
        labels.add(g.name);
        _groupSounds[g.id] = List<SoundEntity>.from(g.sounds);
      }
    } else {
      shelves.addAll(const [_PickerShelf.hot, _PickerShelf.forYou]);
      labels.addAll([l10n.soundTabHot, l10n.soundTabForYou]);
    }

    shelves.addAll(const [
      _PickerShelf.mine,
      _PickerShelf.favorites,
      _PickerShelf.recent,
    ]);
    labels.addAll([
      l10n.soundTabMine,
      l10n.soundTabFavorites,
      l10n.soundTabRecent,
    ]);

    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _tabController = TabController(length: shelves.length, vsync: this);
    _tabController!.addListener(_onTabChanged);

    if (!mounted) return;
    setState(() {
      _shelves = shelves;
      _tabLabels = labels;
      _bootstrapping = false;
    });

    unawaited(_loadLocalTabs());
    unawaited(_ensureCurrentShelfLoaded());
  }

  _PickerShelf get _currentShelf {
    final i = _tabController?.index ?? 0;
    if (i < 0 || i >= _shelves.length) return _PickerShelf.hot;
    return _shelves[i];
  }

  String? get _currentGroupId {
    if (_currentShelf != _PickerShelf.group) return null;
    final i = _tabController?.index ?? 0;
    if (i < 0 || i >= _groups.length) return null;
    return _groups[i].id;
  }

  Future<void> _ensureCurrentShelfLoaded() async {
    switch (_currentShelf) {
      case _PickerShelf.group:
        final id = _currentGroupId;
        if (id == null) return;
        final cached = _groupSounds[id];
        if (cached != null && cached.isNotEmpty && !_showSearch) return;
        await _loadGroup(id);
      case _PickerShelf.hot:
        if (_hot.isEmpty) await _loadHot();
      case _PickerShelf.forYou:
        await _loadForYou();
      case _PickerShelf.mine:
        await _loadMine();
      case _PickerShelf.favorites:
      case _PickerShelf.recent:
        break;
    }
  }

  Future<void> _reloadSearchableShelf() async {
    switch (_currentShelf) {
      case _PickerShelf.group:
        final id = _currentGroupId;
        if (id != null) await _loadGroup(id);
      case _PickerShelf.forYou:
        await _loadForYou();
      case _PickerShelf.mine:
        await _loadMine();
      case _PickerShelf.hot:
        if (_showSearch && _searchController.text.trim().isNotEmpty) {
          await _loadForYou();
        }
      case _PickerShelf.favorites:
      case _PickerShelf.recent:
        break;
    }
  }

  Future<void> _loadHot() async {
    setState(() {
      _loadingRemote = true;
      _error = null;
    });
    final result = await sounds_di.sl<GetTrendingSoundsUseCase>()(
      const GetTrendingSoundsParams(limit: 40),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loadingRemote = false;
        _error = failure.message;
      }),
      (sounds) => setState(() {
        _loadingRemote = false;
        _hot = sounds;
      }),
    );
  }

  Future<void> _loadForYou() async {
    setState(() {
      _loadingRemote = true;
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
        _loadingRemote = false;
        _error = failure.message;
      }),
      (page) => setState(() {
        _loadingRemote = false;
        _forYou = page.sounds;
      }),
    );
  }

  Future<void> _loadGroup(String groupId) async {
    setState(() {
      _loadingRemote = true;
      _error = null;
    });
    final query = _searchController.text.trim();
    final result = await sounds_di.sl<GetSoundsUseCase>()(
      GetSoundsParams(
        page: 1,
        limit: 40,
        search: query.isEmpty ? null : query,
        sort: SoundSort.trending,
        groupId: groupId,
      ),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loadingRemote = false;
        _error = failure.message;
      }),
      (page) => setState(() {
        _loadingRemote = false;
        _groupSounds[groupId] = page.sounds;
      }),
    );
  }

  Future<void> _loadMine() async {
    setState(() {
      _loadingRemote = true;
      _error = null;
    });
    final query = _searchController.text.trim();
    final result = await sounds_di.sl<GetMySoundsUseCase>()(
      GetMySoundsParams(
        page: 1,
        limit: 40,
        search: query.isEmpty ? null : query,
        sort: SoundSort.recent,
      ),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loadingRemote = false;
        _error = failure.message;
      }),
      (page) => setState(() {
        _loadingRemote = false;
        _mine = page.sounds;
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
      await SoundAudioPreview.stop();
      if (!mounted) return;
      Navigator.of(context).pop(SoundPickResult(sound: sound, needsTrim: true));
      return;
    }

    setState(() => _selected = sound);
    unawaited(SoundAudioPreview.toggle(sound.id, sound.resolvedAudioUrl));
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
        soundSegmentId: (!didTrim && offset == Duration.zero)
            ? sound.defaultSegment?.id
            : null,
      ),
    );
  }

  Future<void> _openTrim(SoundEntity sound) async {
    await SoundAudioPreview.stop();
    if (!mounted) return;
    Navigator.of(context).pop(SoundPickResult(sound: sound, needsTrim: true));
  }

  Future<void> _clearSelection() async {
    await SoundAudioPreview.stop();
    if (!mounted) return;
    Navigator.of(context).pop(const SoundPickResult.cleared());
  }

  Future<void> _toggleFavorite(SoundEntity sound) async {
    final favorited = await SoundLocalCatalogStore.toggleFavorite(sound);
    if (!mounted) return;
    setState(() {
      if (favorited) {
        _favoriteIds.add(sound.id);
        _favorites = [sound, ..._favorites.where((s) => s.id != sound.id)];
      } else {
        _favoriteIds.remove(sound.id);
        _favorites = _favorites.where((s) => s.id != sound.id).toList();
      }
    });
  }

  List<SoundEntity> _currentList() {
    switch (_currentShelf) {
      case _PickerShelf.group:
        final id = _currentGroupId;
        return id == null ? const [] : (_groupSounds[id] ?? const []);
      case _PickerShelf.hot:
        return _hot;
      case _PickerShelf.forYou:
        return _forYou;
      case _PickerShelf.mine:
        return _mine;
      case _PickerShelf.favorites:
        return _favorites;
      case _PickerShelf.recent:
        return _recent;
    }
  }

  bool _currentLoading() {
    if (_bootstrapping) return true;
    switch (_currentShelf) {
      case _PickerShelf.favorites:
      case _PickerShelf.recent:
        return _loadingLocal;
      case _PickerShelf.group:
      case _PickerShelf.hot:
      case _PickerShelf.forYou:
      case _PickerShelf.mine:
        return _loadingRemote;
    }
  }

  Future<void> _retryCurrent() async {
    switch (_currentShelf) {
      case _PickerShelf.group:
        final id = _currentGroupId;
        if (id != null) await _loadGroup(id);
      case _PickerShelf.hot:
        await _loadHot();
      case _PickerShelf.forYou:
        await _loadForYou();
      case _PickerShelf.mine:
        await _loadMine();
      case _PickerShelf.favorites:
      case _PickerShelf.recent:
        await _loadLocalTabs();
    }
  }

  bool get _showRemoteError {
    return switch (_currentShelf) {
      _PickerShelf.favorites || _PickerShelf.recent => false,
      _ => true,
    };
  }

  int? get _searchTabIndex {
    final forYou = _shelves.indexOf(_PickerShelf.forYou);
    if (forYou >= 0) return forYou;
    final firstGroup = _shelves.indexOf(_PickerShelf.group);
    if (firstGroup >= 0) return firstGroup;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    final canRemove = widget.initialSelection != null;
    final controller = _tabController;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: scheme.surface,
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller != null)
                SoundPickerHeader(
                  tabController: controller,
                  tabLabels: _tabLabels,
                  showSearch: _showSearch,
                  searchController: _searchController,
                  uploading: _uploading,
                  onToggleSearch: () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      unawaited(_reloadSearchableShelf());
                    } else {
                      final idx = _searchTabIndex;
                      if (idx != null) controller.animateTo(idx);
                    }
                  }),
                  onPickFromDevice: () => unawaited(_pickFromDevice()),
                  onSearchSubmitted: () {
                    final idx = _searchTabIndex;
                    if (idx != null) controller.animateTo(idx);
                    unawaited(_reloadSearchableShelf());
                  },
                ),
              if (canRemove)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: OutlinedButton.icon(
                    onPressed: () => unawaited(_clearSelection()),
                    icon: Icon(
                      Icons.music_off_rounded,
                      size: 18,
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
                    label: Text(l10n.soundClearSelection),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onSurface,
                      side: BorderSide(
                        color: scheme.onSurface.withValues(alpha: 0.18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: SoundPickerList(
                  loading: _currentLoading(),
                  sounds: _currentList(),
                  selectedId: _selected?.id,
                  favoriteIds: _favoriteIds,
                  error: _error,
                  showError: _showRemoteError,
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
