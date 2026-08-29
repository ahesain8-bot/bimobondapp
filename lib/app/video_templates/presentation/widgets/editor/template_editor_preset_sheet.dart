import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_theme.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style horizontal preset picker (filters / effects / stickers).
class TemplateEditorPresetSheet extends StatelessWidget {
  const TemplateEditorPresetSheet({
    super.key,
    required this.title,
    required this.presets,
    required this.selectedId,
    required this.onSelected,
    required this.onClear,
    required this.onClose,
    this.categories = const ['Trending'],
    this.selectedCategory = 'Trending',
    this.onCategoryChanged,
  });

  final String title;
  final List<TemplatePresetItem> presets;
  final String? selectedId;
  final ValueChanged<TemplatePresetItem> onSelected;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String>? onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: TemplateEditorTheme.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(LucideIcons.check, color: Colors.white),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final cat in categories)
                            Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: GestureDetector(
                                onTap: onCategoryChanged == null
                                    ? null
                                    : () => onCategoryChanged!(cat),
                                child: Column(
                                  children: [
                                    Text(
                                      cat,
                                      style: TextStyle(
                                        color: cat == selectedCategory
                                            ? Colors.white
                                            : TemplateEditorTheme.textMuted,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 2,
                                      width: 28,
                                      color: cat == selectedCategory
                                          ? Colors.white
                                          : Colors.transparent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClear,
                    tooltip: 'None',
                    icon: const Icon(
                      LucideIcons.ban,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: TemplateEditorTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: presets.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final preset = presets[i];
                  final selected = _presetSelected(preset, selectedId);
                  return _PresetTile(
                    preset: preset,
                    selected: selected,
                    onTap: () => onSelected(preset),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _presetSelected(TemplatePresetItem preset, String? selectedId) {
  if (selectedId == null) return preset.isClear;
  if (preset.id == selectedId) return true;
  switch (preset.kind) {
    case TemplatePresetKind.filter:
      return preset.previewFilterKey == selectedId;
    case TemplatePresetKind.effect:
      return preset.previewEffectKey == selectedId;
    case TemplatePresetKind.transition:
      return preset.previewTransitionKey == selectedId;
    case TemplatePresetKind.sticker:
      return false;
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final TemplatePresetItem preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white12,
                    width: selected ? 2.5 : 1,
                  ),
                  color: TemplateEditorTheme.panelElevated,
                ),
                clipBehavior: Clip.antiAlias,
                child: preset.thumbnailUrl != null
                    ? SafeNetworkImage(
                        imageUrl: preset.thumbnailUrl,
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Icon(
                          preset.kind == TemplatePresetKind.filter
                              ? LucideIcons.aperture
                              : preset.kind == TemplatePresetKind.effect
                                  ? LucideIcons.sparkles
                                  : preset.kind == TemplatePresetKind.transition
                                      ? LucideIcons.betweenHorizontalStart
                                      : LucideIcons.sticker,
                          color: Colors.white54,
                          size: 24,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple sticker grid (recommended row).
class TemplateEditorStickerSheet extends StatelessWidget {
  const TemplateEditorStickerSheet({
    super.key,
    required this.presets,
    required this.onSelected,
    required this.onClose,
  });

  final List<TemplatePresetItem> presets;
  final ValueChanged<TemplatePresetItem> onSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.45,
      decoration: const BoxDecoration(
        color: TemplateEditorTheme.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(LucideIcons.check, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Stickers',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: presets.length,
                itemBuilder: (context, i) {
                  final preset = presets[i];
                  return Material(
                    color: TemplateEditorTheme.panelElevated,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => onSelected(preset),
                      borderRadius: BorderRadius.circular(12),
                      child: preset.assetUrl != null
                          ? SafeNetworkImage(
                              imageUrl: preset.assetUrl,
                              fit: BoxFit.contain,
                            )
                          : Center(
                              child: Text(
                                preset.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
