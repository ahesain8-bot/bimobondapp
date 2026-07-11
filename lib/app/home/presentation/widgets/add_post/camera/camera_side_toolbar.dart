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
    required this.zoom,
  });

  final String flash;
  final String timer;
  final String layout;
  final String aspectRatio;
  final String beauty;
  final String filters;
  final String speed;
  final String zoom;
}

class _SideToolItem {
  const _SideToolItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final String? badge;
}

/// TikTok-style side rail (physical left in RTL, physical right in LTR).
class CameraSideToolbar extends StatefulWidget {
  const CameraSideToolbar({
    super.key,
    required this.onFlash,
    required this.onTimer,
    required this.onLayout,
    required this.onAspectRatio,
    required this.onBeauty,
    required this.onFilters,
    required this.onSpeed,
    required this.onZoom,
    required this.beautyEnabled,
    required this.filtersEnabled,
    required this.timerEnabled,
    required this.speedLabel,
    required this.labels,
    this.iconOnStartEdge = true,
    this.collapsedCount = 5,
  });

  final VoidCallback onFlash;
  final VoidCallback onTimer;
  final VoidCallback onLayout;
  final VoidCallback onAspectRatio;
  final VoidCallback onBeauty;
  final VoidCallback onFilters;
  final VoidCallback onSpeed;
  final VoidCallback onZoom;
  final bool beautyEnabled;
  final bool filtersEnabled;
  final bool timerEnabled;
  final String speedLabel;
  final CameraSideToolbarLabels labels;
  final bool iconOnStartEdge;
  final int collapsedCount;

  @override
  State<CameraSideToolbar> createState() => _CameraSideToolbarState();
}

class _CameraSideToolbarState extends State<CameraSideToolbar> {
  bool _expanded = false;

  List<_SideToolItem> get _allTools => [
        _SideToolItem(
          icon: LucideIcons.wandSparkles,
          label: widget.labels.flash,
          onTap: widget.onFlash,
        ),
        _SideToolItem(
          icon: LucideIcons.timer,
          label: widget.labels.timer,
          onTap: widget.onTimer,
          active: widget.timerEnabled,
        ),
        _SideToolItem(
          icon: LucideIcons.layoutGrid,
          label: widget.labels.layout,
          onTap: widget.onLayout,
        ),
        _SideToolItem(
          icon: LucideIcons.ratio,
          label: widget.labels.aspectRatio,
          onTap: widget.onAspectRatio,
        ),
        _SideToolItem(
          icon: LucideIcons.sparkles,
          label: widget.labels.beauty,
          onTap: widget.onBeauty,
          active: widget.beautyEnabled,
        ),
        _SideToolItem(
          icon: LucideIcons.palette,
          label: widget.labels.filters,
          onTap: widget.onFilters,
          active: widget.filtersEnabled,
        ),
        _SideToolItem(
          icon: LucideIcons.gauge,
          label: widget.labels.speed,
          badge: widget.speedLabel,
          onTap: widget.onSpeed,
        ),
        _SideToolItem(
          icon: LucideIcons.zoomIn,
          label: widget.labels.zoom,
          onTap: widget.onZoom,
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

    return Column(
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
              for (final tool in visible)
                CameraRailToolRow(
                  icon: tool.icon,
                  label: tool.label,
                  onTap: tool.onTap,
                  active: tool.active,
                  badge: tool.badge,
                  iconOnStartEdge: widget.iconOnStartEdge,
                ),
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
    );
  }
}

/// Chevron to expand/collapse the side tool rail.
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

/// @deprecated Use [CameraRailTool] from camera_tool_icons.dart.
class CameraSideTool extends StatelessWidget {
  const CameraSideTool({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return CameraRailTool(
      icon: icon,
      label: caption ?? label,
      onTap: onTap,
      active: active,
    );
  }
}
