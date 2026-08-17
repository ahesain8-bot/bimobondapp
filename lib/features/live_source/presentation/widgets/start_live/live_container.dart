import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../../../../features/live/presentation/widgets/live_countdown_overlay.dart';
import '../../../../../features/live/presentation/pages/live_room_page.dart';

/// Live setup card: title input + image picker + LIVE start button.
class LiveContainer extends StatefulWidget {
  const LiveContainer({super.key, required this.titleController});

  final TextEditingController titleController;

  @override
  State<LiveContainer> createState() => _LiveContainerState();
}

class _LiveContainerState extends State<LiveContainer> {
  /// Shows countdown (3 → 2 → 1), then navigates to the live room.
  Future<void> _openLiveRoom(BuildContext context) async {
    await LiveCountdownOverlay.run(context);
    if (!context.mounted) return;

    final title = widget.titleController.text.trim();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LiveRoomPage(
          title: title.isEmpty ? null : title,
        ),
      ),
    );
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
              Container(
                width: AppSizes.imagePickerButton,
                height: AppSizes.imagePickerButton,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: Colors.white60,
                  size: AppSizes.imagePickerIcon,
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
                    'بدء',
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
