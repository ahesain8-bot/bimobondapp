import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class TemplateEditorPlaybackBar extends StatelessWidget {
  const TemplateEditorPlaybackBar({
    super.key,
    required this.isPlaying,
    required this.currentTime,
    required this.totalTime,
    required this.canUndo,
    required this.canRedo,
    required this.onPlayPause,
    required this.onUndo,
    required this.onRedo,
    this.onExpand,
  });

  final bool isPlaying;
  final double currentTime;
  final double totalTime;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onPlayPause;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _IconBtn(
            icon: LucideIcons.maximize2,
            onPressed: onExpand,
            enabled: onExpand != null,
          ),
          _IconBtn(
            icon: LucideIcons.undo2,
            onPressed: onUndo,
            enabled: canUndo,
          ),
          _IconBtn(
            icon: LucideIcons.redo2,
            onPressed: onRedo,
            enabled: canRedo,
          ),
          const Spacer(),
          IconButton(
            onPressed: onPlayPause,
            icon: Icon(
              isPlaying ? LucideIcons.pause : LucideIcons.play,
              color: TemplateEditorTheme.textPrimary,
              size: 28,
            ),
          ),
          const Spacer(),
          Text(
            '${TemplateEditorTheme.formatTime(currentTime)} / '
            '${TemplateEditorTheme.formatTime(totalTime)}',
            style: const TextStyle(
              color: TemplateEditorTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        icon,
        color: enabled ? TemplateEditorTheme.textPrimary : TemplateEditorTheme.textMuted,
        size: 20,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
