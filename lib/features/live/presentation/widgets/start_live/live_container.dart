import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';
import '../../bloc/start_live/live_state.dart';
import '../../pages/live_room_page.dart';
import '../live_countdown_overlay.dart';

/// Live setup card: title input + image picker + LIVE start button.
class LiveContainer extends StatelessWidget {
  const LiveContainer({super.key, required this.titleController});

  final TextEditingController titleController;

  Future<void> _openLiveRoom(BuildContext context) async {
    // Pre-live countdown (3 → 2 → 1) shown over the camera preview.
    await LiveCountdownOverlay.run(context);
    if (!context.mounted) return;

    final title = titleController.text.trim();
    final liveBloc = context.read<LiveBloc>();

    // REUSE the camera that is already running on the start screen: hand the
    // SAME controller to the room (no close/reopen -> no black flicker).
    final ready = liveBloc.state is LiveReady
        ? liveBloc.state as LiveReady
        : null;
    final CameraController? runningCamera =
        (ready != null && ready.isCameraInitialized) ? ready.controller : null;

    if (runningCamera != null) {
      liveBloc.add(const LiveCameraHandedOff());
    } else {
      liveBloc.add(const LiveAppPaused());
    }
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveRoomPage(
          title: title.isEmpty ? null : title,
          initialCamera: runningCamera,
        ),
      ),
    );

    if (!context.mounted) return;
    liveBloc.add(const LiveAppResumed());
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
                  controller: titleController,
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
