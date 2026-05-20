import 'dart:io';

import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/domain/usecases/get_categories_usecase.dart';
import 'package:bimobondapp/app/categories/presentation/di/categories_injector.dart'
    as categories_di;
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_auction_fields.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_category_picker_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_chevron_icon.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_media_picker_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_media_widgets.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_privacy_picker_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_setting_item.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_tag_button.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_input.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/constants/add_post_layout_constants.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_button.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key, this.initialFiles, this.initialType});

  final List<File>? initialFiles;
  final String? initialType;

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  static const int _maxFiles = 5;
  final ImagePicker _picker = ImagePicker();

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
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    final result =
        await categories_di.sl<GetCategoriesUseCase>()(NoParams());
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

  Future<void> _showMediaPickerOptions() {
    return AddPostMediaPickerSheet.show(
      context,
      onPick: _pickMedia,
    );
  }

  Future<void> _pickMedia(ImageSource source, {required bool isVideo}) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (_selectedFiles.length >= _maxFiles) {
        PopupDialogs.showErrorDialog(
          context,
          l10n.fieldIsRequired('Maximum $_maxFiles files allowed'),
        );
        return;
      }
      if (isVideo) {
        final XFile? video = await _picker.pickVideo(source: source);
        if (!mounted) return;
        if (video != null) {
          setState(() {
            _selectedFiles = [..._selectedFiles, File(video.path)];
            _updateType();
          });
        }
      } else {
        if (source == ImageSource.camera) {
          final XFile? photo = await _picker.pickImage(
            source: ImageSource.camera,
          );
          if (!mounted) return;
          if (photo != null) {
            setState(() {
              _selectedFiles = [..._selectedFiles, File(photo.path)];
              _updateType();
            });
          }
        } else {
          final List<XFile> picked = await _picker.pickMultiImage();
          if (!mounted) return;
          if (picked.isNotEmpty) {
            final remaining = _maxFiles - _selectedFiles.length;
            final toAdd = picked
                .take(remaining)
                .map((e) => File(e.path))
                .toList();
            if (toAdd.length < picked.length) {
              PopupDialogs.showErrorDialog(
                context,
                l10n.fieldIsRequired('Maximum $_maxFiles files allowed'),
              );
            }
            setState(() {
              _selectedFiles = [..._selectedFiles, ...toAdd];
              _updateType();
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      PopupDialogs.showErrorDialog(
        context,
        '${l10n.fieldIsRequired('Media')}: $e',
      );
    }
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
      startingPriceUsd: startingPrice,
      targetPriceUsd: targetPrice,
      startedAt: _auctionStartDate,
      endedAt: _auctionEndDate,
    );
  }

  void _onCreatePost() {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedFiles.isEmpty) {
      PopupDialogs.showErrorDialog(context, l10n.pleaseSelectMediaFirst);
      return;
    }

    final auction = _buildAuctionInput(l10n);
    if (_isAuction && auction == null) return;

    if (_selectedCategory == null) {
      PopupDialogs.showErrorDialog(
        context,
        l10n.fieldIsRequired(l10n.categoryLabel),
      );
      return;
    }

    context.read<PostsBloc>().add(
      CreatePostWithMediaRequestedEvent(
        type: _type,
        description: _descriptionController.text.trim(),
        category: _selectedCategory!.slug,
        privacyStatus: _privacyStatus,
        allowComments: _allowComments,
        allowDuets: _allowDuets,
        allowStitch: _allowStitch,
        status: 'PUBLISHED',
        isAuctionable: _isAuction,
        auction: auction,
        files: _selectedFiles,
      ),
    );
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
    AddPostPrivacyPickerSheet.show(
      context,
      selectedStatus: _privacyStatus,
      onSelected: (status) => setState(() => _privacyStatus = status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(title: l10n.addPost, showBackButton: true),
      body: BlocConsumer<PostsBloc, PostsState>(
        listener: (context, state) {
          if (state is PostsFailure) {
            PopupDialogs.showErrorDialog(context, state.message);
          } else if (state is CreatePostSuccess) {
            context.goNamed('home');
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: l10n.describePostHint,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      AddPostMediaStrip(
                        files: _selectedFiles,
                        maxFiles: _maxFiles,
                        onAddTap: _showMediaPickerOptions,
                        onRemoveAt: _removeFile,
                      ),
                      const SizedBox(height: AppSizes.p12),
                      Row(
                        children: [
                          AddPostTagButton(
                            icon: LucideIcons.hash,
                            label: l10n.hashtagsLabel,
                            onTap: () {},
                          ),
                          const SizedBox(width: AppSizes.p12),
                          AddPostTagButton(
                            icon: LucideIcons.atSign,
                            label: l10n.mentionsLabel,
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.p24),
                      Divider(color: theme.colorScheme.outlineVariant),
                      AddPostSettingItem(
                        icon: LucideIcons.gavel,
                        title: l10n.addPostAsAuction,
                        trailing: Switch.adaptive(
                          value: _isAuction,
                          activeTrackColor: theme.colorScheme.primary,
                          onChanged: (value) =>
                              setState(() => _isAuction = value),
                        ),
                      ),
                      if (_isAuction) ...[
                        const SizedBox(height: AppSizes.p8),
                        AddPostAuctionFields(
                          itemNameController: _auctionItemNameController,
                          startingPriceController: _startingPriceController,
                          targetPriceController: _targetPriceController,
                          startDate: _auctionStartDate,
                          endDate: _auctionEndDate,
                          onPickStartDate: () =>
                              _pickAuctionDate(isStart: true),
                          onPickEndDate: () =>
                              _pickAuctionDate(isStart: false),
                        ),
                      ],
                      AddPostSettingItem(
                        icon: LucideIcons.layoutGrid,
                        title: l10n.categoryLabel,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isLoadingCategories)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            else
                              CustomText(
                                _selectedCategory?.name ??
                                    l10n.selectCategoryHint,
                                variant: TextVariant.secondary,
                                fontSize: 14,
                              ),
                            const AddPostChevronIcon(),
                          ],
                        ),
                        onTap: _categories.isEmpty && !_isLoadingCategories
                            ? null
                            : _showCategoryPicker,
                      ),
                      AddPostSettingItem(
                        icon: LucideIcons.lock,
                        title: l10n.whoCanWatchLabel,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomText(
                              localizedAddPostPrivacyStatus(
                                _privacyStatus,
                                l10n,
                              ),
                              variant: TextVariant.secondary,
                              fontSize: 14,
                            ),
                            const AddPostChevronIcon(),
                          ],
                        ),
                        onTap: _showPrivacyPicker,
                      ),
                      AddPostSettingItem(
                        icon: LucideIcons.mapPin,
                        title: l10n.addLocationLabel,
                        trailing: const AddPostChevronIcon(),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.p16,
                  AppSizes.p16,
                  AppSizes.p16,
                  MediaQuery.of(context).padding.bottom + AppSizes.p16,
                ),
                child: CustomButton(
                  onPressed: _onCreatePost,
                  text: l10n.postButton,
                  isLoading: state is PostsLoading,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
