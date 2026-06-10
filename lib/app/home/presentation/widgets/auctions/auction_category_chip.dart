import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class AuctionCategoryChip extends StatefulWidget {
  const AuctionCategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.inactiveBackground,
    required this.inactiveBorder,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final Color inactiveBackground;
  final Color inactiveBorder;
  final VoidCallback onTap;

  @override
  State<AuctionCategoryChip> createState() => _AuctionCategoryChipState();
}

class _AuctionCategoryChipState extends State<AuctionCategoryChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.isSelected;
    final foreground = isSelected
        ? Colors.white
        : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
            theme.colorScheme.onSurface;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    widget.selectedColor,
                    widget.selectedColor.withValues(alpha: 0.72),
                  ],
                )
              : null,
          color: isSelected ? null : widget.inactiveBackground,
          borderRadius: BorderRadius.circular(AppSizes.p20),
          border: Border.all(
            color: isSelected ? Colors.transparent : widget.inactiveBorder,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(AppSizes.p20),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p16,
                vertical: AppSizes.p8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 16, color: foreground),
                  const SizedBox(width: AppSizes.p8),
                  CustomText(
                    widget.label,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: foreground,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
