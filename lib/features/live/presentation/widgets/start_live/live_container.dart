import 'dart:io';

import 'package:camera/camera.dart';
import 'package:bimobondapp/app/camera_engine/native_camera_controller.dart';
import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/domain/usecases/get_categories_usecase.dart';
import 'package:bimobondapp/app/categories/presentation/di/categories_injector.dart'
    as categories_di;
import 'package:bimobondapp/app/posts/domain/usecases/upload_media_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';
import '../../bloc/start_live/live_state.dart';
import '../../pages/live_room_page.dart';

/// Live setup card: title input + image picker + LIVE start button.
class LiveContainer extends StatefulWidget {
  const LiveContainer({super.key, required this.titleController});

  final TextEditingController titleController;

  @override
  State<LiveContainer> createState() => _LiveContainerState();
}

class _LiveContainerState extends State<LiveContainer> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _coverUrl;
  String? _categoryId;
  bool _isUploadingCover = false;

  Future<String?> _pickAndUploadCover() async {
    if (_isUploadingCover) return null;
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a hosted cover URL on web.')),
        );
      }
      return null;
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return null;
      setState(() => _isUploadingCover = true);
      final result = await posts_di.sl<UploadMediaUseCase>().call(File(picked.path));
      if (!mounted) return null;
      return result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cover upload failed: $failure')),
          );
          return null;
        },
        (url) {
          setState(() => _coverUrl = url);
          return url;
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cover selection failed: $error')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _chooseCategory(TextEditingController controller) async {
    try {
      final result = await categories_di.sl<GetCategoriesUseCase>()(
        const GetCategoriesParams.flat(),
      );
      if (!mounted) return;
      await result.fold(
        (failure) async {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Categories unavailable: $failure')),
          );
        },
        (categories) async {
          final selected = await showDialog<CategoryEntity>(
            context: context,
            builder: (dialogContext) => SimpleDialog(
              title: const Text('Choose category'),
              children: [
                for (final category in flattenCategories(categories))
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialogContext, category),
                    child: Text(category.name),
                  ),
              ],
            ),
          );
          if (selected != null && mounted) controller.text = selected.id;
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Categories unavailable: $error')),
        );
      }
    }
  }

  Future<void> _openLiveRoom(BuildContext context) async {
    final title = widget.titleController.text.trim();
    final liveBloc = context.read<LiveBloc>();
    final useExistingArCamera =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    // REUSE the camera that is already running on the start screen: hand the
    // SAME controller to the room (no close/reopen -> no black flicker).
    final ready = liveBloc.state is LiveReady
        ? liveBloc.state as LiveReady
        : null;
    final CameraController? runningCamera =
        (ready != null && ready.isCameraInitialized) ? ready.controller : null;
    final NativeCameraController? runningNativeCamera =
        (ready != null && ready.isCameraInitialized)
        ? ready.nativeController
        : null;

    if (useExistingArCamera) {
      final unmounted = liveBloc.stream.firstWhere(
        (state) => state is LiveReady && !state.isCameraInitialized,
      );
      liveBloc.add(const LiveCameraHandedOff());
      try {
        await unmounted.timeout(const Duration(seconds: 1));
      } catch (_) {}
      await WidgetsBinding.instance.endOfFrame;
    } else if (runningCamera != null || runningNativeCamera != null) {
      liveBloc.add(const LiveCameraHandedOff());
    } else {
      liveBloc.add(const LiveAppPaused());
    }
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveRoomPage(
          title: title.isEmpty ? null : title,
          coverUrl: _coverUrl,
          categoryId: _categoryId,
          initialCamera: useExistingArCamera ? null : runningCamera,
          initialNativeCamera: useExistingArCamera ? null : runningNativeCamera,
        ),
      ),
    );

    if (!context.mounted) return;
    liveBloc.add(const LiveAppResumed());
  }

  Future<void> _editLiveMetadata() async {
    final cover = TextEditingController(text: _coverUrl);
    final category = TextEditingController(text: _categoryId);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Live details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cover,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Cover URL (optional)'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isUploadingCover
                    ? null
                    : () async {
                        final url = await _pickAndUploadCover();
                        if (url != null) cover.text = url;
                      },
                icon: _isUploadingCover
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: const Text('Pick cover from gallery'),
              ),
            ),
            TextField(
              controller: category,
              readOnly: true,
              onTap: () => _chooseCategory(category),
              decoration: const InputDecoration(labelText: 'Category ID (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    setState(() {
      _coverUrl = cover.text.trim().isEmpty ? null : cover.text.trim();
      _categoryId = category.text.trim().isEmpty ? null : category.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.liveContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.titleController,
                  decoration: InputDecoration(
                    hintText: 'اضافة عنوان',
                    hintStyle: AppTextStyles.titleHint.copyWith(fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppTextStyles.titleInput.copyWith(fontSize: 13),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: _editLiveMetadata,
                child: Container(
                  width: AppSizes.imagePickerButton,
                  height: AppSizes.imagePickerButton,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                  child: Icon(
                    _coverUrl == null ? Icons.image_outlined : Icons.image,
                    color: Colors.white60,
                    size: AppSizes.imagePickerIcon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.liveContentGap),
          SizedBox(
            width: double.infinity,
            height: AppSizes.liveButtonHeight,
            child: ElevatedButton(
              onPressed: () => _openLiveRoom(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusButton),
                ),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'LIVE',
                    style: AppTextStyles.liveTitle.copyWith(
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    'إنشاء',
                    style: AppTextStyles.liveStart.copyWith(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
