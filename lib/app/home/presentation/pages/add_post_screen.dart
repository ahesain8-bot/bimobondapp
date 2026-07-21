import 'dart:io';

import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/domain/usecases/get_categories_usecase.dart';
import 'package:bimobondapp/app/categories/presentation/di/categories_injector.dart'
    as categories_di;
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_auction_fields.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_category_picker_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_cover_preview.dart';
import 'package:bimobondapp/app/home/presentation/pages/add_post_location_search_screen.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_media_widgets.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_privacy_picker_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_publish_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_setting_item.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_settings_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_tag_button.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_sheet.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_input.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_location_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/social/presentation/widgets/mention_composer_field.dart';
import 'package:bimobondapp/app/posts/presentation/widgets/hashtag_picker_sheet.dart';
import 'package:bimobondapp/app/social/presentation/widgets/mention_picker_sheet.dart';
import 'package:bimobondapp/core/constants/add_post_layout_constants.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_import_flow.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_media_picker_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_sheets.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/core/navigation/sound_navigation.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({
    super.key,
    this.initialFiles,
    this.initialType,
    this.isStory = false,
    this.initialSound,
    this.initialFilterName,
    this.initialFilterCategory,
    this.initialEffectSlug,
    this.initialBeautyEnabled = false,
  });

  final List<File>? initialFiles;
  final String? initialType;
  final bool isStory;
  final SoundEntity? initialSound;
  final String? initialFilterName;
  final String? initialFilterCategory;
  final String? initialEffectSlug;
  final bool initialBeautyEnabled;

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen>
    with FeedPlaybackBlocker {
  static const int _maxFiles = 5;

  late List<File> _selectedFiles;
  late String _type;

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _auctionItemNameController =
      TextEditingController();
  final TextEditingController _startingPriceController =
      TextEditingController();
  final TextEditingController _targetPriceController = TextEditingController();
  String _privacyStatus = 'PUBLIC';
  final List<CategoryEntity> _categories = [];
  CategoryEntity? _selectedCategory;
  bool _isLoadingCategories = false;
  bool _allowComments = true;
  bool _allowDuets = true;
  bool _allowStitch = true;
  bool _isAuction = false;
  late DateTime _auctionStartDate;
  late DateTime _auctionEndDate;
  SoundEntity? _selectedSound;
  Duration _soundStartOffset = Duration.zero;
  Duration _soundWindow = const Duration(seconds: 15);
  AddPostLocationSelection? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedFiles = widget.initialFiles ?? [];
    _type = widget.initialType ?? 'VIDEO';
    final now = DateTime.now();
    _auctionStartDate = now;
    _auctionEndDate = now.add(
      const Duration(days: AddPostLayoutConstants.defaultAuctionDurationDays),
    );
    _selectedSound = widget.initialSound;
    _loadCategories();
    if (widget.isStory &&
        (widget.initialFiles == null || widget.initialFiles!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openStoryCamera();
      });
    }
  }

  void _openStoryCamera() {
    context.pushReplacementNamed(
      'add_post_camera',
      extra: const {'isStory': true},
    );
  }

  void _retakeStory() => _openStoryCamera();

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    final result = await categories_di.sl<GetCategoriesUseCase>()(NoParams());
    if (!mounted) return;
    setState(() {
      _isLoadingCategories = false;
      result.fold((_) {}, (categories) {
        _categories
          ..clear()
          ..addAll(categories);
      });
    });
  }

  @override
  void dispose() {
    SoundAudioPreview.stop();
    _descriptionController.dispose();
    _auctionItemNameController.dispose();
    _startingPriceController.dispose();
    _targetPriceController.dispose();
    super.dispose();
  }

  void _updateType() {
    if (_selectedFiles.isEmpty) return;
    final hasVideo = _selectedFiles.any(addPostIsVideoFile);
    if (_selectedFiles.length > 1) {
      _type = hasVideo ? 'VIDEO' : 'CAROUSEL';
    } else {
      _type = hasVideo ? 'VIDEO' : 'IMAGE';
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      if (_selectedFiles.isNotEmpty) {
        _updateType();
      }
    });
  }

  Future<void> _editMediaAt(int index) async {
    if (widget.isStory || index < 0 || index >= _selectedFiles.length) return;

    final items = _selectedFiles
        .map(
          (file) => GalleryMediaItem(
            file: file,
            type: addPostIsVideoFile(file) ? 'VIDEO' : 'IMAGE',
          ),
        )
        .toList(growable: false);

    final edited = await MediaGalleryImportFlow.openBatchEditor(
      context,
      items: items,
      initialIndex: index,
      initialSound: _selectedSound,
      initialSoundOffset: _soundStartOffset,
    );
    if (!mounted || edited == null || edited.files.isEmpty) return;

    setState(() {
      _selectedFiles = edited.files;
      if (edited.sound != null) _selectedSound = edited.sound;
      _updateType();
    });
  }

  Future<void> _showMediaPickerOptions() {
    if (widget.isStory) {
      _openStoryCamera();
      return Future.value();
    }
    return AddPostMediaPickerSheet.show(
      context,
      onOpenCamera: _openAddPostCamera,
      onOpenGallery: _pickFromGallery,
    );
  }

  Future<void> _pickFromGallery() async {
    final remaining = _maxFilesLimit - _selectedFiles.length;
    if (remaining <= 0) {
      final l10n = AppLocalizations.of(context)!;
      PopupDialogs.showErrorDialog(
        context,
        l10n.fieldIsRequired('Maximum $_maxFilesLimit files allowed'),
      );
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    await CameraStudioSheets.pickFromLibrary(
      context,
      l10n: l10n,
      limit: remaining,
      chooseMediaType: true,
      onPicked: (items) async {
        if (!mounted) return;

        final edited = await MediaGalleryImportFlow.openBatchEditor(
          context,
          items: items,
          initialSound: _selectedSound,
        );
        if (!mounted || edited == null || edited.files.isEmpty) return;

        final toAdd = edited.files.take(remaining).toList();
        setState(() {
          _selectedFiles = [..._selectedFiles, ...toAdd];
          if (edited.sound != null) _selectedSound = edited.sound;
          _updateType();
        });
      },
    );
  }

  Future<void> _openAddPostCamera() async {
    final remaining = _maxFilesLimit - _selectedFiles.length;
    if (remaining <= 0) {
      final l10n = AppLocalizations.of(context)!;
      PopupDialogs.showErrorDialog(
        context,
        l10n.fieldIsRequired('Maximum $_maxFilesLimit files allowed'),
      );
      return;
    }

    final result = await context.pushNamed<CameraMediaPickResult>(
      'add_post_camera',
      extra: {'returnMediaOnDone': true, 'initialSound': _selectedSound},
    );

    if (!mounted || result == null || result.files.isEmpty) return;

    final toAdd = result.files.take(remaining).toList();
    setState(() {
      _selectedFiles = [..._selectedFiles, ...toAdd];
      if (result.sound != null) _selectedSound = result.sound;
      _updateType();
    });
  }

  PostAuctionInput? _buildAuctionInput(AppLocalizations l10n) {
    if (!_isAuction) return null;

    final itemName = _auctionItemNameController.text.trim();
    if (itemName.isEmpty) {
      PopupDialogs.showErrorDialog(
        context,
        l10n.fieldIsRequired(l10n.auctionItemName),
      );
      return null;
    }

    final startingPrice = double.tryParse(_startingPriceController.text.trim());
    final targetPrice = double.tryParse(_targetPriceController.text.trim());
    if (startingPrice == null ||
        startingPrice <= 0 ||
        targetPrice == null ||
        targetPrice <= 0) {
      PopupDialogs.showErrorDialog(context, l10n.auctionInvalidPrice);
      return null;
    }
    if (targetPrice <= startingPrice) {
      PopupDialogs.showErrorDialog(context, l10n.auctionTargetBelowStart);
      return null;
    }
    if (!_auctionEndDate.isAfter(_auctionStartDate)) {
      PopupDialogs.showErrorDialog(context, l10n.auctionEndBeforeStart);
      return null;
    }

    return PostAuctionInput(
      itemName: itemName,
      startingPrice: startingPrice,
      targetPrice: targetPrice,
      startedAt: _auctionStartDate,
      endedAt: _auctionEndDate,
    );
  }

  int get _maxFilesLimit => widget.isStory ? 1 : _maxFiles;

  void _onCreatePost() {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedFiles.isEmpty) {
      PopupDialogs.showErrorDialog(context, l10n.pleaseSelectMediaFirst);
      return;
    }

    PostAuctionInput? auction;
    if (!widget.isStory) {
      auction = _buildAuctionInput(l10n);
      if (_isAuction && auction == null) return;

      if (_selectedCategory == null) {
        PopupDialogs.showErrorDialog(
          context,
          l10n.fieldIsRequired(l10n.categoryLabel),
        );
        return;
      }
    }

    // Stop any leftover sound preview before upload/processing starts.
    SoundAudioPreview.stop();

    context.read<PostsBloc>().add(
      CreatePostWithMediaRequestedEvent(
        type: _type,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        categoryId: widget.isStory ? null : _selectedCategory!.id,
        privacyStatus: _privacyStatus,
        allowComments: _allowComments,
        allowDuets: widget.isStory ? false : _allowDuets,
        allowStitch: widget.isStory ? false : _allowStitch,
        status: 'PUBLISHED',
        isStory: widget.isStory,
        isAuctionable: widget.isStory ? false : _isAuction,
        auction: widget.isStory ? null : auction,
        files: _selectedFiles,
        soundId: _selectedSound?.id,
        filterName: widget.initialFilterName,
        filterCategory: widget.initialFilterCategory,
        effectSlug: widget.initialEffectSlug,
        beautyEnabled: widget.initialBeautyEnabled ? true : null,
        location: _buildLocationInput(),
      ),
    );
  }

  PostInlineLocationInput? _buildLocationInput() {
    final selection = _selectedLocation;
    if (selection == null) return null;
    final city = selection.city;
    final lat = city.latitude;
    final lng = city.longitude;
    if (lat == null || lng == null) {
      return PostInlineLocationInput(
        name: city.name,
        latitude: 0,
        longitude: 0,
        city: city.name,
        countryCode: selection.country.code,
        placeId: city.id.toString(),
      );
    }
    return PostInlineLocationInput(
      name: city.name,
      latitude: lat,
      longitude: lng,
      city: city.name,
      countryCode: selection.country.code,
      placeId: city.id.toString(),
    );
  }

  Future<void> _showLocationPicker() async {
    final picked = await AddPostLocationSearchScreen.open(
      context,
      initial: _selectedLocation,
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedLocation = picked);
  }

  void _clearLocation() {
    setState(() => _selectedLocation = null);
  }

  Future<void> _showSoundPicker() async {
    final picked = await SoundPickerSheet.show(
      context,
      initialSelection: _selectedSound,
      initialOffset: _soundStartOffset,
      initialWindow: _soundWindow,
    );
    if (!mounted || picked == null) return;
    if (picked.cleared) {
      setState(() {
        _selectedSound = null;
        _soundStartOffset = Duration.zero;
        _soundWindow = const Duration(seconds: 15);
      });
      return;
    }
    final sound = picked.sound;
    if (sound == null) return;
    setState(() {
      _selectedSound = sound;
      _soundStartOffset = picked.offset;
      _soundWindow = picked.window > Duration.zero
          ? picked.window
          : const Duration(seconds: 15);
    });
  }

  Future<void> _openSoundDetail() async {
    final sound = _selectedSound;
    if (sound == null) return;
    final picked = await openSoundDetail(
      context,
      soundId: sound.id,
      pickMode: true,
      preview: sound,
    );
    if (picked != null && mounted) {
      setState(() => _selectedSound = picked);
    }
  }

  Future<void> _pickAuctionDate({required bool isStart}) async {
    final initial = isStart ? _auctionStartDate : _auctionEndDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    final combined = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _auctionStartDate = combined;
        if (!_auctionEndDate.isAfter(_auctionStartDate)) {
          _auctionEndDate = _auctionStartDate.add(
            const Duration(
              days: AddPostLayoutConstants.defaultAuctionDurationDays,
            ),
          );
        }
      } else {
        _auctionEndDate = combined;
      }
    });
  }

  void _showCategoryPicker() {
    AddPostCategoryPickerSheet.show(
      context,
      categories: _categories,
      selectedCategory: _selectedCategory,
      onSelected: (category) => setState(() => _selectedCategory = category),
    );
  }

  void _showPrivacyPicker() {
    if (widget.isStory) {
      AddPostPrivacyPickerSheet.show(
        context,
        selectedStatus: _privacyStatus,
        onSelected: (status) => setState(() => _privacyStatus = status),
      );
      return;
    }
    AddPostSettingsSheet.show(
      context,
      privacyStatus: _privacyStatus,
      allowComments: _allowComments,
      allowReuse: _allowDuets && _allowStitch,
      onPrivacyChanged: (status) => setState(() => _privacyStatus = status),
      onAllowCommentsChanged: (v) => setState(() => _allowComments = v),
      onAllowReuseChanged: (v) => setState(() {
        _allowDuets = v;
        _allowStitch = v;
      }),
    );
  }

  Widget _composerHeader(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final coverFile = _selectedFiles.isEmpty ? null : _selectedFiles.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: MentionComposerField(
              controller: _descriptionController,
              maxLines: widget.isStory ? 4 : 7,
              minLines: 4,
              decoration: InputDecoration(
                hintText: widget.isStory
                    ? l10n.storyCaptionHint
                    : l10n.addDescriptionHint,
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 15,
                  height: 1.4,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 12),
          AddPostCoverPreview(
            file: coverFile,
            soundName: _selectedSound?.name,
            onAdd: widget.isStory ? _retakeStory : _showMediaPickerOptions,
            onEdit: () {
              if (widget.isStory) {
                _retakeStory();
              } else if (_selectedFiles.isNotEmpty) {
                _editMediaAt(0);
              } else {
                _showMediaPickerOptions();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _tagRow(BuildContext context, AppLocalizations l10n) {
    if (widget.isStory) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          AddPostTagButton(
            icon: LucideIcons.hash,
            label: l10n.hashtagsLabel,
            onTap: () => HashtagPickerSheet.show(
              context,
              controller: _descriptionController,
            ),
          ),
          const SizedBox(width: 10),
          AddPostTagButton(
            icon: LucideIcons.atSign,
            label: l10n.mentionsLabel,
            onTap: () => MentionPickerSheet.show(
              context,
              controller: _descriptionController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationChipBar(BuildContext context) {
    final selection = _selectedLocation;
    if (selection == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final fill = theme.brightness == Brightness.dark
        ? const Color(0xFF2A2A2D)
        : const Color(0xFFF1F1F2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 0, 16, 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: _showLocationPicker,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selection.displayLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _clearLocation,
                    child: Icon(
                      LucideIcons.x,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionsList(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    if (widget.isStory) {
      return AddPostSettingItem(
        icon: LucideIcons.lock,
        title: localizedAddPostPrivacyRowLabel(_privacyStatus, l10n),
        onTap: _showPrivacyPicker,
        showDivider: false,
      );
    }

    return Column(
      children: [
        AddPostSettingItem(
          icon: LucideIcons.mapPin,
          title: l10n.locationLabelShort,
          onTap: _showLocationPicker,
          below: _locationChipBar(context),
        ),
        AddPostSettingItem(
          icon: privacyIconForStatus(_privacyStatus),
          title: localizedAddPostPrivacyRowLabel(_privacyStatus, l10n),
          onTap: _showPrivacyPicker,
        ),
        AddPostSettingItem(
          icon: LucideIcons.layoutGrid,
          title: l10n.categoryLabel,
          trailing: _isLoadingCategories
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : CustomText(
                  _selectedCategory?.name ?? l10n.selectCategoryHint,
                  variant: TextVariant.secondary,
                  fontSize: 14,
                ),
          onTap: _showCategoryPicker,
        ),
        AddPostSettingItem(
          icon: LucideIcons.music,
          title: l10n.soundLabel,
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _selectedSound?.name ?? l10n.soundNoneSelected,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ),
                if (_selectedSound != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _openSoundDetail,
                    child: Icon(
                      LucideIcons.info,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          onTap: _showSoundPicker,
        ),
        AddPostSettingItem(
          icon: LucideIcons.gavel,
          title: l10n.addPostAsAuction,
          showChevron: false,
          showDivider: false,
          trailing: Switch.adaptive(
            value: _isAuction,
            activeTrackColor: theme.colorScheme.primary,
            onChanged: (value) => setState(() => _isAuction = value),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: widget.isStory
            ? Text(
                l10n.addStoryTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
        centerTitle: true,
      ),
      body: BlocConsumer<PostsBloc, PostsState>(
        listener: (context, state) {
          if (state is PostsFailure) {
            PopupDialogs.showErrorDialog(context, state.message);
          } else if (state is CreatePostSuccess) {
            if (widget.isStory) {
              context.goNamed('home');
            } else {
              context.goNamed('home', queryParameters: {'tab': 'profile'});
            }
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _composerHeader(context, l10n),
                      _tagRow(context, l10n),
                      if (!widget.isStory && _selectedFiles.length > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: AddPostMediaStrip(
                            files: _selectedFiles,
                            maxFiles: _maxFilesLimit,
                            allowAdd: true,
                            onAddTap: _showMediaPickerOptions,
                            onRemoveAt: _removeFile,
                            onEditAt: _editMediaAt,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Divider(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
                      _optionsList(context, l10n),
                      if (!widget.isStory)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _isAuction
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    16,
                                  ),
                                  child: AddPostAuctionFields(
                                    itemNameController:
                                        _auctionItemNameController,
                                    startingPriceController:
                                        _startingPriceController,
                                    targetPriceController:
                                        _targetPriceController,
                                    startDate: _auctionStartDate,
                                    endDate: _auctionEndDate,
                                    onPickStartDate: () =>
                                        _pickAuctionDate(isStart: true),
                                    onPickEndDate: () =>
                                        _pickAuctionDate(isStart: false),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              AddPostPublishBar(
                label: widget.isStory ? l10n.shareStoryButton : l10n.postButton,
                onPressed: _onCreatePost,
                isLoading: state is PostsLoading,
                showDrafts: !widget.isStory,
                onDraftsPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.addPostDraftsComingSoon)),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
