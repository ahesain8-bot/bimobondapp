import 'package:bimobondapp/app/home/presentation/widgets/stories/story_text_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_text_style.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StoryTextEditorToolbar extends StatelessWidget {
  const StoryTextEditorToolbar({
    required this.overlay,
    required this.onChanged,
    required this.onDone,
    required this.onDelete,
    super.key,
  });

  final StoryTextOverlay overlay;
  final ValueChanged<StoryTextOverlay> onChanged;
  final VoidCallback onDone;
  final VoidCallback onDelete;

  Color get _activePaletteColor => switch (overlay.backgroundMode) {
    StoryTextBackgroundMode.none => overlay.textColor,
    StoryTextBackgroundMode.translucent ||
    StoryTextBackgroundMode.solid => overlay.backgroundColor,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p8,
        vertical: AppSizes.p8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: StoryTextStyleKit.palette.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final color = StoryTextStyleKit.palette[index];
                final selected =
                    color.toARGB32() == _activePaletteColor.toARGB32();
                return GestureDetector(
                  onTap: () => onChanged(overlay.applyPaletteColor(color)),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.white38,
                        width: selected ? 2.5 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.35),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSizes.p8),
          Row(
            children: [
              _ToolbarIconButton(
                label: 'Aa',
                isTextLabel: true,
                isActive: true,
                onTap: () => onChanged(
                  overlay.copyWith(
                    fontStyle: StoryTextStyleKit.cycleFont(overlay.fontStyle),
                  ),
                ),
              ),
              _ToolbarIconButton(
                icon: _backgroundIcon(overlay.backgroundMode),
                isActive:
                    overlay.backgroundMode != StoryTextBackgroundMode.none,
                onTap: () => onChanged(
                  overlay.copyWith(
                    backgroundMode: StoryTextStyleKit.cycleBackground(
                      overlay.backgroundMode,
                    ),
                  ),
                ),
              ),
              _ToolbarIconButton(
                icon: _alignmentIcon(overlay.alignment),
                onTap: () => onChanged(
                  overlay.copyWith(alignment: overlay.alignment.next()),
                ),
              ),
              _ToolbarIconButton(icon: LucideIcons.trash2, onTap: onDelete),
              const Spacer(),
              TextButton(
                onPressed: onDone,
                child: Text(
                  l10n.storyTextDone,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _backgroundIcon(StoryTextBackgroundMode mode) {
    return switch (mode) {
      StoryTextBackgroundMode.none => LucideIcons.type,
      StoryTextBackgroundMode.translucent => LucideIcons.highlighter,
      StoryTextBackgroundMode.solid => LucideIcons.square,
    };
  }

  IconData _alignmentIcon(StoryTextAlignment alignment) {
    return switch (alignment) {
      StoryTextAlignment.left => LucideIcons.textAlignStart,
      StoryTextAlignment.center => LucideIcons.textAlignCenter,
      StoryTextAlignment.right => LucideIcons.textAlignEnd,
    };
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    this.icon,
    this.label,
    this.isTextLabel = false,
    this.isActive = false,
    required this.onTap,
  });

  final IconData? icon;
  final String? label;
  final bool isTextLabel;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.p4),
      child: IconButton(
        onPressed: onTap,
        icon: isTextLabel
            ? Text(
                label ?? 'Aa',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              )
            : Icon(
                icon,
                color: isActive ? Colors.white : Colors.white70,
                size: 22,
              ),
      ),
    );
  }
}
