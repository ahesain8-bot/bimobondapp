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
    required String? selectedEffectSlug,
    required ValueChanged<String?> onSelected,
  }) {
    GlassBottomSheet.showContent(
      context,
      title: l10n.cameraEffects,
      child: CameraEffectsPickerStrip(
        effects: CameraEffectsCatalog.trending,
        selected: selectedEffectSlug,
        labelBuilder: (effect) => CameraEffectsCatalog.label(l10n, effect),
        onSelected: (effect) {
          onSelected(effect.isNone ? null : effect.slug);
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

  static Future<void> showCountdownSheet(
    BuildContext context, {
    required AppLocalizations l10n,
    required int initialCountdownSeconds,
    required bool timerEnabled,
    required ValueChanged<int> onStart,
    required VoidCallback onTurnOff,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _CountdownSheetBody(
          l10n: l10n,
          initialCountdownSeconds: initialCountdownSeconds,
          timerEnabled: timerEnabled,
          onStart: onStart,
          onTurnOff: onTurnOff,
        );
      },
    );
  }
}

class _CountdownSheetBody extends StatefulWidget {
  const _CountdownSheetBody({
    required this.l10n,
    required this.initialCountdownSeconds,
    required this.timerEnabled,
    required this.onStart,
    required this.onTurnOff,
  });

  final AppLocalizations l10n;
  final int initialCountdownSeconds;
  final bool timerEnabled;
  final ValueChanged<int> onStart;
  final VoidCallback onTurnOff;

  @override
  State<_CountdownSheetBody> createState() => _CountdownSheetBodyState();
}

class _CountdownSheetBodyState extends State<_CountdownSheetBody> {
  // 0 = Off, otherwise countdown seconds (3 or 10).
  late int _countdownSeconds;

  @override
  void initState() {
    super.initState();
    if (!widget.timerEnabled) {
      _countdownSeconds = 0;
    } else {
      _countdownSeconds = widget.initialCountdownSeconds == 10 ? 10 : 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.l10n.cameraSetCountdown,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _CountdownSegment(
                selected: _countdownSeconds,
                offLabel: widget.l10n.settingsOff,
                onChanged: (v) => setState(() => _countdownSeconds = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  if (_countdownSeconds == 0) {
                    widget.onTurnOff();
                  } else {
                    widget.onStart(_countdownSeconds);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _countdownSeconds == 0
                          ? widget.l10n.settingsOff
                          : widget.l10n.cameraStartCountdown,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownSegment extends StatelessWidget {
  const _CountdownSegment({
    required this.selected,
    required this.offLabel,
    required this.onChanged,
  });

  final int selected;
  final String offLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(0, offLabel),
          _seg(3, '3s'),
          _seg(10, '10s'),
        ],
      ),
    );
  }

  Widget _seg(int seconds, String label) {
    final active = selected == seconds;
    return GestureDetector(
      onTap: () => onChanged(seconds),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
