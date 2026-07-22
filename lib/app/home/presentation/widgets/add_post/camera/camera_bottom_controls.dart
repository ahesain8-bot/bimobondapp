import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_tool_icons.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:flutter/material.dart';

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
    return CameraBottomTool(icon: icon, label: label, onTap: onTap);
  }
}

class CameraModeDurationBar extends StatelessWidget {
  const CameraModeDurationBar({
    super.key,
    required this.studioMode,
    required this.selectedDuration,
    required this.photoLabel,
    required this.textLabel,
    required this.liveLabel,
    required this.duration10mLabel,
    required this.showLive,
    required this.showText,
    required this.onPhotoSelected,
    required this.onDurationSelected,
    required this.onLiveSelected,
    required this.onTextSelected,
  });

  final CameraStudioMode studioMode;
  final int selectedDuration;
  final String photoLabel;
  final String textLabel;
  final String liveLabel;
  final String duration10mLabel;
  final bool showLive;
  final bool showText;
  final VoidCallback onPhotoSelected;
  final ValueChanged<int> onDurationSelected;
  final VoidCallback onLiveSelected;
  final VoidCallback onTextSelected;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _ModeDurationItem(
        label: duration10mLabel,
        selected:
            studioMode == CameraStudioMode.video && selectedDuration == 180,
        onTap: () => onDurationSelected(180),
      ),
      _ModeDurationItem(
        label: '60s',
        selected:
            studioMode == CameraStudioMode.video && selectedDuration == 60,
        onTap: () => onDurationSelected(60),
      ),
      _ModeDurationItem(
        label: '15s',
        selected:
            studioMode == CameraStudioMode.video && selectedDuration == 15,
        onTap: () => onDurationSelected(15),
      ),
      _ModeDurationItem(
        label: photoLabel,
        selected: studioMode == CameraStudioMode.photo,
        onTap: onPhotoSelected,
      ),
      if (showText)
        _ModeDurationItem(
          label: textLabel,
          selected: false,
          onTap: onTextSelected,
        ),
      if (showLive)
        _ModeDurationItem(
          label: liveLabel,
          selected: studioMode == CameraStudioMode.live,
          isLive: true,
          onTap: onLiveSelected,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              items[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeDurationItem extends StatelessWidget {
  const _ModeDurationItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isLive = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? (isLive
                      ? LiveDetailsLayoutConstants.liveBadgeColor
                      : Colors.black)
                : Colors.white,
            fontSize: selected ? 14 : 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            letterSpacing: isLive && selected ? 0.5 : 0,
            shadows: selected
                ? null
                : const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

class CameraWorkspaceTabs extends StatelessWidget {
  const CameraWorkspaceTabs({
    super.key,
    required this.postLabel,
    required this.creativeLabel,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String postLabel;
  final String creativeLabel;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final postTab = _WorkspaceTab(
      label: postLabel,
      selected: selectedIndex == 0,
      onTap: () => onSelected(0),
    );
    final createTab = _WorkspaceTab(
      label: creativeLabel,
      selected: selectedIndex == 1,
      onTap: () => onSelected(1),
    );

    // Stack + directional align so RTL doesn't flip Create under the upload
    // button (Row would reverse and collide with gallery on the start edge).
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          postTab,
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              alignment: AlignmentDirectional.centerStart,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 36),
                  child: createTab,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceTab extends StatelessWidget {
  const _WorkspaceTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.45),
            fontSize: 15,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0.6,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
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
      height: 40,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < modes.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isLive
                      ? LiveDetailsLayoutConstants.liveBadgeColor
                      : Colors.white)
                : Colors.white,
            fontSize: isSelected ? 16 : 15,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
            letterSpacing: isLive && isSelected ? 0.6 : 0,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
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
    this.isPhotoMode = false,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final bool isRecording;
  final bool isBusy;
  final double progress;
  final VoidCallback onTap;
  final bool isPhotoMode;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final innerColor = isPhotoMode && !isRecording
        ? Colors.white
        : const Color(0xFFFE2C55);

    return GestureDetector(
      onTap: isBusy ? null : onTap,
      onLongPressStart: isBusy ? null : onLongPressStart,
      onLongPressEnd: isBusy ? null : onLongPressEnd,
      child: SizedBox(
        width: 94,
        height: 94,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isRecording)
              SizedBox(
                width: 94,
                height: 94,
                child: CircularProgressIndicator(
                  value: progress.clamp(0, 1),
                  strokeWidth: 3,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4.5),
              ),
            ),
            // Always use rectangle + borderRadius (never shape:circle) so
            // AnimatedContainer's decoration lerp never hits Flutter's
            // "A circle cannot have a border radius" assert while recording.
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isRecording ? 34 : 66,
              height: isRecording ? 34 : 66,
              decoration: BoxDecoration(
                color: innerColor,
                borderRadius: BorderRadius.circular(isRecording ? 6 : 33),
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
    this.showUpload = true,
    this.selectedEffect,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.showEffectsTool = true,
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
  final bool showUpload;
  final CameraEffectDefinition? selectedEffect;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final bool showEffectsTool;

  @override
  Widget build(BuildContext context) {
    if (isLiveMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: CameraGoLiveButton(label: goLiveLabel, onTap: onGoLiveTap),
      );
    }

    final hasEffect =
        selectedEffect != null && !selectedEffect!.isNone;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showEffectsTool)
            CameraEffectsTool(
              onTap: onEffectsTap,
              label: effectsLabel,
              emoji: selectedEffect?.emoji,
              assetUrl: selectedEffect?.assetUrl,
              previewColor: selectedEffect?.previewColor,
              hasSelection: hasEffect,
            )
          else
            const SizedBox(width: 72),
          Expanded(
            child: Center(
              child: CameraRecordButton(
                isRecording: isRecording,
                isBusy: isBusy,
                progress: recordProgress,
                isPhotoMode: isPhotoMode,
                onTap: onRecordTap,
                onLongPressStart: onLongPressStart,
                onLongPressEnd: onLongPressEnd,
              ),
            ),
          ),
          if (showUpload)
            CameraGalleryTool(
              onTap: onUploadTap,
              label: uploadLabel,
            )
          else
            const SizedBox(width: 72),
        ],
      ),
    );
  }
}
