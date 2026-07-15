import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style footer: Drafts + Post pills.
class AddPostPublishBar extends StatelessWidget {
  const AddPostPublishBar({
    required this.label,
    required this.onPressed,
    this.onDraftsPressed,
    this.isLoading = false,
    this.showDrafts = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onDraftsPressed;
  final bool isLoading;
  final bool showDrafts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final draftFill = isDark ? const Color(0xFF2A2A2D) : const Color(0xFFF1F1F2);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.p16,
          AppSizes.p10,
          AppSizes.p16,
          AppSizes.p12,
        ),
        child: Row(
          children: [
            if (showDrafts) ...[
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: Material(
                    color: draftFill,
                    borderRadius: BorderRadius.circular(28),
                    child: InkWell(
                      onTap: isLoading ? null : onDraftsPressed,
                      borderRadius: BorderRadius.circular(28),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.folder,
                            size: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.draftsLabel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 48,
                child: Material(
                  color: isLoading
                      ? (isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA))
                      : AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    onTap: isLoading ? null : onPressed,
                    borderRadius: BorderRadius.circular(28),
                    child: Center(
                      child: isLoading
                          ? const CustomLoadingWidget(size: 26)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  LucideIcons.arrowUpFromLine,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
