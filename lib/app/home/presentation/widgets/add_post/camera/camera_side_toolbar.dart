import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_layout_picker.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_tool_icons.dart';
import 'package:flutter/material.dart';
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool? showActiveBadge;
  final String? badge;
  final CameraLayoutMode? layoutMode;
  final bool dimmed;

  /// Stays icon-only even when the rail is expanded (Flash / Switch Camera).
  final bool iconOnly;
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
    this.showAspectRatio = true,
    this.aspectRatioEnabled = true,
    required this.labels,
    this.ratioLetterboxed = false,
    this.selectedLayoutMode = CameraLayoutMode.off,
    this.layoutPickerOpen = false,
    this.onLayoutModeSelected,
    this.offLabel = 'Off',
    this.iconOnStartEdge = true,
    this.collapsedCount = 6,
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
  final bool showAspectRatio;
  final bool aspectRatioEnabled;
  final CameraSideToolbarLabels labels;
  final bool ratioLetterboxed;
  final CameraLayoutMode selectedLayoutMode;
  final bool layoutPickerOpen;
  final ValueChanged<CameraLayoutMode>? onLayoutModeSelected;
  final String offLabel;
  final bool iconOnStartEdge;
  final int collapsedCount;

  @override
  State<CameraSideToolbar> createState() => _CameraSideToolbarState();
}

class _CameraSideToolbarState extends State<CameraSideToolbar> {
  bool _expanded = false;

  static const _rowStride = 54.0;
  // Switch-camera sits first now, so Layout is the 4th row (index 3).
  static const _layoutRowIndex = 3;
  // Icons hug one edge of the 122px-wide rail and are only ~40px wide; anchor
  // the popup to the icon (not the full rail width) so it opens right next to
  // the button instead of drifting toward the screen center.
  static const _iconRailWidth = 44.0;
  static const _popupGap = 10.0;
  static const _popupHeight = 244.0;

  bool get _layoutActive => widget.selectedLayoutMode != CameraLayoutMode.off;

  List<_SideToolItem> get _allTools => [
        _SideToolItem(
          icon: LucideIcons.switchCamera,
          label: widget.labels.switchCamera,
          onTap: widget.onFlip,
          iconOnly: true,
        ),
        _SideToolItem(
          icon: LucideIcons.zap,
          label: widget.labels.flash,
          onTap: widget.onFlash,
          active: widget.flashEnabled,
          iconOnly: true,
        ),
        _SideToolItem(
          icon: LucideIcons.timer,
          label: widget.labels.timer,
          onTap: widget.onTimer,
          active: widget.timerEnabled,
        ),
        // Layout temporarily hidden (photo + video). Uncomment to restore.
        // _SideToolItem(
        //   icon: LucideIcons.layoutGrid,
        //   label: widget.labels.layout,
        //   onTap: widget.onLayout,
        //   active: _layoutActive || widget.layoutPickerOpen,
        //   showActiveBadge: _layoutActive,
        //   layoutMode: widget.selectedLayoutMode,
        // ),
        if (widget.showAspectRatio)
          _SideToolItem(
            icon: LucideIcons.ratio,
            label: widget.labels.aspectRatio,
            onTap: widget.aspectRatioEnabled ? widget.onAspectRatio : () {},
            active: widget.ratioLetterboxed && widget.aspectRatioEnabled,
            dimmed: !widget.aspectRatioEnabled,
          ),
        // _SideToolItem(
        //   icon: LucideIcons.sparkles,
        //   label: widget.labels.beauty,
        //   onTap: widget.onBeauty,
        //   active: widget.beautyEnabled,
        // ),
        _SideToolItem(
          icon: LucideIcons.palette,
          label: widget.labels.filters,
          onTap: widget.onFilters,
          active: widget.filtersEnabled,
        ),
        if (widget.showSpeed)
          _SideToolItem(
            icon: LucideIcons.gauge,
            label: widget.labels.speed,
            badge: widget.speedLabel,
            onTap: widget.onSpeed,
          ),
      ];

  List<_SideToolItem> get _visibleTools {
    if (_expanded) return _allTools;
    return _allTools.take(widget.collapsedCount).toList(growable: false);
  }

  bool get _hasMore => _allTools.length > widget.collapsedCount;

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTools;
    final align = widget.iconOnStartEdge
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end;

    // Force LTR inside the rail so the manual [iconOnStartEdge] flag is the
    // single source of truth for which edge the icons hug. Without this, an
    // ambient RTL (Arabic) locale flips every start/end alignment a second
    // time and the icons end up on the wrong (inner) edge.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: align,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: widget.iconOnStartEdge
                  ? Alignment.topLeft
                  : Alignment.topRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: align,
                children: [
                  for (final tool in visible) _buildToolRow(tool),
                ],
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
        ],
      ),
    );
  }

  double get _layoutPopupTop =>
      _layoutRowIndex * _rowStride + (_rowStride / 2) - (_popupHeight / 2);

  Widget _buildToolRow(_SideToolItem tool) {
    final row = CameraRailToolRow(
      icon: tool.icon,
      label: tool.label,
      onTap: tool.onTap,
      active: tool.active,
      showActiveBadge: tool.showActiveBadge,
      badge: tool.badge,
      iconOnStartEdge: widget.iconOnStartEdge,
      // Show the caption when the rail is expanded, except for icon-only tools
      // (Flash / Switch Camera).
      showLabel: _expanded && !tool.iconOnly,
      customIcon: tool.layoutMode != null && tool.layoutMode != CameraLayoutMode.off
          ? CameraLayoutIcon(
              mode: tool.layoutMode!,
              color: Colors.white,
              size: 26,
            )
          : null,
    );
    if (tool.dimmed) {
      return Opacity(opacity: 0.4, child: row);
    }
    return row;
  }
}

class CameraRailExpandButton extends StatelessWidget {
  const CameraRailExpandButton({
    super.key,
    required this.expanded,
    required this.onTap,
    this.iconOnStartEdge = true,
  });

  final bool expanded;
  final VoidCallback onTap;
  final bool iconOnStartEdge;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: iconOnStartEdge ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 28,
          height: 28,
          margin: EdgeInsets.only(
            top: 2,
            left: iconOnStartEdge ? 6 : 0,
            right: iconOnStartEdge ? 0 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Icon(
            expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            color: Colors.white.withValues(alpha: 0.9),
            size: 14,
          ),
        ),
      ),
    );
  }
}
