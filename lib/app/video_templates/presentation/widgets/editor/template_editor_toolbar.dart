import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_theme.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class TemplateEditorToolbar extends StatelessWidget {
  const TemplateEditorToolbar({
    super.key,
    required this.editable,
    required this.activePanel,
    required this.onPanelSelected,
  });

  final TemplateEditableFlags editable;
  final TemplateEditorPanel? activePanel;
  final ValueChanged<TemplateEditorPanel> onPanelSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <_ToolItem>[
      _ToolItem(
        panel: TemplateEditorPanel.edit,
        icon: LucideIcons.scissors,
        label: l10n.edit,
        enabled: true,
      ),
      if (editable.music)
        _ToolItem(
          panel: TemplateEditorPanel.audio,
          icon: LucideIcons.music,
          label: l10n.templateEditorSound,
          enabled: true,
        ),
      if (editable.text)
        _ToolItem(
          panel: TemplateEditorPanel.text,
          icon: LucideIcons.type,
          label: l10n.templateEditorText,
          enabled: true,
        ),
      if (editable.effects)
        _ToolItem(
          panel: TemplateEditorPanel.effects,
          icon: LucideIcons.sparkles,
          label: l10n.templateEditorEffects,
          enabled: true,
        ),
      if (editable.filters)
        _ToolItem(
          panel: TemplateEditorPanel.filters,
          icon: LucideIcons.aperture,
          label: l10n.templateEditorFilters,
          enabled: true,
        ),
      if (editable.transitions)
        _ToolItem(
          panel: TemplateEditorPanel.transitions,
          icon: LucideIcons.betweenHorizontalStart,
          label: l10n.templateEditorTransitions,
          enabled: true,
        ),
      if (editable.stickers)
        _ToolItem(
          panel: TemplateEditorPanel.stickers,
          icon: LucideIcons.sticker,
          label: l10n.templateEditorStickers,
          enabled: true,
        ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final item in items)
              Expanded(
                child: _ToolButton(
                  item: item,
                  selected: activePanel == item.panel,
                  onTap: () => onPanelSelected(item.panel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolItem {
  const _ToolItem({
    required this.panel,
    required this.icon,
    required this.label,
    required this.enabled,
  });

  final TemplateEditorPanel panel;
  final IconData icon;
  final String label;
  final bool enabled;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _ToolItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? TemplateEditorTheme.panelElevated
                      : TemplateEditorTheme.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? TemplateEditorTheme.slotSelectedBorder
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  item.icon,
                  color: item.enabled
                      ? TemplateEditorTheme.textPrimary
                      : TemplateEditorTheme.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: item.enabled
                      ? TemplateEditorTheme.textPrimary
                      : TemplateEditorTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
