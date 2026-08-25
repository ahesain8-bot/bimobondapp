import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MarketplaceSearchBar extends StatelessWidget {
  const MarketplaceSearchBar({
    this.onTap,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = true,
    super.key,
  });

  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: theme.surface,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusMd),
        child: InkWell(
          onTap: readOnly ? onTap : null,
          borderRadius: BorderRadius.circular(MarketplaceTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MarketplaceTheme.radiusMd),
              border: Border.all(color: theme.shop.border.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.search, size: 20, color: theme.mutedText),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    readOnly: readOnly,
                    controller: controller,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    onTap: readOnly ? onTap : null,
                    decoration: InputDecoration(
                      hintText: l10n.marketplaceSearchHint,
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: TextStyle(color: theme.mutedText, fontSize: 14),
                    ),
                    style: TextStyle(color: theme.onSurface, fontSize: 14),
                  ),
                ),
                if (readOnly)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primary,
                      borderRadius:
                          BorderRadius.circular(MarketplaceTheme.radiusSm),
                    ),
                    child: Text(
                      l10n.searchAction,
                      style: TextStyle(
                        color: theme.shop.onAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
