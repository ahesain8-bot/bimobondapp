import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CoinAmountChip extends StatelessWidget {
  const CoinAmountChip({
    required this.coins,
    super.key,
    this.compact = false,
  });

  final int coins;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final digits = LocaleFormatUtils.localizeDigits(coins.toString(), locale);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.18),
            colorScheme.secondary.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.coins,
            size: compact ? 14 : 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            compact ? digits : '$digits ${l10n.coinsUnit}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11 : 12,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
