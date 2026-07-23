import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_search_filters.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

class AuctionItem {
  const AuctionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.giftTotalCoins,
    required this.giftCount,
    this.highestPriceCoins = 0,
    this.targetPriceCoins = 0,
    this.ownerUsername,
    this.ownerFullName,
    this.ownerAvatarUrl,
    this.ownerUserId,
    this.categorySlug,
    this.categoryLabel,
    this.isLive = false,
    this.isEnded = false,
    this.countdown,
    this.startedAt,
    this.endedAt,
    this.post,
    this.auctionId,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int giftTotalCoins;
  final int giftCount;
  /// Current highest price (starting + gifts, or gifts when starting is 0).
  final int highestPriceCoins;
  final int targetPriceCoins;
  final String? ownerUsername;
  final String? ownerFullName;
  final String? ownerAvatarUrl;
  final String? ownerUserId;
  final String? categorySlug;
  final String? categoryLabel;
  final bool isLive;
  final bool isEnded;
  final String? countdown;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final PostEntity? post;
  final String? auctionId;

  /// True when status is terminal or [endedAt] has passed (re-evaluated now).
  bool get isEndedNow {
    if (isEnded) return true;
    final end = endedAt?.toUtc();
    if (end == null) return false;
    return !end.isAfter(DateTime.now().toUtc());
  }

  AuctionItem copyWith({
    bool? isLive,
    bool? isEnded,
    String? countdown,
  }) {
    return AuctionItem(
      id: id,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      giftTotalCoins: giftTotalCoins,
      giftCount: giftCount,
      highestPriceCoins: highestPriceCoins,
      targetPriceCoins: targetPriceCoins,
      ownerUsername: ownerUsername,
      ownerFullName: ownerFullName,
      ownerAvatarUrl: ownerAvatarUrl,
      ownerUserId: ownerUserId,
      categorySlug: categorySlug,
      categoryLabel: categoryLabel,
      isLive: isLive ?? this.isLive,
      isEnded: isEnded ?? this.isEnded,
      countdown: countdown,
      startedAt: startedAt,
      endedAt: endedAt,
      post: post,
      auctionId: auctionId,
    );
  }

  factory AuctionItem.fromAuction(
    AuctionDetailsEntity auction, {
    String? categoryLabel,
    String? categorySlug,
  }) {
    final now = DateTime.now().toUtc();
    final startedAt = auction.startedAt?.toUtc() ?? now;
    final endedAt = auction.endedAt?.toUtc();
    final isEnded = auction.isEnded ||
        (endedAt != null && !endedAt.isAfter(now));
    final isLive = !isEnded && auction.isActive;
    final countdown = isEnded || endedAt == null
        ? null
        : formatAuctionCountdown(now, startedAt, endedAt);
    final ownerHandle = auction.host.username?.trim();
    final hasOwnerHandle = ownerHandle != null && ownerHandle.isNotEmpty;
    final image = auction.itemImageUrl?.trim();
    final targetCoins = auction.pricing?.estimatedBidderSpendCoins?.round() ??
        auction.targetPriceCoins;

    return AuctionItem(
      id: auction.postId?.isNotEmpty == true ? auction.postId! : auction.id,
      auctionId: auction.id,
      title: auction.itemName.isNotEmpty ? auction.itemName : 'Auction',
      subtitle: '',
      imageUrl: image != null && image.isNotEmpty
          ? MediaUtils.resolveAbsoluteUrl(image)
          : '',
      giftTotalCoins: auction.currentTotalCoins,
      giftCount: auction.giftCount,
      highestPriceCoins: auction.displayHighestPriceCoins,
      targetPriceCoins: targetCoins,
      ownerUsername: hasOwnerHandle ? ownerHandle : null,
      ownerFullName: auction.host.fullName?.trim().isNotEmpty == true
          ? auction.host.fullName!.trim()
          : null,
      ownerAvatarUrl: auction.host.avatarUrl,
      ownerUserId: auction.host.id,
      categorySlug: categorySlug,
      categoryLabel: categoryLabel,
      isLive: isLive,
      isEnded: isEnded,
      countdown: countdown,
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }

  factory AuctionItem.fromPost(
    PostEntity post, {
    String? categoryLabel,
    String? categorySlug,
  }) {
    final auction = post.auction!;
    final now = DateTime.now().toUtc();
    final startedAt = auction.startedAt.toUtc();
    final endedAt = auction.endedAt.toUtc();
    final isEnded = AuctionSearchFilters.isPostEnded(post);
    final isLive = AuctionSearchFilters.isPostLive(post);
    final countdown =
        isEnded ? null : formatAuctionCountdown(now, startedAt, endedAt);
    final owner = post.user;
    final ownerHandle = owner?.username.trim();
    final hasOwnerHandle =
        ownerHandle != null && ownerHandle.isNotEmpty;

    return AuctionItem(
      id: post.id,
      auctionId: auction.id,
      title: auction.itemName,
      subtitle: post.description?.trim().isNotEmpty == true
          ? post.description!.trim()
          : '',
      imageUrl: resolveAuctionPostImageUrl(post),
      giftTotalCoins: auction.currentTotalCoins,
      giftCount: auction.giftCount,
      highestPriceCoins: auction.displayHighestPriceCoins,
      targetPriceCoins: auction.displayBidderSpendCoins.round(),
      ownerUsername: hasOwnerHandle ? ownerHandle : null,
      ownerFullName: owner?.fullName?.trim().isNotEmpty == true
          ? owner!.fullName!.trim()
          : null,
      ownerAvatarUrl: owner?.avatarUrl,
      ownerUserId: owner?.id ?? post.userId,
      categorySlug: categorySlug,
      categoryLabel: categoryLabel,
      isLive: isLive,
      isEnded: isEnded,
      countdown: countdown,
      startedAt: startedAt,
      endedAt: endedAt,
      post: post,
    );
  }
}

String resolveAuctionPostImageUrl(PostEntity post) {
  return MediaUtils.resolvePostCoverUrl(post) ?? '';
}

String? formatAuctionCountdown(
  DateTime now,
  DateTime startedAt,
  DateTime endedAt,
) {
  if (endedAt.isBefore(now) || endedAt.isAtSameMomentAs(now)) {
    return null;
  }
  final target = startedAt.isAfter(now) ? startedAt : endedAt;
  final diff = target.difference(now);
  final hours = diff.inHours.remainder(24).toString().padLeft(2, '0');
  final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (diff.inDays > 0) {
    return '${diff.inDays}d $hours:$minutes:$seconds';
  }
  return '$hours:$minutes:$seconds';
}
