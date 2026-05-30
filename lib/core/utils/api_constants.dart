class ApiConstants {
  static const String baseUrl = 'http://192.168.1.123:3000';
  static const String apiKey =
      'YOUR_API_KEY'; // Replace with your ReqRes API Key
  static const String login = '/login';
  static const String backendLogin = '/auth/login';
  static const String authMe = '/auth/me';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String register = '/register';
  static const String updateProfile = '/users/me';
  static const String uploadAvatar = '/users/avatar';
  static const String uploadMedia = '/posts/upload';
  static const String createPost = '/posts';
  static String postById(String postId) => '/posts/$postId';
  static const String getFeed = '/posts/feed';
  static const String publicFeed = '/posts/public/feed';
  static String toggleLike(String postId) => '/posts/$postId/like';
  static String toggleSave(String postId) => '/posts/$postId/save';
  
  // Comments
  static String getComments(String postId) => '/posts/$postId/comments';
  static String addComment(String postId) => '/posts/$postId/comments';
  static String getReplies(String commentId) => '/posts/comments/$commentId/replies';
  static String deleteComment(String commentId) => '/posts/comments/$commentId';
  static String toggleLikeComment(String commentId) => '/posts/comments/$commentId/like';

  static const String categories = '/categories';

  static const String gifts = '/gifts';
  static const String giftsInventory = '/gifts/inventory';
  static const String giftsPurchase = '/gifts/purchase';
  static const String giftsSend = '/gifts/send';

  static String auctionById(String auctionId) => '/auctions/$auctionId';

  // Chats
  static const String chats = '/chats';
  static String chatMessages(String chatId) => '/chats/$chatId/messages';
  static String markMessageRead(String messageId) =>
      '/chats/messages/$messageId/read';
  static String reactToMessage(String messageId) =>
      '/chats/messages/$messageId/react';
  static String deleteMessage(String messageId) =>
      '/chats/messages/$messageId/delete';

  // Friends (mutual follows)
  static const String myFriends = '/users/me/friends';
  static String followUser(String userId) => '/users/$userId/follow';
  static String userFollowers(String userId) => '/users/$userId/followers';
  static String userFollowing(String userId) => '/users/$userId/following';
  static String userById(String userId) => '/users/$userId';
}
