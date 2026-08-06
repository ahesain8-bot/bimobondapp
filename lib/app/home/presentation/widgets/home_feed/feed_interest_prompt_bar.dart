import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Instagram-style bottom prompt: "Are you interested in this content?"
class FeedInterestPromptBar extends StatelessWidget {
  const FeedInterestPromptBar({
    required this.onInterested,
    required this.onNotInterested,
    required this.onDismiss,
    super.key,
  });

  final VoidCallback onInterested;
  final VoidCallback onNotInterested;
  final VoidCallback onDismiss;

  static const double height = HomeLayoutConstants.feedInterestPromptHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.p12,
            AppSizes.p10,
            AppSizes.p8,
            AppSizes.p10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.feedInterestPromptQuestion,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p8),
              _PromptChip(
                label: l10n.feedInterestPromptYes,
                filled: true,
                onTap: onInterested,
              ),
              const SizedBox(width: AppSizes.p6),
              _PromptChip(
                label: l10n.feedInterestPromptNo,
                filled: false,
                onTap: onNotInterested,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDismiss,
                icon: Icon(
                  LucideIcons.x,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.14);
    final fg = filled ? Colors.white : Colors.white;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
