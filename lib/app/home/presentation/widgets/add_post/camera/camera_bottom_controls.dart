import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CameraBottomAction extends StatelessWidget {
  const CameraBottomAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class CameraModeSelector extends StatelessWidget {
  const CameraModeSelector({
    super.key,
    required this.modes,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<CameraStudioMode> modes;
  final CameraStudioMode selected;
  final String Function(CameraStudioMode mode) labelBuilder;
  final ValueChanged<CameraStudioMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < modes.length; index++) ...[
            if (index > 0) const SizedBox(width: 24),
            CameraModeTab(
              label: labelBuilder(modes[index]),
              isSelected: modes[index] == selected,
              isLive: modes[index] == CameraStudioMode.live,
              onTap: () => onSelected(modes[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class CameraModeTab extends StatelessWidget {
  const CameraModeTab({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isLive,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isLive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isLive
                      ? LiveDetailsLayoutConstants.liveBadgeColor
                      : Colors.white)
                : Colors.white54,
            fontSize: isSelected ? 14 : 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: isLive && isSelected ? 0.8 : 0,
          ),
        ),
      ),
    );
  }
}

class CameraGoLiveButton extends StatelessWidget {
  const CameraGoLiveButton({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: compact ? 52 : 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              LiveDetailsLayoutConstants.liveBadgeColor,
              LiveDetailsLayoutConstants.liveBadgeDark,
            ],
          ),
          borderRadius: BorderRadius.circular(compact ? 26 : 28),
          boxShadow: [
            BoxShadow(
              color: LiveDetailsLayoutConstants.liveBadgeColor.withValues(
                alpha: 0.35,
              ),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class CameraRecordButton extends StatelessWidget {
  const CameraRecordButton({
    super.key,
    required this.isRecording,
    required this.isBusy,
    required this.progress,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final bool isRecording;
  final bool isBusy;
  final double progress;
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onTap,
      onLongPressStart: isBusy ? null : onLongPressStart,
      onLongPressEnd: isBusy ? null : onLongPressEnd,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: CircularProgressIndicator(
                value: isRecording ? progress.clamp(0, 1) : 0,
                strokeWidth: 4,
                color: Colors.redAccent,
                backgroundColor: Colors.white24,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isRecording ? 34 : 68,
              height: isRecording ? 34 : 68,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isRecording ? BorderRadius.circular(8) : null,
                border: Border.all(color: Colors.white, width: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CameraCaptureControls extends StatelessWidget {
  const CameraCaptureControls({
    super.key,
    required this.isLiveMode,
    required this.isPhotoMode,
    required this.isRecording,
    required this.isBusy,
    required this.recordProgress,
    required this.effectsLabel,
    required this.uploadLabel,
    required this.goLiveLabel,
    required this.onEffectsTap,
    required this.onUploadTap,
    required this.onGoLiveTap,
    required this.onRecordTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final bool isLiveMode;
  final bool isPhotoMode;
  final bool isRecording;
  final bool isBusy;
  final double recordProgress;
  final String effectsLabel;
  final String uploadLabel;
  final String goLiveLabel;
  final VoidCallback onEffectsTap;
  final VoidCallback onUploadTap;
  final VoidCallback onGoLiveTap;
  final VoidCallback onRecordTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    if (isLiveMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: CameraGoLiveButton(label: goLiveLabel, onTap: onGoLiveTap),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          CameraBottomAction(
            icon: LucideIcons.sparkles,
            label: effectsLabel,
            onTap: onEffectsTap,
          ),
          Expanded(
            child: Center(
              child: CameraRecordButton(
                isRecording: isRecording,
                isBusy: isBusy,
                progress: recordProgress,
                onTap: onRecordTap,
                onLongPressStart: isPhotoMode ? null : onLongPressStart,
                onLongPressEnd: isPhotoMode ? null : onLongPressEnd,
              ),
            ),
          ),
          CameraBottomAction(
            icon: LucideIcons.imageUp,
            label: uploadLabel,
            onTap: onUploadTap,
          ),
        ],
      ),
    );
  }
}
