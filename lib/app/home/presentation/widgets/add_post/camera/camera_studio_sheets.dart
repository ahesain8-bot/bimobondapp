import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_bottom_controls.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_overlays.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CameraStudioSheets {
  CameraStudioSheets._();

  static const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  );

  static void showDurationPicker(
    BuildContext context, {
    required AppLocalizations l10n,
    required int selectedDuration,
    required ValueChanged<int> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: _sheetShape,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: CameraStudioConstants.durationOptions.map((seconds) {
              return ListTile(
                title: Text(
                  '$seconds ${l10n.cameraSeconds}',
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: selectedDuration == seconds
                    ? const Icon(Icons.check, color: Colors.redAccent)
                    : null,
                onTap: () {
                  onSelected(seconds);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  static void showSpeedPicker(
    BuildContext context, {
    required double selectedSpeed,
    required ValueChanged<double> onSelected,
  }) {
    GlassBottomSheet.showActions(
      context,
      children: CameraStudioConstants.speedOptions.map((speed) {
        return GlassBottomSheetListTile(
          label: '${speed}x',
          isSelected: selectedSpeed == speed,
          onTap: () {
            onSelected(speed);
            Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }

  static void showEffectsPicker(
    BuildContext context, {
    required AppLocalizations l10n,
    required CameraEffectId? selectedEffect,
    required ValueChanged<CameraEffectId?> onSelected,
  }) {
    GlassBottomSheet.showContent(
      context,
      title: l10n.cameraEffects,
      child: CameraEffectsPickerStrip(
        effects: CameraEffectsCatalog.trending,
        selected: selectedEffect,
        labelBuilder: (effect) => CameraEffectsCatalog.label(l10n, effect),
        onSelected: (effect) {
          onSelected(effect.isNone ? null : effect.id);
          Navigator.pop(context);
        },
      ),
    );
  }

  static void showLiveSetup(
    BuildContext context, {
    required AppLocalizations l10n,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: _sheetShape,
      builder: (sheetContext) {
        final titleController = TextEditingController();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: l10n.cameraLiveTitleHint,
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                CameraGoLiveButton(
                  label: l10n.cameraGoLive,
                  compact: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    PopupDialogs.showErrorDialog(
                      context,
                      l10n.cameraLiveComingSoon,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showMusicComingSoon(BuildContext context, String message) {
    PopupDialogs.showErrorDialog(context, message);
  }

  static Future<String?> showImportTypeSheet(
    BuildContext context, {
    required AppLocalizations l10n,
  }) {
    return GlassBottomSheet.open<String>(
      context,
      builder: (context) {
        return GlassBottomSheetShell(
          children: [
            GlassBottomSheetActionTile(
              icon: LucideIcons.image,
              label: l10n.imageFromLibrary,
              showChevron: false,
              onTap: () => Navigator.pop(context, 'image'),
            ),
            GlassBottomSheetActionTile(
              icon: LucideIcons.film,
              label: l10n.videoFromLibrary,
              showChevron: false,
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> pickFromLibrary(
    BuildContext context, {
    required AppLocalizations l10n,
    required void Function(List<GalleryMediaItem> items) onPicked,
    int limit = 5,
    bool chooseMediaType = false,
  }) async {
    try {
      final List<GalleryMediaItem> items;

      if (chooseMediaType) {
        final choice = await showImportTypeSheet(context, l10n: l10n);
        if (choice == null || !context.mounted) return;

        if (limit == 1) {
          items = choice == 'video'
              ? await MediaGalleryPicker.pickSingleVideo()
              : await MediaGalleryPicker.pickSingleImage();
        } else {
          items = choice == 'video'
              ? await MediaGalleryPicker.pickVideos(limit: limit)
              : await MediaGalleryPicker.pickImages(limit: limit);
        }
      } else {
        items = await MediaGalleryPicker.pickMixed(limit: limit);
      }

      if (items.isEmpty || !context.mounted) return;
      onPicked(items);
    } catch (e) {
      if (!context.mounted) return;
      PopupDialogs.showErrorDialog(
        context,
        l10n.cameraCaptureError(e.toString()),
      );
    }
  }
}
