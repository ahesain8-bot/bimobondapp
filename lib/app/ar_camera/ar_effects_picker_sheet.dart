import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_l10n.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// AR face-effect picker matching the live camera carousel catalog.
class ArEffectsPickerSheet {
  ArEffectsPickerSheet._();

  static Future<void> show(
    BuildContext context, {
    required AppLocalizations l10n,
    required String selectedEffectId,
    required ValueChanged<String> onSelected,
  }) {
    return GlassBottomSheet.showContent(
      context,
      title: l10n.cameraEffects,
      child: SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: ArFilterCatalog.effectItems.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final item = ArFilterCatalog.effectItems[index];
            final selected = item.id == selectedEffectId ||
                (selectedEffectId == 'none' && item.isOriginal);
            return GestureDetector(
              onTap: () {
                onSelected(item.id);
                Navigator.pop(context);
              },
              child: SizedBox(
                width: 68,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(
                          alpha: selected ? 0.18 : 0.08,
                        ),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFE2C55)
                              : Colors.white.withValues(alpha: 0.22),
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          item.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      arFilterLabel(l10n, item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
