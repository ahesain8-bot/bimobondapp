import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddPostPublishBar extends StatelessWidget {
  const AddPostPublishBar({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.p16,
            AppSizes.p12,
            AppSizes.p16,
            AppSizes.p12,
          ),
          child: SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeightMd,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isLoading
                    ? null
                    : LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                      ),
                color: isLoading
                    ? (isDark ? const Color(0xFF2E2E30) : const Color(0xFFE5E5EA))
                    : null,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                boxShadow: isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.32),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? null : onPressed,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  child: Center(
                    child: isLoading
                        ? const CustomLoadingWidget(size: 28)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.send,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: AppSizes.p8),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
