class ApiConstants {
  static const String baseUrl = 'http://134.209.2.225';
  static const String apiKey =
      'YOUR_API_KEY'; // Replace with your ReqRes API Key
  static const String backendLogin = '/auth/login';
  static const String authMe = '/auth/me';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String updateProfile = '/users/me';
  static const String updateUserLocation = '/users/me/location';
  static const String userLocationHistory = '/users/me/locations/history';
  static const String userLocationMovements = '/users/me/locations/movements';

  static const String promotionsOptions = '/promotions/options';
  static const String promotions = '/promotions';
  static const String promotionsPackages = '/promotions/packages';
  static const String promotionsMine = '/promotions/mine';
  static String promotionById(String id) => '/promotions/$id';
  static String promotionPay(String id) => '/promotions/$id/pay';
  static String promotionStats(String id) => '/promotions/$id/stats';
  static String promotionPause(String id) => '/promotions/$id/pause';
  static String promotionResume(String id) => '/promotions/$id/resume';
  static const String promotionsPosts = '/promotions/posts';
  static String promotionPostById(String postId) => '/promotions/posts/$postId';
  static String promotionPostStats(String postId) =>
      '/promotions/posts/$postId/stats';
  static const String uploadAvatar = '/users/avatar';
  static const String uploadMedia = '/posts/upload';
  static const String createPost = '/posts';
  static String postById(String postId) => '/posts/$postId';
  static const String getFeed = '/posts/feed';
  static const String publicFeed = '/posts/public/feed';
  static const String postsHashtags = '/posts/hashtags';
  static String toggleLike(String postId) => '/posts/$postId/like';
  static String postLikes(String postId) => '/posts/$postId/likes';
  static String postViews(String postId) => '/posts/$postId/views';
  static String recordPostView(String postId) => '/posts/$postId/view';
  static String toggleSave(String postId) => '/posts/$postId/save';
  static String toggleRepost(String postId) => '/posts/$postId/repost';
  static String postReposts(String postId) => '/posts/$postId/reposts';
  static String deleteRepost(String repostId) => '/posts/reposts/$repostId';
  static String postNotInterested(String postId) =>
      '/posts/$postId/not-interested';
  static String reportPost(String postId) => '/posts/$postId/report';
  static String sharePost(String postId) => '/posts/$postId/share';
  static String postMentions(String postId) => '/posts/$postId/mentions';
  static const String myReposts = '/users/me/reposts';
  static const String myLikedPosts = '/users/me/liked-posts';
  static const String mySavedPosts = '/users/me/saved-posts';
  static String userVideos(String userId) => '/users/$userId/videos';

  // Comments
  static String getComments(String postId) => '/posts/$postId/comments';
  static String addComment(String postId) => '/posts/$postId/comments';
  static String getReplies(String commentId) =>
      '/posts/comments/$commentId/replies';
  static String deleteComment(String commentId) => '/posts/comments/$commentId';
  static String toggleLikeComment(String commentId) =>
      '/posts/comments/$commentId/like';
  static String commentLikes(String commentId) =>
      '/posts/comments/$commentId/likes';

  static const String categories = '/categories';
  static String categoryById(String id) => '/categories/$id';

  static const String gifts = '/gifts';
  static const String giftsInventory = '/gifts/inventory';
  static const String giftsPurchase = '/gifts/purchase';
  static const String giftsSend = '/gifts/send';

  static const String walletsMe = '/wallets/me';
  static const String walletsPackages = '/wallets/packages';
  static const String walletsPurchase = '/wallets/purchase';
  static const String walletsTopUp = '/wallets/top-up';

  static String auctionById(String auctionId) => '/auctions/$auctionId';
  static const String auctions = '/auctions';
  static const String auctionsActive = '/auctions/active';
  static const String auctionsPricingPreview = '/auctions/pricing/preview';
  static const String auctionsSellerEligibility =
      '/auctions/seller-eligibility';
  static String auctionCancel(String auctionId) =>
      '/auctions/$auctionId/cancel';
  static String auctionFulfillment(String auctionId) =>
      '/auctions/$auctionId/fulfillment';
  static String auctionFulfillmentShip(String auctionId) =>
      '/auctions/$auctionId/fulfillment/ship';
  static String auctionFulfillmentReceive(String auctionId) =>
      '/auctions/$auctionId/fulfillment/receive';
  static String auctionFulfillmentAccept(String auctionId) =>
      '/auctions/$auctionId/fulfillment/accept';
  static String auctionFulfillmentDispute(String auctionId) =>
      '/auctions/$auctionId/fulfillment/dispute';
  static const String myAuctions = '/users/me/auctions';
  static String liveAuctions(String liveId) => '/lives/$liveId/auctions';
  static String liveAuctionsActive(String liveId) =>
      '/lives/$liveId/auctions/active';
  static String liveCreateAuction(String liveId) => '/lives/$liveId/auctions';

  // Seller verification (required to host auctions)
  static const String sellerVerification = '/seller-verification';
  static const String sellerVerificationEligibility =
      '/seller-verification/eligibility';
  static const String sellerVerificationMe = '/seller-verification/me';
  static const String sellerVerificationUpload = '/seller-verification/upload';

  // Stories (ephemeral; separate from posts)
  static const String stories = '/stories';
  static const String storiesRings = '/stories/rings';
  static const String storiesMe = '/stories/me';
  static String storiesByUser(String userId) => '/stories/user/$userId';
  static String storyById(String storyId) => '/stories/$storyId';
  static String storyView(String storyId) => '/stories/$storyId/view';
  static String storyViewers(String storyId) => '/stories/$storyId/viewers';

  static const String cameraStudioCatalog = '/camera-studio/catalog';
  static const String cameraStudioColorFilters = '/camera-studio/color-filters';
  static const String cameraStudioEffectPlacementSchema =
      '/camera-studio/effect-placement/schema';

  static String get cameraStudioCatalogUrl => '$baseUrl$cameraStudioCatalog';
  static String get cameraStudioColorFiltersUrl =>
      '$baseUrl$cameraStudioColorFilters';

  // Chats
  static const String chats = '/chats';
  static String chatById(String chatId) => '/chats/$chatId';
  static String chatMessages(String chatId) => '/chats/$chatId/messages';
  static String markMessageRead(String messageId) =>
      '/chats/messages/$messageId/read';
  static String reactToMessage(String messageId) =>
      '/chats/messages/$messageId/react';
  static String deleteMessage(String messageId) =>
      '/chats/messages/$messageId/delete';
  static String pollVote(String messageId) =>
      '/chats/messages/$messageId/poll-vote';

  // Friends (mutual follows)
  static const String myFriends = '/users/me/friends';
  static const String mySuggestions = '/users/me/suggestions';
  static const String myComments = '/users/me/comments';
  static const String myLikes = '/users/me/likes';
  static const String myMentions = '/users/me/mentions';
  static String userComments(String userId) => '/users/$userId/comments';
  static String followUser(String userId) => '/users/$userId/follow';
  static String userFollowers(String userId) => '/users/$userId/followers';
  static String userFollowing(String userId) => '/users/$userId/following';
  static String userById(String userId) => '/users/$userId';
  static String userFollowStatus(String userId) =>
      '/users/$userId/follow-status';
  static String blockUser(String userId) => '/users/$userId/block';
  static const String myBlocks = '/users/me/blocks';
  static String adminUserActivity(String userId) =>
      '/users/admin/$userId/activity';

  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';
  static const String notificationsClearRead = '/notifications/clear-read';
  static String notificationById(String id) => '/notifications/$id';
  static String notificationRead(String id) => '/notifications/$id/read';

  static const String sounds = '/sounds';
  static const String soundsTrending = '/sounds/trending';
  static const String soundsGroups = '/sounds/groups';
  static const String soundsMine = '/sounds/mine';
  static const String soundsUpload = '/sounds/upload';
  static const String soundsFromOriginal = '/sounds/from-original';
  static String soundById(String id) => '/sounds/$id';
  static String soundGroupById(String id) => '/sounds/groups/$id';
  static String soundSegments(String id) => '/sounds/$id/segments';
  static String soundSegmentById(String id) => '/sounds/segments/$id';

  // Search history
  static const String searchHistory = '/users/me/search-history';
  static String searchHistoryById(String id) => '/users/me/search-history/$id';
  static const String searchTrends = '/users/me/search-trends';
  static const String search = '/search';

  // Countries catalog (public)
  static const String countries = '/countries';
  static String countryCities(String code) => '/countries/$code/cities';

  // User interests
  static const String userInterests = '/users/me/interests';
}
