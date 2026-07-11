import 'dart:math' as math;
import 'dart:ui';

import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/domain/usecases/get_categories_usecase.dart';
import 'package:bimobondapp/app/categories/presentation/di/categories_injector.dart'
    as categories_di;
import 'package:bimobondapp/app/categories/presentation/utils/category_icons.dart';
import 'package:bimobondapp/app/categories/presentation/utils/category_lookup.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/compact_highest_bid.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_grid_tile.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_display_utils.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

List<String> auctionPostCoverUrls(PostEntity post) {
  return resolveAuctionDisplayMedia(post).map((item) => item.url).toList();
}

ProfileAuctionStatus auctionStatusForPost(
  PostEntity post,
  AppLocalizations l10n,
) {
  if (!post.isAuctionable) return ProfileAuctionStatus.none;

  final auction = post.auction;
  if (auction == null) {
    return ProfileAuctionStatus(
      label: l10n.profilePostAuction,
      borderColor: LiveDetailsLayoutConstants.giftCommentGold,
      badgeBackground: LiveDetailsLayoutConstants.auctionActiveBadgeDark,
      badgeForeground: Colors.white,
    );
  }

  final now = DateTime.now().toUtc();
  final start = auction.startedAt.toUtc();
  final end = auction.endedAt.toUtc();

  if (now.isAfter(end)) {
    return ProfileAuctionStatus(
      label: l10n.auctionFinishedBadge,
      borderColor: LiveDetailsLayoutConstants.auctionFinishedBadgeColor,
      badgeBackground: LiveDetailsLayoutConstants.auctionFinishedBadgeDark,
      badgeForeground: Colors.white,
    );
  }

  if (now.isBefore(start)) {
    return ProfileAuctionStatus(
      label: l10n.auctionStartsIn,
      borderColor: LiveDetailsLayoutConstants.giftCommentGold,
      badgeBackground: LiveDetailsLayoutConstants.auctionActiveBadgeDark,
      badgeForeground: Colors.white,
    );
  }

  return ProfileAuctionStatus(
    label: l10n.auctionActiveBadge,
    borderColor: LiveDetailsLayoutConstants.auctionActiveBadgeColor,
    badgeBackground: LiveDetailsLayoutConstants.auctionActiveBadgeDark,
    badgeForeground: Colors.white,
  );
}

class _FeedAuctionCategoriesCache {
  static Future<List<CategoryEntity>>? _future;

  static Future<List<CategoryEntity>> categories() {
    return _future ??= _load();
  }

  static Future<List<CategoryEntity>> _load() async {
    final result = await categories_di.sl<GetCategoriesUseCase>()(NoParams());
    return result.fold((_) => <CategoryEntity>[], (list) => list);
  }
}

String? _auctionItemName(PostEntity post) {
  final name = post.auction?.itemName.trim();
  if (name == null || name.isEmpty) return null;
  return name;
}

String? _auctionTitle(PostEntity post) {
  final title = post.description?.trim();
  if (title == null || title.isEmpty) return null;
  return title;
}

String? _auctionUserName(PostEntity post) {
  final user = post.user;
  if (user == null) return null;

  final fullName = user.fullName?.trim();
  if (fullName != null && fullName.isNotEmpty) return fullName;

  final username = user.username.trim();
  if (username.isNotEmpty) return '@$username';

  return null;
}

bool showAuctionTapToEnter(PostEntity post) {
  final auction = post.auction;
  if (auction == null) return false;
  final now = DateTime.now().toUtc();
  return !now.isBefore(auction.startedAt.toUtc());
}

/// Minimal auction tile in the home feed: cover image + auction frame only.
/// Tap opens the full [LiveDetailsScreen] experience.
class FeedAuctionPreview extends StatelessWidget {
  const FeedAuctionPreview({
    required this.post,
    this.bottomPadding = HomeLayoutConstants.feedPostBottomPadding,
    super.key,
  });

  final PostEntity post;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = auctionStatusForPost(post, l10n);
    final imageUrl = MediaUtils.resolvePostCoverUrl(post) ?? '';
    final itemName = _auctionItemName(post);
    final title = _auctionTitle(post);
    final userName = _auctionUserName(post);
    final avatarUrl = post.user?.avatarUrl;
    final auction = post.auction;
    final isAuctionFinished =
        auction != null &&
        DateTime.now().toUtc().isAfter(auction.endedAt.toUtc());
    final showTapToEnter = showAuctionTapToEnter(post);

    return GestureDetector(
      onTap: () => openPost(context, post),
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: Colors.black,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: FutureBuilder<List<CategoryEntity>>(
            future: _FeedAuctionCategoriesCache.categories(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? const <CategoryEntity>[];
              final categoryLabel = CategoryLookup.labelForId(
                post.categoryId,
                categories,
              );
              final categorySlug =
                  CategoryLookup.slugForId(post.categoryId, categories) ??
                  'default';

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isNotEmpty)
                    SafeNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                          stops: const [0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: status.borderColor.withValues(alpha: 0.95),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + AppSizes.p12,
                    left: AppSizes.p16,
                    child: ProfileAuctionBadge(status: status),
                  ),
                  if (showTapToEnter)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: _FeedAuctionTapToEnterHint(
                            label: l10n.auctionTapToEnter,
                            isFinished: isAuctionFinished,
                          ),
                        ),
                      ),
                    ),
                  if (auction != null ||
                      categoryLabel != null ||
                      itemName != null ||
                      title != null ||
                      userName != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: AppSizes.p16,
                      child: _FeedAuctionInfoOverlay(
                        auction: auction,
                        categoryLabel: categoryLabel,
                        categorySlug: categorySlug,
                        itemName: itemName,
                        title: title,
                        userName: userName,
                        avatarUrl: avatarUrl,
                        isAuctionFinished: isAuctionFinished,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeedAuctionInfoOverlay extends StatelessWidget {
  const _FeedAuctionInfoOverlay({
    required this.categorySlug,
    this.auction,
    this.categoryLabel,
    this.itemName,
    this.title,
    this.userName,
    this.avatarUrl,
    this.isAuctionFinished = false,
  });

  final PostAuctionEntity? auction;
  final String? categoryLabel;
  final String categorySlug;
  final String? itemName;
  final String? title;
  final String? userName;
  final String? avatarUrl;
  final bool isAuctionFinished;

  String _formatHighestBid(AppLocalizations l10n, Locale locale) {
    final amount = formatAuctionPricingCoins(
      auction?.displayHighestPriceCoins ?? 0,
      locale,
    );
    return l10n.liveHighestBidAmount(amount, l10n.coinsUnit);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final bidderSpend = auction?.displayBidderSpendCoins;
    final targetPriceLabel = bidderSpend != null && bidderSpend > 0
        ? l10n.auctionTargetPrice(
            formatAuctionPricingCoins(bidderSpend, locale),
            l10n.coinsUnit,
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (auction != null) ...[
          CompactHighestBid(
            topBidLabel: l10n.liveTopBid,
            bidAmountText: _formatHighestBid(l10n, locale),
            showGiftIcon: true,
            showCoinIcon: true,
            targetPrice: bidderSpend?.round(),
            targetPriceLabel: targetPriceLabel,
            isFinished: isAuctionFinished,
            popAnimation: const AlwaysStoppedAnimation(1),
            theme: theme,
            margin: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
          ),
          const SizedBox(height: AppSizes.p12),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (categoryLabel != null) ...[
                _FeedAuctionCategoryChip(
                  label: categoryLabel!,
                  categorySlug: categorySlug,
                ),
                const SizedBox(height: AppSizes.p8),
              ],
              if (itemName != null) ...[
                CustomText(
                  itemName!,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                const SizedBox(height: AppSizes.p4),
              ],
              if (title != null) ...[
                Text(
                  title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AppSizes.p8),
              ],
              if (userName != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.p8,
                        vertical: AppSizes.p6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (avatarUrl != null && avatarUrl!.isNotEmpty) ...[
                            ClipOval(
                              child: SafeNetworkImage(
                                imageUrl: avatarUrl!,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: AppSizes.p8),
                          ],
                          Flexible(
                            child: CustomText(
                              userName!,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
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

class _FeedAuctionTapToEnterHint extends StatefulWidget {
  const _FeedAuctionTapToEnterHint({
    required this.label,
    this.isFinished = false,
  });

  final String label;
  final bool isFinished;

  @override
  State<_FeedAuctionTapToEnterHint> createState() =>
      _FeedAuctionTapToEnterHintState();
}

class _FeedAuctionTapToEnterHintState extends State<_FeedAuctionTapToEnterHint>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isFinished
        ? LiveDetailsLayoutConstants.auctionFinishedBadgeColor
        : LiveDetailsLayoutConstants.liveBadgeColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final tapDown = t < 0.45
            ? Curves.easeIn.transform(t / 0.45)
            : Curves.easeOut.transform((1 - t) / 0.55);
        final fingerOffset = 14 * tapDown;
        final rippleProgress = ((t - 0.2) / 0.65).clamp(0.0, 1.0);
        final rippleScale = 0.5 + rippleProgress * 2.2;
        final rippleOpacity = (1 - rippleProgress) * 0.65;
        final textOpacity = 0.6 + 0.4 * math.sin(t * math.pi * 2).abs();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (rippleProgress > 0)
                    Transform.scale(
                      scale: rippleScale,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: rippleOpacity),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(
                                alpha: rippleOpacity * 0.5,
                              ),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(6, fingerOffset),
                    child: Transform.rotate(
                      angle: -0.25,
                      child: Icon(
                        LucideIcons.pointer,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: 40,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Opacity(
                  opacity: textOpacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p12,
                      vertical: AppSizes.p6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FeedAuctionCategoryChip extends StatelessWidget {
  const _FeedAuctionCategoryChip({
    required this.label,
    required this.categorySlug,
  });

  final String label;
  final String categorySlug;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p8,
            vertical: AppSizes.p4,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                categoryIconForSlug(categorySlug),
                size: 12,
                color: Colors.white,
              ),
              const SizedBox(width: AppSizes.p4),
              CustomText(
                label,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
