import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Tap target to dock search + progress above the bottom nav (home feed).
class FeedBottomChromeExpandHandle extends StatelessWidget {
  const FeedBottomChromeExpandHandle({
    required this.onTap,
    super.key,
  });

  final VoidCallback onTap;

  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.search,
                size: 16,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.searchAction,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                LucideIcons.chevronUp,
                size: 16,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
