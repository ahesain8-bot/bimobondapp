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
    this.ownerUsername,
    this.ownerFullName,
    this.ownerAvatarUrl,
    this.ownerUserId,
    this.categorySlug,
    this.categoryLabel,
    this.isLive = false,
    this.isEnded = false,
    this.countdown,
    this.post,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int giftTotalCoins;
  final int giftCount;
  final String? ownerUsername;
  final String? ownerFullName;
  final String? ownerAvatarUrl;
  final String? ownerUserId;
  final String? categorySlug;
  final String? categoryLabel;
  final bool isLive;
  final bool isEnded;
  final String? countdown;
  final PostEntity? post;

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
      title: auction.itemName,
      subtitle: post.description?.trim().isNotEmpty == true
          ? post.description!.trim()
          : '',
      imageUrl: resolveAuctionPostImageUrl(post),
      giftTotalCoins: auction.currentTotalCoins,
      giftCount: auction.giftCount,
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
