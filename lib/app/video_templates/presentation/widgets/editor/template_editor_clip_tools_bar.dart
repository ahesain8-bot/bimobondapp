import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_theme.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// CapCut-style clip tools shown when Edit is open (static horizontal bar).
enum TemplateClipTool {
  split,
  replace,
  delete,
  speed,
  crop,
  volume,
  reduceNoise,
  rotate,
  beautify,
  filters,
  adjust,
  overlay,
  reverse,
  freeze,
  mask,
  opacity,
  voiceEffect,
  animation,
  effects,
  cutout,
  background,
  magic,
}

class TemplateEditorClipToolsBar extends StatelessWidget {
  const TemplateEditorClipToolsBar({
    super.key,
    required this.onClose,
    required this.onToolSelected,
  });

  final VoidCallback onClose;
  final ValueChanged<TemplateClipTool> onToolSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <({TemplateClipTool tool, IconData icon, String label})>[
      (tool: TemplateClipTool.split, icon: LucideIcons.scissors, label: l10n.videoEditorSplit),
      (tool: TemplateClipTool.replace, icon: LucideIcons.refreshCw, label: l10n.templateEditorClipReplace),
      (tool: TemplateClipTool.delete, icon: LucideIcons.trash2, label: l10n.videoEditorDeleteSegment),
      (tool: TemplateClipTool.speed, icon: LucideIcons.gauge, label: l10n.cameraSpeed),
      (tool: TemplateClipTool.crop, icon: LucideIcons.crop, label: l10n.mediaEditorCrop),
      (tool: TemplateClipTool.volume, icon: LucideIcons.volume2, label: l10n.templateEditorClipVolume),
      (tool: TemplateClipTool.reduceNoise, icon: LucideIcons.audioLines, label: l10n.templateEditorClipReduceNoise),
      (tool: TemplateClipTool.rotate, icon: LucideIcons.rotateCw, label: l10n.templateEditorClipRotate),
      (tool: TemplateClipTool.beautify, icon: LucideIcons.sparkle, label: l10n.templateEditorClipBeautify),
      (tool: TemplateClipTool.filters, icon: LucideIcons.blend, label: l10n.templateEditorFilters),
      (tool: TemplateClipTool.adjust, icon: LucideIcons.slidersHorizontal, label: l10n.templateEditorClipAdjust),
      (tool: TemplateClipTool.overlay, icon: LucideIcons.copyPlus, label: l10n.templateEditorClipOverlay),
      (tool: TemplateClipTool.reverse, icon: LucideIcons.undo2, label: l10n.templateEditorClipReverse),
      (tool: TemplateClipTool.freeze, icon: LucideIcons.pause, label: l10n.templateEditorClipFreeze),
      (tool: TemplateClipTool.mask, icon: LucideIcons.circleDashed, label: l10n.templateEditorClipMask),
      (tool: TemplateClipTool.opacity, icon: LucideIcons.droplet, label: l10n.templateEditorClipOpacity),
      (tool: TemplateClipTool.voiceEffect, icon: LucideIcons.mic, label: l10n.templateEditorClipVoiceEffect),
      (tool: TemplateClipTool.animation, icon: LucideIcons.orbit, label: l10n.templateEditorClipAnimation),
      (tool: TemplateClipTool.effects, icon: LucideIcons.sparkles, label: l10n.templateEditorEffects),
      (tool: TemplateClipTool.cutout, icon: LucideIcons.userRound, label: l10n.templateEditorClipCutout),
      (tool: TemplateClipTool.background, icon: LucideIcons.image, label: l10n.templateEditorClipBackground),
      (tool: TemplateClipTool.magic, icon: LucideIcons.wandSparkles, label: l10n.templateEditorClipMagic),
    ];

    return SafeArea(
      top: false,
      child: Container(
        color: TemplateEditorTheme.background,
        padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 10),
        child: SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: items.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ClipToolButton(
                  icon: LucideIcons.chevronDown,
                  label: '',
                  onTap: onClose,
                );
              }
              final item = items[index - 1];
              return _ClipToolButton(
                icon: item.icon,
                label: item.label,
                onTap: () => onToolSelected(item.tool),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ClipToolButton extends StatelessWidget {
  const _ClipToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = TemplateEditorTheme.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: TemplateEditorTheme.panel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: color,
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
