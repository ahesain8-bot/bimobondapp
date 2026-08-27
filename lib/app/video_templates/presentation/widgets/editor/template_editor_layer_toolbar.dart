import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style contextual actions when a timeline layer is selected.
class TemplateEditorLayerToolbar extends StatelessWidget {
  const TemplateEditorLayerToolbar({
    super.key,
    required this.replaceLabel,
    required this.onDismiss,
    required this.onReplace,
    required this.onCopy,
    required this.onDelete,
    this.onLayers,
    this.copyEnabled = true,
    this.layersEnabled = false,
  });

  final String replaceLabel;
  final VoidCallback onDismiss;
  final VoidCallback onReplace;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback? onLayers;
  final bool copyEnabled;
  final bool layersEnabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Row(
          children: [
            _ActionButton(
              icon: LucideIcons.chevronDown,
              label: '',
              onTap: onDismiss,
              compact: true,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: LucideIcons.refreshCw,
                    label: replaceLabel,
                    onTap: onReplace,
                  ),
                  _ActionButton(
                    icon: LucideIcons.copy,
                    label: 'Copy',
                    onTap: copyEnabled ? onCopy : null,
                  ),
                  _ActionButton(
                    icon: LucideIcons.trash2,
                    label: 'Delete',
                    onTap: onDelete,
                  ),
                  if (onLayers != null)
                    _ActionButton(
                      icon: LucideIcons.layers,
                      label: 'Layers',
                      onTap: layersEnabled ? onLayers : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 4,
            vertical: 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 40 : 44,
                height: compact ? 40 : 44,
                decoration: BoxDecoration(
                  color: TemplateEditorTheme.panel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? TemplateEditorTheme.textPrimary
                      : TemplateEditorTheme.textMuted,
                  size: compact ? 20 : 22,
                ),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? TemplateEditorTheme.textPrimary
                        : TemplateEditorTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
