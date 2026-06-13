enum NotificationsCategoryFilter {
  all,
  activity,
  auctions,
  invites,
}

extension NotificationsCategoryFilterX on NotificationsCategoryFilter {
  bool matches(String type) {
    return switch (this) {
      NotificationsCategoryFilter.all => true,
      NotificationsCategoryFilter.activity => const {
            'POST_LIKE',
            'POST_COMMENT',
            'COMMENT_REPLY',
            'COMMENT_LIKE',
            'MENTION',
            'REPOST',
            'GIFT_RECEIVED',
          }.contains(type),
      NotificationsCategoryFilter.auctions => const {
            'AUCTION_UPDATE',
            'AUCTION_WON',
          }.contains(type),
      NotificationsCategoryFilter.invites => const {
            'NEW_FOLLOWER',
            'FOLLOW_REQUEST',
            'FOLLOW_REQUEST_ACCEPTED',
          }.contains(type),
    };
  }
}
