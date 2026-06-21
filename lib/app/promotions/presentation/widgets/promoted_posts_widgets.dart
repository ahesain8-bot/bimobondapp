import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/promotions/domain/entities/promotion_entities.dart';
import 'package:bimobondapp/app/promotions/presentation/utils/promoted_post_loader.dart';
import 'package:bimobondapp/app/promotions/presentation/widgets/promotion_insights_widgets.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PromotedPostCard extends StatefulWidget {
  const PromotedPostCard({
    super.key,
    required this.row,
    required this.onTap,
  });

  final PromotedPostRowEntity row;
  final VoidCallback onTap;

  @override
  State<PromotedPostCard> createState() => _PromotedPostCardState();
}

class _PromotedPostCardState extends State<PromotedPostCard> {
  PostEntity? _fetchedPost;
  bool _loadingPost = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    final postId = widget.row.post.id;
    if (postId.isEmpty) return;

    final cached = PromotedPostLoader.cached(postId);
    if (cached != null) {
      setState(() => _fetchedPost = cached);
      return;
    }

    setState(() => _loadingPost = true);
    final post = await PromotedPostLoader.fetch(postId);
    if (!mounted) return;

    setState(() {
      _fetchedPost = post;
      _loadingPost = false;
    });
  }

  String? get _coverUrl {
    if (_fetchedPost != null) {
      return PromotedPostLoader.coverUrl(_fetchedPost!);
    }
    return resolvePromotedPostCoverUrl(widget.row.post);
  }

  bool get _isAuction =>
      _fetchedPost?.isAuctionable ?? widget.row.post.isAuctionable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final row = widget.row;
    final post = row.post;
    final stats = row.statistics;
    final promo = row.promotion;
    final primary = row.primaryCampaign;
    final progress = primary?.progress?.progressPercent ?? 0;
    final description = _fetchedPost?.description ?? post.description;
    final caption = description?.trim().isNotEmpty == true
        ? description!.trim()
        : l10n.promotePostNoCaption;
    final objectiveLabel = primary != null
        ? formatPromotionObjective(primary.objective, l10n)
        : l10n.promoteInsightsMultipleCampaigns;
    final coverUrl = _coverUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isDark ? 0.25 : 0.07),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (coverUrl != null)
                        SafeNetworkImage(
                          imageUrl: coverUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        )
                      else if (_loadingPost)
                        const SkeletonWidget(borderRadius: 0)
                      else
                        ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: Center(
                            child: Icon(
                              _isAuction
                                  ? LucideIcons.gavel
                                  : LucideIcons.image,
                              size: 40,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.08),
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: 10,
                        start: 10,
                        end: 10,
                        child: Row(
                          children: [
                            if (primary != null)
                              PromotionStatusChip(status: primary.status),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.play,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    formatCompactCount(stats.views),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      PositionedDirectional(
                        start: 12,
                        end: 12,
                        bottom: 12,
                        child: Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            shadows: const [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              objectiveLabel,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              formatUsd(promo.totalSpentUsd),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: PromotedStatPill(
                              icon: LucideIcons.eye,
                              value: formatCompactCount(stats.views),
                              label: l10n.viewsLabel,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PromotedStatPill(
                              icon: LucideIcons.heart,
                              value: formatCompactCount(stats.likes),
                              label: l10n.likes,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PromotedStatPill(
                              icon: LucideIcons.megaphone,
                              value: formatCompactCount(promo.totalImpressions),
                              label: l10n.promoteInsightsPromotedImpressions,
                            ),
                          ),
                        ],
                      ),
                      if (primary?.progress != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.promoteInsightsCampaignProgress,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              formatPercent(progress),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        PromotionProgressBar(
                          progressPercent: progress,
                          height: 8,
                        ),
                      ],
                    ],
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

class PromotedStatPill extends StatelessWidget {
  const PromotedStatPill({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
