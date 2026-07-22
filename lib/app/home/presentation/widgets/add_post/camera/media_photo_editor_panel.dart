import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_l10n.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Which Face tool is selected in the TikTok-style photo editor panel.
enum MediaPhotoEditorTool {
  magic,
  saturation,
  brightness,
  contrast,
  exposure,
  whiteBalance,
  highlights,
  shadows,
  nose,
}

/// Bipolar adjustment tools (slider -1…1, 0 = original).
const Set<MediaPhotoEditorTool> _bipolarTools = {
  MediaPhotoEditorTool.saturation,
  MediaPhotoEditorTool.brightness,
  MediaPhotoEditorTool.contrast,
  MediaPhotoEditorTool.exposure,
  MediaPhotoEditorTool.whiteBalance,
  MediaPhotoEditorTool.highlights,
  MediaPhotoEditorTool.shadows,
  MediaPhotoEditorTool.nose,
};

enum MediaPhotoEditorTab {
  face,
  makeup,
}

/// Film color-grade category shown under Makeup.
const String kMediaPhotoEditorFilmCategoryId = 'film';

/// Bottom panel: Face / Makeup tabs + circular tools (Magic + adjustments / Film filters).
class MediaPhotoEditorPanel extends StatefulWidget {
  const MediaPhotoEditorPanel({
    super.key,
    required this.l10n,
    required this.tab,
    required this.selectedTool,
    required this.magicOn,
    required this.adjustmentValues,
    required this.onTabChanged,
    required this.onToolSelected,
    required this.onMagicToggled,
    required this.onAdjustmentChanged,
    required this.onReset,
    this.selectedColorFilterId = 'none',
    this.colorFilterIntensity = 1.0,
    this.onColorFilterSelected,
    this.onColorFilterIntensityChanged,
  });

  final AppLocalizations l10n;
  final MediaPhotoEditorTab tab;
  final MediaPhotoEditorTool selectedTool;
  final bool magicOn;

  /// Bipolar adjustment values (-1…1) keyed by tool.
  final Map<MediaPhotoEditorTool, double> adjustmentValues;

  final ValueChanged<MediaPhotoEditorTab> onTabChanged;
  final ValueChanged<MediaPhotoEditorTool> onToolSelected;
  final VoidCallback onMagicToggled;
  final void Function(MediaPhotoEditorTool tool, double value) onAdjustmentChanged;
  final VoidCallback onReset;

  /// Selected AR color filter id (`none` or a film-catalog id).
  final String selectedColorFilterId;
  final double colorFilterIntensity;
  final ValueChanged<String>? onColorFilterSelected;
  final ValueChanged<double>? onColorFilterIntensityChanged;

  @override
  State<MediaPhotoEditorPanel> createState() => _MediaPhotoEditorPanelState();
}

class _MediaPhotoEditorPanelState extends State<MediaPhotoEditorPanel> {
  double _localValue = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _localValue = _valueFromWidget(widget.selectedTool);
  }

  @override
  void didUpdateWidget(covariant MediaPhotoEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging) return;
    if (oldWidget.selectedTool != widget.selectedTool ||
        _valueFromWidget(widget.selectedTool) != _localValue) {
      _localValue = _valueFromWidget(widget.selectedTool);
    }
  }

  double _valueFromWidget(MediaPhotoEditorTool tool) {
    if (_bipolarTools.contains(tool)) {
      return (widget.adjustmentValues[tool] ?? 0).clamp(-1.0, 1.0);
    }
    return 0;
  }

  bool get _isFilmFilterSelected {
    final id = widget.selectedColorFilterId;
    if (id == 'none' || !ArFilterCatalog.isColorFilter(id)) return false;
    return ArFilterCatalog.colorItemsForCategory(kMediaPhotoEditorFilmCategoryId)
        .any((f) => f.id == id);
  }

  bool get _showFaceSlider =>
      widget.tab == MediaPhotoEditorTab.face &&
      _bipolarTools.contains(widget.selectedTool);

  bool get _showMakeupIntensity =>
      widget.tab == MediaPhotoEditorTab.makeup &&
      _isFilmFilterSelected &&
      widget.onColorFilterIntensityChanged != null;

  void _emit(double value) {
    widget.onAdjustmentChanged(widget.selectedTool, value);
  }

  void _onSliderDrag(double value) {
    setState(() {
      _dragging = true;
      _localValue = value;
    });
    _emit(value);
  }

  void _onSliderDragEnd(double value) {
    setState(() {
      _dragging = false;
      _localValue = value;
    });
    _emit(value);
  }

  @override
  Widget build(BuildContext context) {
    // Slider sits above the dark sheet (in the camera/preview area).
    // Sheet itself only holds tabs + tool/filter chips.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showFaceSlider)
          _FloatingBipolarSlider(
            value: _localValue,
            onChanged: _onSliderDrag,
            onChangeEnd: _onSliderDragEnd,
          )
        else if (_showMakeupIntensity)
          _FloatingIntensitySlider(
            value: widget.colorFilterIntensity,
            onChanged: widget.onColorFilterIntensityChanged!,
          ),
        Material(
          color: Colors.black.withValues(alpha: 0.92),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Header(
                    l10n: widget.l10n,
                    tab: widget.tab,
                    onTabChanged: widget.onTabChanged,
                    onReset: widget.onReset,
                  ),
                  const SizedBox(height: 14),
                  if (widget.tab == MediaPhotoEditorTab.face)
                    _FaceToolsRow(
                      l10n: widget.l10n,
                      selectedTool: widget.selectedTool,
                      magicOn: widget.magicOn,
                      adjustmentValues: widget.adjustmentValues,
                      onToolSelected: widget.onToolSelected,
                      onMagicToggled: widget.onMagicToggled,
                    )
                  else
                    _FilmFiltersRow(
                      l10n: widget.l10n,
                      selectedFilterId: widget.selectedColorFilterId,
                      onFilterSelected: widget.onColorFilterSelected ?? (_) {},
                    ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingBipolarSlider extends StatelessWidget {
  const _FloatingBipolarSlider({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final label = '${(value * 100).round()}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment(value.clamp(-1.0, 1.0), 0),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              activeTrackColor: const Color(0xFFE11D48),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.45),
              thumbColor: Colors.white,
              overlayColor: const Color(0x33E11D48),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.clamp(-1.0, 1.0),
              min: -1.0,
              max: 1.0,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingIntensitySlider extends StatelessWidget {
  const _FloatingIntensitySlider({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final label = '${(clamped * 100).round()}';
    // Same pink/white look as the Face adjustment slider.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment((clamped * 2) - 1, 0),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              activeTrackColor: const Color(0xFFE11D48),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.45),
              thumbColor: Colors.white,
              overlayColor: const Color(0x33E11D48),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: clamped,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.l10n,
    required this.tab,
    required this.onTabChanged,
    required this.onReset,
  });

  final AppLocalizations l10n;
  final MediaPhotoEditorTab tab;
  final ValueChanged<MediaPhotoEditorTab> onTabChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabLabel(
          label: l10n.mediaPhotoEditorFace,
          selected: tab == MediaPhotoEditorTab.face,
          onTap: () => onTabChanged(MediaPhotoEditorTab.face),
        ),
        const SizedBox(width: 18),
        _TabLabel(
          label: l10n.mediaPhotoEditorMakeup,
          selected: tab == MediaPhotoEditorTab.makeup,
          onTap: () => onTabChanged(MediaPhotoEditorTab.makeup),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onReset,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.rotateCcw, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                l10n.mediaEditorReset,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 28,
            height: 2.5,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE11D48) : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceToolsRow extends StatelessWidget {
  const _FaceToolsRow({
    required this.l10n,
    required this.selectedTool,
    required this.magicOn,
    required this.adjustmentValues,
    required this.onToolSelected,
    required this.onMagicToggled,
  });

  final AppLocalizations l10n;
  final MediaPhotoEditorTool selectedTool;
  final bool magicOn;
  final Map<MediaPhotoEditorTool, double> adjustmentValues;
  final ValueChanged<MediaPhotoEditorTool> onToolSelected;
  final VoidCallback onMagicToggled;

  bool _active(MediaPhotoEditorTool tool) =>
      (adjustmentValues[tool] ?? 0).abs() > 0.02;

  @override
  Widget build(BuildContext context) {
    final adjustTools = <_AdjustToolSpec>[
      _AdjustToolSpec(
        MediaPhotoEditorTool.saturation,
        LucideIcons.palette,
        l10n.mediaPhotoEditorSaturation,
      ),
      _AdjustToolSpec(
        MediaPhotoEditorTool.brightness,
        LucideIcons.sun,
        l10n.mediaPhotoEditorBrightness,
      ),
      _AdjustToolSpec(
        MediaPhotoEditorTool.contrast,
        LucideIcons.contrast,
        l10n.mediaPhotoEditorContrast,
      ),
      _AdjustToolSpec(
        MediaPhotoEditorTool.exposure,
        LucideIcons.aperture,
        l10n.mediaPhotoEditorExposure,
      ),
      _AdjustToolSpec(
        MediaPhotoEditorTool.whiteBalance,
        LucideIcons.thermometer,
        l10n.mediaPhotoEditorWhiteBalance,
      ),
      _AdjustToolSpec(
        MediaPhotoEditorTool.highlights,
        LucideIcons.sunDim,
        l10n.mediaPhotoEditorHighlights,
      ),
      _AdjustToolSpec(
        MediaPhotoEditorTool.shadows,
        LucideIcons.moon,
        l10n.mediaPhotoEditorShadows,
      ),
      _AdjustToolSpec(
        MediaPhotoEditorTool.nose,
        LucideIcons.scanFace,
        l10n.mediaPhotoEditorNose,
      ),
    ];

    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _ToolChip(
            icon: LucideIcons.wandSparkles,
            label: magicOn ? l10n.mediaPhotoEditorOn : l10n.mediaPhotoEditorMagic,
            selected: selectedTool == MediaPhotoEditorTool.magic,
            activeBadge: magicOn,
            showDot: false,
            accentSelected: false,
            onTap: () {
              onToolSelected(MediaPhotoEditorTool.magic);
              onMagicToggled();
            },
          ),
          for (final spec in adjustTools) ...[
            const SizedBox(width: 14),
            _ToolChip(
              icon: spec.icon,
              label: spec.label,
              selected: selectedTool == spec.tool,
              activeBadge: false,
              showDot: _active(spec.tool),
              accentSelected: true,
              onTap: () => onToolSelected(spec.tool),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilmFiltersRow extends StatelessWidget {
  const _FilmFiltersRow({
    required this.l10n,
    required this.selectedFilterId,
    required this.onFilterSelected,
  });

  final AppLocalizations l10n;
  final String selectedFilterId;
  final ValueChanged<String> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final filters =
        ArFilterCatalog.colorItemsForCategory(kMediaPhotoEditorFilmCategoryId);
    final noneSelected = selectedFilterId == 'none' ||
        !filters.any((f) => f.id == selectedFilterId);

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _NoneChip(
              selected: noneSelected,
              onTap: () => onFilterSelected('none'),
            );
          }
          final item = filters[index - 1];
          final selected = item.id == selectedFilterId;
          return _FilmFilterChip(
            item: item,
            selected: selected,
            onTap: () => onFilterSelected(item.id),
          );
        },
      ),
    );
  }
}

class _NoneChip extends StatelessWidget {
  const _NoneChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2A2A2A),
                border: Border.all(
                  color: selected ? Colors.white : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Icon(
                LucideIcons.ban,
                color: selected ? Colors.white : Colors.white54,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.cameraFilterOriginal,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilmFilterChip extends StatelessWidget {
  const _FilmFilterChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ArFilterItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: selected ? 0.18 : 0.08),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFE11D48)
                      : Colors.white.withValues(alpha: 0.22),
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: ClipOval(child: _FilmThumbImage(item: item)),
            ),
            const SizedBox(height: 8),
            Text(
              arFilterLabel(l10n, item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFE11D48)
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilmThumbImage extends StatelessWidget {
  const _FilmThumbImage({required this.item});

  final ArFilterItem item;

  @override
  Widget build(BuildContext context) {
    final placeholderColor = _hexToColor(item.previewColorHex);
    final emojiFallback = ColoredBox(
      color: placeholderColor ?? const Color(0xFF2A2A2A),
      child: Center(
        child: Text(item.emoji, style: const TextStyle(fontSize: 22)),
      ),
    );

    if (!item.hasThumbnail) return emojiFallback;

    return Image.network(
      item.thumbnailUrl!,
      width: 54,
      height: 54,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: placeholderColor ?? Colors.white.withValues(alpha: 0.06),
        );
      },
      errorBuilder: (context, error, stack) => emojiFallback,
    );
  }

  static Color? _hexToColor(String? hex) {
    if (hex == null) return null;
    var value = hex.replaceFirst('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final intValue = int.tryParse(value, radix: 16);
    return intValue == null ? null : Color(intValue);
  }
}

class _AdjustToolSpec {
  const _AdjustToolSpec(this.tool, this.icon, this.label);

  final MediaPhotoEditorTool tool;
  final IconData icon;
  final String label;
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeBadge,
    required this.showDot,
    required this.accentSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool activeBadge;
  final bool showDot;
  final bool accentSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE11D48);
    final ringColor = selected
        ? (accentSelected ? accent : Colors.white)
        : null;
    final labelColor = selected && accentSelected ? accent : Colors.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2A2A2A),
                    border: ringColor != null
                        ? Border.all(color: ringColor, width: 2)
                        : null,
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                if (activeBadge)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            if (showDot)
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
