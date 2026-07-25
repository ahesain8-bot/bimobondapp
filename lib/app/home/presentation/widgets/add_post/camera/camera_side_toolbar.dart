import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_layout_picker.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_speed_picker.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_tool_icons.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CameraSideToolbarLabels {
  const CameraSideToolbarLabels({
    required this.flash,
    required this.timer,
    required this.layout,
    required this.aspectRatio,
    required this.beauty,
    required this.filters,
    required this.speed,
    required this.switchCamera,
  });

  final String flash;
  final String timer;
  final String layout;
  final String aspectRatio;
  final String beauty;
  final String filters;
  final String speed;
  final String switchCamera;
}

class _SideToolItem {
  const _SideToolItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.showActiveBadge,
    this.badge,
    this.layoutMode,
    this.dimmed = false,
    this.iconOnly = false,
    this.isSeparator = false,
    this.customIcon,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool? showActiveBadge;
  final String? badge;
  final CameraLayoutMode? layoutMode;
  final bool dimmed;
  final bool iconOnly;
  final bool isSeparator;
  final Widget? customIcon;
}

class CameraSideToolbar extends StatefulWidget {
  const CameraSideToolbar({
    super.key,
    required this.onFlip,
    required this.onFlash,
    required this.onTimer,
    required this.onLayout,
    required this.onAspectRatio,
    required this.onBeauty,
    required this.onFilters,
    required this.onSpeed,
    required this.flashEnabled,
    required this.beautyEnabled,
    required this.filtersEnabled,
    required this.timerEnabled,
    required this.speedLabel,
    this.showSpeed = true,
    this.speedEnabled = true,
    this.showAspectRatio = true,
    this.aspectRatioEnabled = true,
    required this.labels,
    this.ratioLetterboxed = false,
    this.selectedLayoutMode = CameraLayoutMode.off,
    this.layoutPickerOpen = false,
    this.onLayoutModeSelected,
    this.speedPickerOpen = false,
    this.selectedSpeed = 1.0,
    this.onSpeedSelected,
    this.offLabel = 'Off',
    this.iconOnStartEdge = true,
    this.collapsedCount = 6,
    this.showFlip = true,
  });

  final VoidCallback onFlip;
  final VoidCallback onFlash;
  final VoidCallback onTimer;
  final VoidCallback onLayout;
  final VoidCallback onAspectRatio;
  final VoidCallback onBeauty;
  final VoidCallback onFilters;
  final VoidCallback onSpeed;
  final bool flashEnabled;
  final bool beautyEnabled;
  final bool filtersEnabled;
  final bool timerEnabled;
  final String speedLabel;
  final bool showSpeed;
  final bool speedEnabled;
  final bool showAspectRatio;
  final bool aspectRatioEnabled;
  final CameraSideToolbarLabels labels;
  final bool ratioLetterboxed;
  final CameraLayoutMode selectedLayoutMode;
  final bool layoutPickerOpen;
  final ValueChanged<CameraLayoutMode>? onLayoutModeSelected;
  final bool speedPickerOpen;
  final double selectedSpeed;
  final ValueChanged<double>? onSpeedSelected;
  final String offLabel;
  final bool iconOnStartEdge;
  final int collapsedCount;
  final bool showFlip;

  @override
  State<CameraSideToolbar> createState() => _CameraSideToolbarState();
}

class _CameraSideToolbarState extends State<CameraSideToolbar> {
  bool _expanded = false;

  static const _rowStride = 54.0;
  static const _layoutRowIndex = 4;
  static const _speedRowIndex = 6;
  static const _iconRailWidth = 48.0;
  static const _popupGap = 10.0;
  static const _popupHeight = 244.0;
  static const _speedPopupHeight = 220.0;

  bool get _layoutActive => widget.selectedLayoutMode != CameraLayoutMode.off;

  @override
  void didUpdateWidget(covariant CameraSideToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speedPickerOpen && !oldWidget.speedPickerOpen && !_expanded) {
      _expanded = true;
    }
  }

  List<_SideToolItem> get _allTools => [
        if (widget.showFlip)
          _SideToolItem(
            icon: LucideIcons.switchCamera,
            label: widget.labels.switchCamera,
            onTap: widget.onFlip,
            iconOnly: true,
            customIcon: TikTokSideIcons.flip(),
          ),
        _SideToolItem(
          icon: widget.flashEnabled ? LucideIcons.zap : LucideIcons.zapOff,
          label: widget.labels.flash,
          onTap: widget.onFlash,
          active: widget.flashEnabled,
          showActiveBadge: false,
          iconOnly: true,
        ),
        const _SideToolItem(
          icon: Icons.remove,
          label: '',
          onTap: _noop,
          isSeparator: true,
        ),
        _SideToolItem(
          icon: LucideIcons.timer,
          label: widget.labels.timer,
          onTap: widget.onTimer,
          active: widget.timerEnabled,
          showActiveBadge: false,
          customIcon: TikTokSideIcons.timer(),
        ),
        _SideToolItem(
          icon: LucideIcons.columns2,
          label: widget.labels.layout,
          onTap: widget.onLayout,
          active: _layoutActive || widget.layoutPickerOpen,
          showActiveBadge: _layoutActive,
          layoutMode: widget.selectedLayoutMode,
          customIcon: _railSvg(AppAssets.cameraLayoutIcon),
        ),
        _SideToolItem(
          icon: Icons.face_retouching_natural,
          label: widget.labels.beauty,
          onTap: widget.onBeauty,
          active: widget.beautyEnabled,
          showActiveBadge: false,
          customIcon: TikTokSideIcons.retouch(),
        ),
        _SideToolItem(
          icon: LucideIcons.blend,
          label: widget.labels.filters,
          onTap: widget.onFilters,
          active: widget.filtersEnabled,
          showActiveBadge: false,
          customIcon: _railSvg(AppAssets.cameraFiltersIcon),
        ),
        if (widget.showSpeed)
          _SideToolItem(
            icon: LucideIcons.gauge,
            label: widget.labels.speed,
            badge: widget.speedLabel,
            onTap: widget.speedEnabled ? widget.onSpeed : _noop,
            active: widget.speedPickerOpen,
            dimmed: !widget.speedEnabled,
          ),
        if (widget.showAspectRatio)
          _SideToolItem(
            icon: LucideIcons.ratio,
            label: widget.labels.aspectRatio,
            onTap: widget.aspectRatioEnabled ? widget.onAspectRatio : () {},
            active: widget.ratioLetterboxed && widget.aspectRatioEnabled,
            dimmed: !widget.aspectRatioEnabled,
          ),
      ];

  static void _noop() {}

  static Widget _railSvg(String asset, {double size = 30}) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }

  bool get _hasMore {
    final toolCount = _allTools.where((t) => !t.isSeparator).length;
    return toolCount > widget.collapsedCount;
  }

  @override
  Widget build(BuildContext context) {
    final align = widget.iconOnStartEdge
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end;

    final alwaysVisible = <_SideToolItem>[];
    final overflow = <_SideToolItem>[];
    var toolsSeen = 0;
    for (final tool in _allTools) {
      if (tool.isSeparator) {
        if (toolsSeen > 0 && toolsSeen <= widget.collapsedCount) {
          alwaysVisible.add(tool);
        }
        continue;
      }
      if (toolsSeen < widget.collapsedCount) {
        alwaysVisible.add(tool);
      } else {
        overflow.add(tool);
      }
      toolsSeen++;
    }

    // Keep LTR so [iconOnStartEdge] is not flipped again by ambient RTL.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CameraRailExpandedBackdrop(
            expanded: _expanded,
            iconOnStartEdge: widget.iconOnStartEdge,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: align,
            children: [
              for (final tool in alwaysVisible)
                tool.isSeparator
                    ? _SideRailSeparator(
                        iconOnStartEdge: widget.iconOnStartEdge,
                      )
                    : _buildToolRow(tool),
              if (overflow.isNotEmpty)
                ClipRect(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 480),
                    curve: Curves.easeInOutCubic,
                    alignment: widget.iconOnStartEdge
                        ? Alignment.topLeft
                        : Alignment.topRight,
                    heightFactor: _expanded ? 1.0 : 0.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: align,
                      children: [
                        for (final tool in overflow) _buildToolRow(tool),
                      ],
                    ),
                  ),
                ),
              if (_hasMore)
                CameraRailExpandButton(
                  expanded: _expanded,
                  iconOnStartEdge: widget.iconOnStartEdge,
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),
          if (widget.layoutPickerOpen && widget.onLayoutModeSelected != null)
            Positioned(
              top: _layoutPopupTop,
              left: widget.iconOnStartEdge
                  ? _iconRailWidth + _popupGap
                  : null,
              right: widget.iconOnStartEdge
                  ? null
                  : _iconRailWidth + _popupGap,
              child: CameraLayoutPickerPopup(
                selected: widget.selectedLayoutMode,
                offLabel: widget.offLabel,
                onSelected: widget.onLayoutModeSelected!,
              ),
            ),
          if (widget.showSpeed &&
              widget.speedPickerOpen &&
              widget.onSpeedSelected != null)
            Positioned(
              top: _speedPopupTop,
              left: widget.iconOnStartEdge
                  ? _iconRailWidth + _popupGap
                  : null,
              right: widget.iconOnStartEdge
                  ? null
                  : _iconRailWidth + _popupGap,
              child: CameraSpeedPickerPopup(
                selectedSpeed: widget.selectedSpeed,
                onSelected: widget.onSpeedSelected!,
              ),
            ),
        ],
      ),
    );
  }

  double get _layoutPopupTop =>
      _layoutRowIndex * _rowStride + (_rowStride / 2) - (_popupHeight / 2);

  double get _speedPopupTop =>
      _speedRowIndex * _rowStride +
      (_rowStride / 2) -
      (_speedPopupHeight / 2);

  Widget _buildToolRow(_SideToolItem tool) {
    final row = CameraRailToolRow(
      icon: tool.icon,
      label: tool.label,
      onTap: tool.onTap,
      active: tool.active,
      showActiveBadge: tool.showActiveBadge,
      badge: tool.customIcon != null ? null : tool.badge,
      iconOnStartEdge: widget.iconOnStartEdge,
      showLabel: _expanded &&
          !tool.iconOnly &&
          !widget.layoutPickerOpen &&
          !widget.speedPickerOpen,
      customIcon: tool.layoutMode != null &&
              tool.layoutMode != CameraLayoutMode.off
          ? CameraLayoutIcon(
              mode: tool.layoutMode!,
              color: Colors.white,
              size: 30,
            )
          : tool.customIcon,
    );
    if (tool.dimmed) {
      return Opacity(opacity: 0.4, child: row);
    }
    return row;
  }
}

class CameraSideRailSeparator extends StatelessWidget {
  const CameraSideRailSeparator({super.key, required this.iconOnStartEdge});

  final bool iconOnStartEdge;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: iconOnStartEdge ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 26,
        height: 1.2,
        margin: EdgeInsets.only(
          top: 2,
          bottom: 8,
          left: iconOnStartEdge ? 11 : 0,
          right: iconOnStartEdge ? 0 : 11,
        ),
        color: Colors.white.withValues(alpha: 0.4),
      ),
    );
  }
}

class _SideRailSeparator extends CameraSideRailSeparator {
  const _SideRailSeparator({required super.iconOnStartEdge});
}

class CameraRailExpandButton extends StatelessWidget {
  const CameraRailExpandButton({
    super.key,
    required this.expanded,
    required this.onTap,
    this.iconOnStartEdge = true,
    this.compact = false,
  });

  final bool expanded;
  final VoidCallback onTap;
  final bool iconOnStartEdge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: iconOnStartEdge ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.only(
            top: compact ? 0 : 4,
            left: iconOnStartEdge ? 12 : 0,
            right: iconOnStartEdge ? 0 : 12,
          ),
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
            turns: expanded ? 0.5 : 0,
            child: const Icon(
              LucideIcons.chevronDown,
              color: Colors.white,
              size: 24,
              shadows: CameraToolIcons.iconShadows,
            ),
          ),
        ),
      ),
    );
  }
}
