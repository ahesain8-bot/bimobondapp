import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FeedEmptyState extends StatelessWidget {
  const FeedEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final feedOverlay = FeedOverlayTheme.of(context);

    return Center(
      child: CustomText(
        l10n.noPostsFound,
        color: feedOverlay.overlayForeground,
        fontSize: 16,
      ),
    );
  }
}

/// Shown when the feed fails to load (e.g. weak network) instead of a false empty state.
class FeedLoadErrorState extends StatelessWidget {
  const FeedLoadErrorState({
    required this.onRetry,
    this.message,
    this.lightForeground = true,
    super.key,
  });

  final VoidCallback onRetry;
  final String? message;
  final bool lightForeground;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final feedOverlay = FeedOverlayTheme.of(context);
    final foreground = lightForeground
        ? feedOverlay.overlayForeground
        : theme.colorScheme.onSurface;
    final muted = foreground.withValues(alpha: 0.7);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.wifiOff,
              size: 40,
              color: muted,
            ),
            const SizedBox(height: AppSizes.p16),
            CustomText(
              message?.trim().isNotEmpty == true
                  ? message!.trim()
                  : l10n.noPostsFound,
              color: foreground,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.p20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
