import 'dart:io';

import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/core/constants/lives_layout_constants.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style music pill for the media editor top bar.
class MediaStudioSoundPill extends StatelessWidget {
  const MediaStudioSoundPill({
    super.key,
    required this.label,
    this.onTap,
    this.onClear,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsetsDirectional.only(
          start: 14,
          end: 10,
          top: 8,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.music2, color: Colors.white, size: 15),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(LucideIcons.x, color: Colors.white70, size: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MediaStudioTopBar extends StatelessWidget {
  const MediaStudioTopBar({
    super.key,
    required this.soundLabel,
    required this.onBack,
    required this.onSoundTap,
    required this.onSettingsTap,
    this.onClearSound,
  });

  final String soundLabel;
  final VoidCallback onBack;
  final VoidCallback onSoundTap;
  final VoidCallback onSettingsTap;
  final VoidCallback? onClearSound;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
          ),
          Expanded(
            child: Center(
              child: MediaStudioSoundPill(
                label: soundLabel,
                onTap: onSoundTap,
                onClear: onClearSound,
              ),
            ),
          ),
          IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(LucideIcons.settings, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class MediaStudioSideTool {
  const MediaStudioSideTool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.useAa = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool useAa;
}

/// Right-rail (LTR) / left-rail (RTL) edit tools — icon column.
class MediaStudioSideRail extends StatefulWidget {
  const MediaStudioSideRail({
    super.key,
    required this.tools,
    this.collapsedCount = 8,
    this.showLabels = false,
  });

  final List<MediaStudioSideTool> tools;
  final int collapsedCount;
  final bool showLabels;

  @override
  State<MediaStudioSideRail> createState() => _MediaStudioSideRailState();
}

class _MediaStudioSideRailState extends State<MediaStudioSideRail> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final visible = _expanded || widget.tools.length <= widget.collapsedCount
        ? widget.tools
        : widget.tools.take(widget.collapsedCount).toList(growable: false);
    final hasMore = widget.tools.length > widget.collapsedCount;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        end: isRtl ? 0 : 10,
        start: isRtl ? 10 : 0,
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tool in visible)
              _SideRailButton(
                tool: tool,
                showLabel: widget.showLabels,
                onTap: tool.onTap,
              ),
            if (hasMore)
              _SideRailButton(
                tool: MediaStudioSideTool(
                  icon: _expanded
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  label: '',
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
                showLabel: false,
                onTap: () => setState(() => _expanded = !_expanded),
              ),
          ],
        ),
      ),
    );
  }
}

class _SideRailButton extends StatelessWidget {
  const _SideRailButton({
    required this.tool,
    required this.onTap,
    this.showLabel = false,
  });

  final MediaStudioSideTool tool;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Tooltip(
        message: tool.label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 44,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 28,
                  child: tool.useAa
                      ? Text(
                          'Aa',
                          style: TextStyle(
                            color: tool.active
                                ? const Color(0xFFFE2C55)
                                : Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        )
                      : Icon(
                          tool.icon,
                          color: tool.active
                              ? const Color(0xFFFE2C55)
                              : Colors.white,
                          size: 26,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                ),
                if (showLabel && tool.label.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tool.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact multi-clip dock: grid | thumbs | add.
class MediaStudioClipDock extends StatelessWidget {
  const MediaStudioClipDock({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
    this.onOpenStrip,
  });

  final List<GalleryMediaItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  final VoidCallback? onOpenStrip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onOpenStrip ?? onAdd,
                child: const Icon(
                  LucideIcons.layoutGrid,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final selected = index == selectedIndex;
                      return GestureDetector(
                        onTap: () => onSelected(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? Colors.white : Colors.white24,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _DockThumb(file: item.file, isVideo: item.isVideo),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.plus, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DockThumb extends StatelessWidget {
  const _DockThumb({required this.file, required this.isVideo});

  final File file;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    if (!isVideo) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return FutureBuilder<File?>(
      future: VideoThumbnailUtils.generateThumbnailFile(file, maxHeight: 80),
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          return Image.file(snapshot.data!, fit: BoxFit.cover);
        }
        return const ColoredBox(
          color: Color(0xFF222222),
          child: Icon(LucideIcons.film, color: Colors.white38, size: 16),
        );
      },
    );
  }
}

class MediaStudioBottomActions extends StatelessWidget {
  const MediaStudioBottomActions({
    super.key,
    required this.yourStoryLabel,
    required this.nextLabel,
    required this.onYourStory,
    required this.onNext,
    this.avatarUrl,
    this.enabled = true,
  });

  final String yourStoryLabel;
  final String nextLabel;
  final VoidCallback onYourStory;
  final VoidCallback onNext;
  final String? avatarUrl;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _PillButton(
              onTap: enabled ? onYourStory : null,
              background: Colors.white,
              foreground: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StoryAvatar(avatarUrl: avatarUrl),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      yourStoryLabel,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: _PillButton(
              onTap: enabled ? onNext : null,
              background: LivesLayoutConstants.liveBadgeColor,
              foreground: Colors.white,
              child: Text(
                nextLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.child,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  final Widget child;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFFF58529),
            Color(0xFFDD2A7B),
            Color(0xFF8134AF),
            Color(0xFF515BD4),
            Color(0xFFF58529),
          ],
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(1.5),
        child: CircleAvatar(
          backgroundColor: const Color(0xFFE8E8E8),
          backgroundImage: url != null && url.isNotEmpty
              ? NetworkImage(url)
              : null,
          child: url == null || url.isEmpty
              ? const Icon(LucideIcons.user, size: 14, color: Colors.black45)
              : null,
        ),
      ),
    );
  }
}
