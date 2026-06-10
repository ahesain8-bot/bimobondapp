import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LiquidGlassDropdownItem<T> {
  const LiquidGlassDropdownItem({
    required this.value,
    required this.label,
    this.isSelected = false,
  });

  final T value;
  final String label;
  final bool isSelected;
}

/// Anchored liquid-glass dropdown menu.
class LiquidGlassDropdownMenu {
  LiquidGlassDropdownMenu._();

  static Future<T?> show<T>({
    required BuildContext context,
    required Rect anchor,
    required List<LiquidGlassDropdownItem<T>> items,
    double minWidth = 168,
    bool alignTrailing = true,
  }) {
    final screen = MediaQuery.sizeOf(context);
    final dropdownWidth = minWidth;
    final left = alignTrailing
        ? (anchor.right - dropdownWidth).clamp(
            AppSizes.p8,
            screen.width - dropdownWidth - AppSizes.p8,
          )
        : anchor.left.clamp(
            AppSizes.p8,
            screen.width - dropdownWidth - AppSizes.p8,
          );
    final top = anchor.bottom + AppSizes.p8;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, _) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: dropdownWidth,
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * -6),
                        child: child,
                      ),
                    );
                  },
                  child: LiquidGlassSurface(
                    borderRadius: BorderRadius.circular(14),
                    blurSigma: 24,
                    backgroundColor: const Color(0x24FFFFFF),
                    borderColor: const Color(0x40FFFFFF),
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.p4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          _LiquidGlassDropdownRow(
                            label: items[i].label,
                            isSelected: items[i].isSelected,
                            onTap: () =>
                                Navigator.pop(dialogContext, items[i].value),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (_, animation, _, child) => child,
    );
  }
}

class _LiquidGlassDropdownRow extends StatelessWidget {
  const _LiquidGlassDropdownRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p12,
            vertical: AppSizes.p12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  LucideIcons.check,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
