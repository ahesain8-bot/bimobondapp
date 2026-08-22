import 'dart:io';

import 'package:bimobondapp/app/auth/data/datasources/profile_remote_data_source.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/data/models/post_model.dart';
import 'package:bimobondapp/app/posts/domain/usecases/upload_media_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_injector;
import 'package:bimobondapp/app/stories/domain/entities/highlight_entity.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';

/// Authentic Instagram iOS 2-Step Story Highlight Picker & Creator
class CreateHighlightSheet extends StatefulWidget {
  const CreateHighlightSheet({
    this.existingHighlight,
    this.initialStories = const [],
    this.onCreated,
    super.key,
  });

  final HighlightEntity? existingHighlight;
  final List<PostEntity> initialStories;
  final ValueChanged<HighlightEntity>? onCreated;

  static void show(
    BuildContext context, {
    HighlightEntity? existingHighlight,
    List<PostEntity> initialStories = const [],
    ValueChanged<HighlightEntity>? onCreated,
    VoidCallback? onSaved,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateHighlightSheet(
        existingHighlight: existingHighlight,
        initialStories: initialStories,
        onCreated: onCreated,
      ),
    ).then((_) => onSaved?.call());
  }

  @override
  State<CreateHighlightSheet> createState() => _CreateHighlightSheetState();
}

class _CreateHighlightSheetState extends State<CreateHighlightSheet> {
  final ProfileRemoteDataSource _remoteDS = ProfileRemoteDataSourceImpl();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _coverController = TextEditingController();

  int _step = 0; // 0: Add to highlights (Grid), 1: New highlight (Details)
  bool _isSubmitting = false;
  bool _isLoadingStories = false;

  final List<PostEntity> _availableStories = [];
  final Set<String> _selectedStoryIds = {};
  String? _selectedCoverUrl;

  @override
  void initState() {
    super.initState();
    if (widget.existingHighlight != null) {
      _titleController.text = widget.existingHighlight!.title;
      _coverController.text = widget.existingHighlight!.coverUrl ?? '';
      _selectedCoverUrl = widget.existingHighlight!.coverUrl;
      _step = 1;
      for (final s in widget.existingHighlight!.stories) {
        _selectedStoryIds.add(s.id);
      }
    }
    for (final s in widget.initialStories) {
      _selectedStoryIds.add(s.id);
    }
    _availableStories.addAll(widget.initialStories);
    _fetchUserStories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _coverController.dispose();
    super.dispose();
  }

  /// Fetches complete Story Archive (active + expired) via GET /stories/me?page=1&limit=50&activeOnly=false
  Future<void> _fetchUserStories() async {
    setState(() => _isLoadingStories = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': ApiConstants.apiKey,
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      List<dynamic> list = [];

      try {
        final res = await dio.get<dynamic>(
          ApiConstants.myStories,
          queryParameters: {
            'page': 1,
            'limit': 50,
            'activeOnly': 'false',
          },
        );
        final data = res.data;
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'] as List;
        } else if (data is Map && data['stories'] is List) {
          list = data['stories'] as List;
        } else if (data is Map && data['items'] is List) {
          list = data['items'] as List;
        }
      } catch (e) {
        debugPrint('[CreateHighlightSheet] GET ${ApiConstants.myStories} failed: $e, trying /posts fallback');
        final res = await dio.get<dynamic>(
          ApiConstants.createPost,
          queryParameters: {'userId': user.uid, 'limit': 50},
        );
        final data = res.data;
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'] as List;
        } else if (data is Map && data['posts'] is List) {
          list = data['posts'] as List;
        }
      }

      final fetched = list
          .whereType<Map>()
          .map((m) => PostModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      if (mounted) {
        setState(() {
          final existingIds = _availableStories.map((s) => s.id).toSet();
          for (final item in fetched) {
            if (!existingIds.contains(item.id)) {
              _availableStories.add(item);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[CreateHighlightSheet] _fetchUserStories error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingStories = false);
      }
    }
  }

  void _toggleStorySelection(String storyId) {
    setState(() {
      if (_selectedStoryIds.contains(storyId)) {
        _selectedStoryIds.remove(storyId);
      } else {
        _selectedStoryIds.add(storyId);
      }
    });
  }

  String? _getStoryCoverUrl(PostEntity story) {
    if (story.thumbnailUrl != null && story.thumbnailUrl!.isNotEmpty) {
      return story.thumbnailUrl;
    }
    if (story.media.isNotEmpty) {
      for (final m in story.media) {
        if (m.url.isNotEmpty) {
          return m.url;
        }
      }
    }
    if (story.videoUrl != null && story.videoUrl!.isNotEmpty) {
      return story.videoUrl;
    }
    if (story.hlsUrl != null && story.hlsUrl!.isNotEmpty) {
      return story.hlsUrl;
    }
    return null;
  }

  void _goToStep2() {
    if (_selectedCoverUrl == null || _selectedCoverUrl!.isEmpty) {
      // Default cover to the cover of the first selected story
      for (final s in _availableStories) {
        if (_selectedStoryIds.contains(s.id)) {
          _selectedCoverUrl = _getStoryCoverUrl(s);
          _coverController.text = _selectedCoverUrl ?? '';
          break;
        }
      }
    }
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'Highlights';

    final coverUrl = _coverController.text.trim().isNotEmpty
        ? _coverController.text.trim()
        : _selectedCoverUrl;

    final storyIds = _selectedStoryIds.toList();

    setState(() => _isSubmitting = true);

    try {
      if (widget.existingHighlight != null) {
        var updated = await _remoteDS.updateHighlight(
          widget.existingHighlight!.id,
          title: title,
          coverUrl: coverUrl,
        );
        if (storyIds.isNotEmpty) {
          try {
            updated = await _remoteDS.addBulkStoriesToHighlight(
              widget.existingHighlight!.id,
              storyIds,
            );
          } catch (_) {}
        }
        widget.onCreated?.call(updated);
        if (mounted) {
          PopupDialogs.showSuccessDialog(context, 'Highlight updated');
          Navigator.pop(context);
        }
      } else {
        var highlight = await _remoteDS.createHighlight(
          title,
          coverUrl,
          0,
        );
        if (storyIds.isNotEmpty) {
          try {
            highlight = await _remoteDS.addBulkStoriesToHighlight(
              highlight.id,
              storyIds,
            );
          } catch (_) {}
        }
        widget.onCreated?.call(highlight);
        if (mounted) {
          PopupDialogs.showSuccessDialog(context, 'Highlight created');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        PopupDialogs.showErrorDialog(context, 'Failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickAndUploadCover(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      if (mounted) {
        PopupDialogs.showLoadingDialog(context);
      }

      final file = File(pickedFile.path);
      final uploadResult =
          await posts_injector.sl<UploadMediaUseCase>().call(file);

      if (mounted) {
        PopupDialogs.hideLoadingDialog(context);
      }

      uploadResult.fold(
        (failure) {
          if (mounted) {
            PopupDialogs.showErrorDialog(context, 'Failed to upload cover image');
          }
        },
        (uploadedUrl) {
          if (mounted) {
            setState(() {
              _selectedCoverUrl = uploadedUrl;
              _coverController.text = uploadedUrl;
            });
            PopupDialogs.showSuccessDialog(context, 'Cover updated');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        PopupDialogs.hideLoadingDialog(context);
        PopupDialogs.showErrorDialog(context, 'Unable to pick image: $e');
      }
    }
  }

  void _showEditCoverOptions() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(
                  l10n.chooseFromGallery,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadCover(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text(
                  l10n.takePhoto,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadCover(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(
                  l10n.pasteImageUrl,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPasteUrlDialog();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showPasteUrlDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editCover),
        content: TextField(
          controller: _coverController,
          decoration: const InputDecoration(
            hintText: 'Paste cover image URL',
            labelText: 'Cover URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.templateExportDone == 'Done' ? 'Cancel' : 'إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedCoverUrl = _coverController.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: Text(l10n.templateExportDone == 'Done' ? 'Apply' : 'تطبيق'),
          ),
        ],
      ),
    );
  }

  String _formatDateBadge(DateTime? dt) {
    if (dt == null) return '17\nJul';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day;
    final month = months[(dt.month - 1).clamp(0, 11)];
    return '$day\n$month';
  }

  String _formatDuration(dynamic rawDuration) {
    if (rawDuration == null) return '0:20';
    int seconds = 20;
    if (rawDuration is num) {
      seconds = rawDuration.toInt();
    } else if (rawDuration is String) {
      seconds = int.tryParse(rawDuration) ?? 20;
    }
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEditing = widget.existingHighlight != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final l10n = AppLocalizations.of(context)!;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
        children: [
          const SizedBox(height: 8),

          // Header Bar matching Instagram screenshots
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (_step == 1 && !isEditing)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => setState(() => _step = 0),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n.templateExportDone == 'Done' ? 'Cancel' : 'إلغاء',
                      style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                const Spacer(),
                CustomText(
                  _step == 0 ? l10n.addToHighlights : (isEditing ? l10n.highlightsTitle : l10n.newHighlight),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
                const Spacer(),
                if (_step == 0)
                  TextButton(
                    onPressed: _selectedStoryIds.isNotEmpty ? _goToStep2 : null,
                    child: Text(
                      l10n.templateExportDone == 'Done' ? 'Next' : 'التالي',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _selectedStoryIds.isNotEmpty
                            ? cs.primary
                            : cs.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                else
                  _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _submit,
                          child: Text(
                            l10n.templateExportDone == 'Done' ? 'Done' : 'تم',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                        ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.12)),

          // Step Content
          Expanded(
            child: _step == 0 ? _buildStoriesStep(cs, theme) : _buildDetailsStep(cs, theme),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildStoriesStep(ColorScheme cs, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Selection grid matching Screenshot 2
        Expanded(
          child: _isLoadingStories && _availableStories.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _availableStories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 48,
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.noStoriesInArchive,
                            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(1),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: _availableStories.length,
                      itemBuilder: (context, index) {
                        final story = _availableStories[index];
                        final isSelected = _selectedStoryIds.contains(story.id);
                        final imageUrl = _getStoryCoverUrl(story);

                        return GestureDetector(
                          onTap: () => _toggleStorySelection(story.id),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Background Story Media
                              imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: cs.surfaceContainerHighest,
                                        child: const Icon(Icons.video_library_rounded),
                                      ),
                                    )
                                  : Container(
                                      color: cs.surfaceContainerHighest,
                                      child: const Icon(Icons.video_library_rounded),
                                    ),

                              // Selection dimming overlay
                              if (isSelected)
                                Container(
                                  color: Colors.black26,
                                ),

                              // Top-Left Date Pill Badge (e.g. "17\nJul")
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _formatDateBadge(story.createdAt),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),

                              // Top-Right Circular Selection Indicator
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? cs.primary : Colors.transparent,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: isSelected ? 0 : 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                      : null,
                                ),
                              ),

                              // Bottom-Left Duration Timestamp (e.g. "0:20")
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Text(
                                  _formatDuration(null),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 3,
                                        color: Colors.black87,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep(ColorScheme cs, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Large Circular Highlight Cover (Screenshot 1)
          GestureDetector(
            onTap: _showEditCoverOptions,
            child: Container(
              width: 104,
              height: 104,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: cs.onSurface.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                child: ClipOval(
                  child: (_selectedCoverUrl != null && _selectedCoverUrl!.isNotEmpty)
                      ? Image.network(
                          _selectedCoverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black,
                          ),
                        )
                      : Container(
                          color: Colors.black,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Edit Cover Button
          TextButton(
            onPressed: _showEditCoverOptions,
            child: Text(
              l10n.editCover,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Centered Highlight Title Input Field
          TextField(
            controller: _titleController,
            textAlign: TextAlign.center,
            autofocus: true,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              hintText: l10n.highlightsTitle,
              hintStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.35),
              ),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}
