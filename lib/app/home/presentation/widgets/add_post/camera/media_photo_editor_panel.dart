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

/// Bottom panel: Face / Makeup tabs + circular tools (Magic, Smooth + adjustments).
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

  bool get _showSlider =>
      widget.tab == MediaPhotoEditorTab.face &&
      _bipolarTools.contains(widget.selectedTool);

  double get _labelAlignX => _localValue;

  String get _sliderLabel => '${(_localValue * 100).round()}';

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
    return Material(
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
              if (_showSlider) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment(_labelAlignX, 0),
                        child: Text(
                          _sliderLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          activeTrackColor: const Color(0xFFE11D48),
                          inactiveTrackColor: Colors.white38,
                          thumbColor: Colors.white,
                          overlayColor: const Color(0x33E11D48),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          value: _localValue,
                          min: -1.0,
                          max: 1.0,
                          onChanged: _onSliderDrag,
                          onChangeEnd: _onSliderDragEnd,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
              ] else
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    widget.l10n.mediaEditorComingSoon,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
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
