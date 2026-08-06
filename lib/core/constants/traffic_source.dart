/// Canonical `trafficSource` values for `POST /posts/:id/view`.
///
/// Use UPPER_SNAKE_CASE. Server uppercases/trims input; send these directly.
abstract final class PostTrafficSource {
  PostTrafficSource._();

  /// Home / For You feed (default if omitted).
  static const forYou = 'FOR_YOU';

  /// Following feed.
  static const following = 'FOLLOWING';

  /// User profile → posts tab.
  static const profile = 'PROFILE';

  /// Search results.
  static const search = 'SEARCH';

  /// Hashtag or category page.
  static const hashtags = 'HASHTAGS';

  /// Opened from share link / deep link.
  static const shares = 'SHARES';

  /// Sound detail page.
  static const sound = 'SOUND';

  /// Live-related post discovery.
  static const live = 'LIVE';

  /// Opened from a push / in-app notification.
  static const notification = 'NOTIFICATION';

  /// Saved posts list.
  static const saved = 'SAVED';

  /// Liked posts list.
  static const liked = 'LIKED';

  /// Repost feed or repost detail.
  static const repost = 'REPOST';

  /// Post opened from chat share.
  static const chat = 'CHAT';

  /// Anything that does not fit above.
  static const other = 'OTHER';
}

/// Alias kept for older call sites; prefer [PostTrafficSource].
typedef TrafficSource = PostTrafficSource;
