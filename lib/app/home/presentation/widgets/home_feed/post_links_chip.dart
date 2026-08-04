import 'package:bimobondapp/app/home/presentation/utils/post_filter_label.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/navigation/camera_filter_navigation.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

enum PostLinkType { effect, location, promotion, auction }

class PostLinkItem {
  final PostLinkType type;
  final String title;
  final String subtitle;
  final Widget leadingWidget;
  final Widget? trailingWidget;
  final VoidCallback onTap;
  final Widget? chipIcon;
  final String chipTitle;

  const PostLinkItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.leadingWidget,
    this.trailingWidget,
    required this.onTap,
    this.chipIcon,
    required this.chipTitle,
  });
}

List<PostLinkItem> getPostLinkItems(BuildContext context, PostEntity post) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final effectSquareBg = isDark
      ? const Color(0xFF2C2C2E)
      : const Color(0xFFE5E5EA);
  final chevronColor = isDark ? Colors.white54 : Colors.black45;

  final links = <PostLinkItem>[];

  // 1. Camera Filter / Effect
  if (post.hasDisplayableFilter &&
      isDisplayablePostFilterName(post.effectiveFilterId!)) {
    final effectLabel = postFilterDisplayLabel(
      l10n,
      post.effectiveFilterId!,
      apiName: post.effectiveFilterLabel,
    );
    const tryEffectText = 'Try effect';
    const effectsSubtitleText = 'Effects';

    links.add(
      PostLinkItem(
        type: PostLinkType.effect,
        title: effectLabel.isNotEmpty ? effectLabel : tryEffectText,
        subtitle: effectsSubtitleText,
        chipTitle: effectLabel.isNotEmpty ? effectLabel : tryEffectText,
        chipIcon: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD60A), Color(0xFFFF8C42)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Icon(LucideIcons.wand2, size: 11, color: Colors.white),
          ),
        ),
        leadingWidget: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: effectSquareBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(
              LucideIcons.sparkles,
              size: 24,
              color: Color(0xFFFF8C42),
            ),
          ),
        ),
        trailingWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFF2D55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(LucideIcons.video, size: 16, color: Colors.white),
        ),
        onTap: () {
          openCameraWithPostFilter(
            context,
            filterId: post.effectiveFilterId!,
            filterCategory: post.filterCategory,
          );
        },
      ),
    );
  }

  // 2. Location
  if (post.location != null && post.location!.hasDisplayLabel) {
    final location = post.location!;
    final displayLabel = location.feedDisplayLabel;
    final subtext =
        location.address ?? location.city ?? location.countryCode ?? '';
    links.add(
      PostLinkItem(
        type: PostLinkType.location,
        title: displayLabel,
        subtitle: subtext.isNotEmpty
            ? '$subtext • Explore now'
            : 'Explore location',
        chipTitle: displayLabel,
        chipIcon: Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF00C896),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(LucideIcons.mapPin, size: 11, color: Colors.white),
          ),
        ),
        leadingWidget: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFF00C896),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(LucideIcons.mapPin, size: 24, color: Colors.white),
          ),
        ),
        trailingWidget: Icon(
          LucideIcons.chevronRight,
          size: 20,
          color: chevronColor,
        ),
        onTap: () async {
          final label = Uri.encodeComponent(location.feedDisplayLabel);
          final uri = Uri.parse(
            'https://www.google.com/maps/search/?api=1'
            '&query=${location.latitude},${location.longitude}($label)',
          );
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }

  // 3. Promotion / Sponsored
  if (post.isPromoted || post.promotion != null) {
    final promoLabel = post.promotion?.label ?? l10n.promotedBadge;
    links.add(
      PostLinkItem(
        type: PostLinkType.promotion,
        title: promoLabel,
        subtitle: 'Sponsored',
        chipTitle: promoLabel,
        chipIcon: const Icon(
          LucideIcons.flame,
          size: 12,
          color: Color(0xFFFF8C42),
        ),
        leadingWidget: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8C42),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(LucideIcons.flame, size: 24, color: Colors.white),
          ),
        ),
        onTap: () {},
      ),
    );
  }

  // 4. Auction
  if (post.isAuctionable && post.auction != null) {
    final auctionTitle = post.auction?.itemName ?? 'Live Auction';
    links.add(
      PostLinkItem(
        type: PostLinkType.auction,
        title: auctionTitle,
        subtitle: 'Auction',
        chipTitle: auctionTitle,
        chipIcon: const Icon(
          LucideIcons.gavel,
          size: 12,
          color: Color(0xFFFFD60A),
        ),
        leadingWidget: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF8E44AD),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(LucideIcons.gavel, size: 24, color: Colors.white),
          ),
        ),
        onTap: () {},
      ),
    );
  }

  return links;
}

Future<void> showPostLinksBottomSheet(
  BuildContext context, {
  required List<PostLinkItem> links,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final sheetBg = isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surface;
  final textPrimary = theme.colorScheme.onSurface;
  final textSecondary = theme.colorScheme.onSurface.withValues(alpha: 0.55);
  final dragHandleColor = theme.colorScheme.onSurface.withValues(alpha: 0.2);

  return showModalBottomSheet(
    context: context,
    backgroundColor: sheetBg,
    elevation: 0,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              // Drag Handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: dragHandleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              // Header title + Close X button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        'Links',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: Icon(
                            LucideIcons.x,
                            color: textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Links list
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: links.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = links[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        item.onTap();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          item.leadingWidget,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.trailingWidget != null) ...[
                            const SizedBox(width: 12),
                            item.trailingWidget!,
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// TikTok style Post Links / Labels chip.
/// Shows single label chip if 1 item exists, or first label + "+N" count badge
/// when multiple items exist. Clicking opens TikTok-style Links bottom sheet.
class PostLinksChip extends StatelessWidget {
  const PostLinksChip({required this.post, super.key});

  final PostEntity post;

  @override
  Widget build(BuildContext context) {
    final links = getPostLinkItems(context, post);
    if (links.isEmpty) return const SizedBox.shrink();

    // Single link: render standard single capsule pill
    if (links.length == 1) {
      final item = links.first;
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: GestureDetector(
          onTap: item.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.chipIcon != null) ...[
                  item.chipIcon!,
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    item.chipTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Multiple links: show ONLY first label + count badge (e.g., "Jeddah • +1")
    final first = links.first;
    final extraCount = links.length - 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: GestureDetector(
        onTap: () => showPostLinksBottomSheet(context, links: links),
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.fromLTRB(5, 4, 8, 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (first.chipIcon != null) ...[
                first.chipIcon!,
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  first.chipTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '• +$extraCount',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                LucideIcons.chevronDown,
                size: 14,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
