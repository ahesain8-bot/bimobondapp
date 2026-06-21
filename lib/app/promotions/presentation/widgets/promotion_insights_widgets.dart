import 'package:bimobondapp/app/promotions/domain/entities/promotion_entities.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

String formatPromotionObjective(String objective, AppLocalizations l10n) {
  switch (objective.toUpperCase()) {
    case 'FOLLOWERS':
      return l10n.promoteInsightsObjectiveFollowers;
    case 'ENGAGEMENT':
      return l10n.promoteInsightsObjectiveEngagement;
    case 'CHALLENGES':
      return l10n.promoteInsightsObjectiveChallenges;
    case 'PROFILE_VISITS':
      return l10n.promoteInsightsObjectiveProfileVisits;
    case 'SALES':
      return l10n.promoteInsightsObjectiveSales;
    case 'VIEWS':
    default:
      return l10n.promoteInsightsObjectiveViews;
  }
}

String formatCampaignStatus(String status, AppLocalizations l10n) {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
      return l10n.promoteInsightsStatusActive;
    case 'PAUSED':
      return l10n.promoteInsightsStatusPaused;
    case 'PENDING_PAYMENT':
      return l10n.promoteInsightsStatusPendingPayment;
    case 'COMPLETED':
      return l10n.promoteInsightsStatusCompleted;
    case 'CANCELLED':
      return l10n.promoteInsightsStatusCancelled;
    default:
      return status;
  }
}

Color campaignStatusColor(String status, ColorScheme scheme) {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
      return Colors.green.shade600;
    case 'PAUSED':
      return Colors.orange.shade700;
    case 'PENDING_PAYMENT':
      return scheme.primary;
    case 'COMPLETED':
      return scheme.onSurfaceVariant;
    case 'CANCELLED':
      return scheme.error;
    default:
      return scheme.onSurfaceVariant;
  }
}

class PromotionStatusChip extends StatelessWidget {
  const PromotionStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final color = campaignStatusColor(status, scheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        formatCampaignStatus(status, l10n),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PromotionProgressBar extends StatelessWidget {
  const PromotionProgressBar({
    super.key,
    required this.progressPercent,
    this.height = 6,
  });

  final double progressPercent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = (progressPercent / 100).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: scheme.surfaceContainerHighest,
        color: scheme.primary,
      ),
    );
  }
}

class PromotionKpiCard extends StatelessWidget {
  const PromotionKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class PromotionImpressionsChart extends StatelessWidget {
  const PromotionImpressionsChart({
    super.key,
    required this.data,
    required this.title,
  });

  final List<DailyImpressionEntity> data;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxCount = data.fold<int>(
      0,
      (prev, item) => item.count > prev ? item.count : prev,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          if (data.isEmpty)
            Text(
              AppLocalizations.of(context)!.promoteInsightsNoChartData,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final item in data) ...[
                    Expanded(
                      child: _ChartBar(
                        label: _shortDateLabel(item.date),
                        count: item.count,
                        maxCount: maxCount <= 0 ? 1 : maxCount,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _shortDateLabel(String date) {
    if (date.length >= 10) {
      return date.substring(5);
    }
    return date;
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.color,
  });

  final String label;
  final int count;
  final int maxCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final barHeight = count / maxCount * 96;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            formatCompactCount(count),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: barHeight.clamp(4, 96),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

String formatUsd(double value) => '\$${value.toStringAsFixed(2)}';

String formatPercent(double value) => '${value.toStringAsFixed(1)}%';
