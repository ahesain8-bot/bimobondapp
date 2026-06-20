import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/promotions/domain/entities/promotion_entities.dart';
import 'package:bimobondapp/app/promotions/presentation/utils/promoted_post_loader.dart';
import 'package:bimobondapp/app/promotions/presentation/widgets/promotion_insights_widgets.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Shimmer placeholder matching [PromotedPostInsightsBody] layout.
class PromotedPostInsightsSkeleton extends StatelessWidget {
  const PromotedPostInsightsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonWidget(width: 72, height: 96, borderRadius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonWidget(height: 16),
                  const SizedBox(height: 8),
                  SkeletonWidget(
                    height: 16,
                    width: MediaQuery.sizeOf(context).width * 0.42,
                  ),
                  const SizedBox(height: 8),
                  SkeletonWidget(
                    height: 16,
                    width: MediaQuery.sizeOf(context).width * 0.28,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SkeletonWidget(height: 24, width: 68, borderRadius: 6),
                      const SizedBox(width: 8),
                      SkeletonWidget(height: 14, width: 88, borderRadius: 6),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _InsightsSkeletonPanel(
          isDark: isDark,
          scheme: scheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SkeletonWidget(height: 14, borderRadius: 6),
                  ),
                  const SizedBox(width: 12),
                  SkeletonWidget(height: 14, width: 48, borderRadius: 6),
                ],
              ),
              const SizedBox(height: 10),
              SkeletonWidget(height: 6, borderRadius: 6),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonWidget(height: 12, width: 72, borderRadius: 6),
                        const SizedBox(height: 6),
                        SkeletonWidget(height: 14, width: 96, borderRadius: 6),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonWidget(height: 12, width: 56, borderRadius: 6),
                        const SizedBox(height: 6),
                        SkeletonWidget(height: 14, width: 88, borderRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SkeletonWidget(height: 44, borderRadius: 10),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SkeletonWidget(height: 20, width: 160, borderRadius: 6),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: List.generate(8, (_) => const _InsightsKpiCardSkeleton()),
        ),
        const SizedBox(height: 16),
        _InsightsSkeletonPanel(
          isDark: isDark,
          scheme: scheme,
          color: scheme.surfaceContainerLow,
          child: Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 36,
                    color: scheme.outlineVariant,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        SkeletonWidget(height: 16, width: 48, borderRadius: 6),
                        const SizedBox(height: 6),
                        SkeletonWidget(height: 10, borderRadius: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _InsightsSkeletonPanel(
          isDark: isDark,
          scheme: scheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonWidget(height: 18, width: 140, borderRadius: 6),
              const SizedBox(height: 20),
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                    7,
                    (index) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SkeletonWidget(
                              height: 10,
                              width: 20,
                              borderRadius: 4,
                            ),
                            const SizedBox(height: 4),
                            SkeletonWidget(
                              height: 40 + (index % 3) * 18.0,
                              borderRadius: 4,
                            ),
                            const SizedBox(height: 6),
                            SkeletonWidget(
                              height: 10,
                              width: 28,
                              borderRadius: 4,
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
      ],
    );
  }
}

class _InsightsSkeletonPanel extends StatelessWidget {
  const _InsightsSkeletonPanel({
    required this.isDark,
    required this.scheme,
    required this.child,
    this.color,
  });

  final bool isDark;
  final ColorScheme scheme;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.65),
        ),
      ),
      child: child,
    );
  }
}

class _InsightsKpiCardSkeleton extends StatelessWidget {
  const _InsightsKpiCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.65),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonWidget(width: 18, height: 18, borderRadius: 6),
          SizedBox(height: 8),
          SkeletonWidget(height: 22, width: 56, borderRadius: 6),
          SizedBox(height: 6),
          SkeletonWidget(height: 12, width: 72, borderRadius: 6),
        ],
      ),
    );
  }
}

class PromotedPostInsightsBody extends StatelessWidget {
  const PromotedPostInsightsBody({
    super.key,
    required this.stats,
    required this.fetchedPost,
    required this.selectedCampaignId,
    required this.actionLoading,
    required this.onCampaignSelected,
    required this.onToggleStatus,
  });

  final PromotedPostStatsEntity stats;
  final PostEntity? fetchedPost;
  final String? selectedCampaignId;
  final bool actionLoading;
  final ValueChanged<String?> onCampaignSelected;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final post = stats.post;
    final coverUrl = fetchedPost != null
        ? PromotedPostLoader.coverUrl(fetchedPost!)
        : resolvePromotedPostCoverUrl(post);
    final description = fetchedPost?.description ?? post.description;
    final s = stats.statistics;
    final primary = stats.primaryCampaign;
    final progress = primary?.progress;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SafeNetworkImage(
                imageUrl: coverUrl,
                width: 72,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description?.trim().isNotEmpty == true
                        ? description!.trim()
                        : l10n.promotePostNoCaption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (primary != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PromotionStatusChip(status: primary.status),
                        Text(
                          formatPromotionObjective(primary.objective, l10n),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 20),
          PromotedCampaignProgressSection(
            progress: progress,
            primary: primary!,
            actionLoading: actionLoading,
            onToggleStatus: onToggleStatus,
          ),
        ],
        const SizedBox(height: 20),
        Text(
          l10n.promoteInsightsPerformanceTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            PromotionKpiCard(
              icon: LucideIcons.eye,
              label: l10n.viewsLabel,
              value: formatCompactCount(s.views),
            ),
            PromotionKpiCard(
              icon: LucideIcons.heart,
              label: l10n.likes,
              value: formatCompactCount(s.likes),
            ),
            PromotionKpiCard(
              icon: LucideIcons.messageCircle,
              label: l10n.commentsTitle,
              value: formatCompactCount(s.comments),
            ),
            PromotionKpiCard(
              icon: LucideIcons.share2,
              label: l10n.promoteInsightsShares,
              value: formatCompactCount(s.shares),
            ),
            PromotionKpiCard(
              icon: LucideIcons.megaphone,
              label: l10n.promoteInsightsPromotedImpressions,
              value: formatCompactCount(s.promotedImpressions),
            ),
            PromotionKpiCard(
              icon: LucideIcons.userPlus,
              label: l10n.promoteInsightsFollowersGained,
              value: formatCompactCount(s.followersGained),
            ),
            PromotionKpiCard(
              icon: LucideIcons.wallet,
              label: l10n.promoteInsightsSpend,
              value: formatUsd(s.promotionSpendUsd),
            ),
            PromotionKpiCard(
              icon: LucideIcons.percent,
              label: l10n.promoteInsightsEngagementRate,
              value: formatPercent(s.engagementRate),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PromotedCostMetricsRow(stats: s),
        const SizedBox(height: 20),
        PromotionImpressionsChart(
          title: l10n.promoteInsightsChartTitle,
          data: stats.charts.impressionsLast7Days,
        ),
        if (stats.campaigns.length > 1) ...[
          const SizedBox(height: 24),
          Text(
            l10n.promoteInsightsCampaignHistory,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.promoteInsightsCampaignHistoryHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          PromotedCampaignFilterChip(
            label: l10n.promoteInsightsAllCampaigns,
            selected: selectedCampaignId == null,
            onTap: () => onCampaignSelected(null),
          ),
          const SizedBox(height: 8),
          ...stats.campaigns.map(
            (campaign) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PromotedCampaignHistoryTile(
                campaign: campaign,
                selected: selectedCampaignId == campaign.id,
                onTap: () => onCampaignSelected(campaign.id),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class PromotedCampaignProgressSection extends StatelessWidget {
  const PromotedCampaignProgressSection({
    super.key,
    required this.progress,
    required this.primary,
    required this.actionLoading,
    required this.onToggleStatus,
  });

  final PromotionCampaignProgressEntity progress;
  final PromotionCampaignSummaryEntity primary;
  final bool actionLoading;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = primary.status.toUpperCase();
    final canToggle = status == 'ACTIVE' || status == 'PAUSED';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.promoteInsightsCampaignProgress,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatPercent(progress.progressPercent),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PromotionProgressBar(progressPercent: progress.progressPercent),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PromotedProgressDetail(
                  label: l10n.promoteInsightsImpressions,
                  value:
                      '${formatCompactCount(progress.impressionCount)} / ${formatCompactCount(progress.impressionTarget)}',
                ),
              ),
              Expanded(
                child: PromotedProgressDetail(
                  label: l10n.promoteInsightsBudget,
                  value:
                      '${formatUsd(progress.spentUsd)} / ${formatUsd(progress.budgetUsd)}',
                ),
              ),
            ],
          ),
          if (canToggle) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: actionLoading ? null : onToggleStatus,
              icon: actionLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    )
                  : Icon(
                      status == 'ACTIVE'
                          ? LucideIcons.pause
                          : LucideIcons.play,
                      size: 18,
                    ),
              label: Text(
                status == 'ACTIVE'
                    ? l10n.promoteInsightsPauseCampaign
                    : l10n.promoteInsightsResumeCampaign,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PromotedProgressDetail extends StatelessWidget {
  const PromotedProgressDetail({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class PromotedCostMetricsRow extends StatelessWidget {
  const PromotedCostMetricsRow({super.key, required this.stats});

  final PostEngagementStatisticsEntity stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: PromotedCostCell(
              label: l10n.promoteInsightsCostPerImpression,
              value: formatUsd(stats.costPerImpression),
            ),
          ),
          Container(width: 1, height: 36, color: scheme.outlineVariant),
          Expanded(
            child: PromotedCostCell(
              label: l10n.promoteInsightsCostPerView,
              value: formatUsd(stats.costPerView),
            ),
          ),
          Container(width: 1, height: 36, color: scheme.outlineVariant),
          Expanded(
            child: PromotedCostCell(
              label: l10n.promoteInsightsUniqueViewers,
              value: formatCompactCount(stats.uniquePromotedViewers),
            ),
          ),
        ],
      ),
    );
  }
}

class PromotedCostCell extends StatelessWidget {
  const PromotedCostCell({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class PromotedCampaignFilterChip extends StatelessWidget {
  const PromotedCampaignFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: scheme.primary.withValues(alpha: 0.15),
      checkmarkColor: scheme.primary,
    );
  }
}

class PromotedCampaignHistoryTile extends StatelessWidget {
  const PromotedCampaignHistoryTile({
    super.key,
    required this.campaign,
    required this.selected,
    required this.onTap,
  });

  final PromotionCampaignSummaryEntity campaign;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = campaign.progress;

    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.08)
          : scheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PromotionStatusChip(status: campaign.status),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formatPromotionObjective(campaign.objective, l10n),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      PromotionProgressBar(
                        progressPercent: progress.progressPercent,
                        height: 4,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.promoteInsightsCampaignProgressSummary(
                          formatPercent(progress.progressPercent),
                          formatUsd(progress.spentUsd),
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              DirectionalChevronIcon(
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
