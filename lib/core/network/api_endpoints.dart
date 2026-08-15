/// Centralized API endpoint constants.
///
/// Override the host with `--dart-define=API_BASE_URL=https://api.example.com`
/// (no trailing slash). LiveKit `url` always comes from Nest start/join responses —
/// never hardcode LiveKit secrets or ports here.
class ApiEndpoints {
  ApiEndpoints._();

  /// Base URL for the Nest HTTP + Socket.IO host.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://134.209.2.225',
  );

  // ── Auth ──────────────────────────────────────────────
  static const String authSendOtp = '/auth/send-otp';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authResetPassword = '/auth/reset-password';
  static const String authLogin = '/auth/login';
  static const String authMe = '/auth/me';
  static const String authLogout = '/auth/logout';

  // ── Users ─────────────────────────────────────────────
  static const String usersMe = '/users/me';
  static const String usersMeInterests = '/users/me/interests';
  static const String usersMeReactivate = '/users/me/reactivate';
  static const String usersMeDeactivate = '/users/me/deactivate';

  // ── Lives (from lives/mobile-api.md) ───────────────────
  static const String lives = '/lives';
  static const String livesFeed = '/lives/feed';
  static const String livesMine = '/lives/mine';
  static String liveById(String id) => '/lives/$id';
  static String liveStart(String id) => '/lives/$id/start';
  static String liveEnd(String id) => '/lives/$id/end';
  static String liveJoin(String id) => '/lives/$id/join';
  static String liveLeave(String id) => '/lives/$id/leave';
  static String liveLike(String id) => '/lives/$id/like';
  static String liveComments(String id) => '/lives/$id/comments';
  static String liveCommentById(String liveId, String commentId) =>
      '/lives/$liveId/comments/$commentId';
  static String liveCommentPin(String liveId, String commentId) =>
      '/lives/$liveId/comments/$commentId/pin';
  static String liveCommentUnpin(String liveId, String commentId) =>
      '/lives/$liveId/comments/$commentId/unpin';
  static String liveSettings(String id) => '/lives/$id/settings';
  static String liveGuests(String id) => '/lives/$id/guests';
  static String liveGuestInvite(String id) => '/lives/$id/guests/invite';
  static String liveGuestAccept(String id, String userId) =>
      '/lives/$id/guests/$userId/accept';
  static String liveGuestReject(String id, String userId) =>
      '/lives/$id/guests/$userId/reject';
  static String liveGuestKick(String id, String userId) =>
      '/lives/$id/guests/$userId/kick';
  static String liveGuestMute(String id, String userId) =>
      '/lives/$id/guests/$userId/mute';
  static String liveGuestUnmute(String id, String userId) =>
      '/lives/$id/guests/$userId/unmute';
  static String liveGuestCameraOff(String id, String userId) =>
      '/lives/$id/guests/$userId/camera-off';
  static String liveGuestCameraOn(String id, String userId) =>
      '/lives/$id/guests/$userId/camera-on';
  static String liveGuestPromote(String id, String userId) =>
      '/lives/$id/guests/$userId/promote';
  static String liveGuestDemote(String id, String userId) =>
      '/lives/$id/guests/$userId/demote';
  static String liveGallery(String id) => '/lives/$id/gallery';
  static String liveAuctionPin(String liveId, String auctionId) =>
      '/lives/$liveId/auctions/$auctionId/pin';
  static String liveAuctionsReorder(String liveId) =>
      '/lives/$liveId/auctions/reorder';
  static String liveHourlyLeaderboard(String id) =>
      '/lives/$id/leaderboard/hourly';
  static String liveGiftersLeaderboard(String id) =>
      '/lives/$id/leaderboard/gifters';
  static const String livesHourlyLeaderboard = '/lives/leaderboard/hourly';
  static String liveViewerMuteChat(String liveId, String userId) =>
      '/lives/$liveId/viewers/$userId/mute-chat';
  static String liveViewerUnmuteChat(String liveId, String userId) =>
      '/lives/$liveId/viewers/$userId/unmute-chat';
  static String liveViewerBan(String liveId, String userId) =>
      '/lives/$liveId/viewers/$userId/ban';
  static String liveViewerUnban(String liveId, String userId) =>
      '/lives/$liveId/viewers/$userId/unban';
  static String liveSummary(String id) => '/lives/$id/summary';
  static const String giftsSend = '/gifts/send';

  // ── Fan Club (lives/mobile-api.md §20) ────────────────
  static String creatorsFanClub(String creatorId) =>
      '/creators/$creatorId/fan-club';
  static String creatorsFanClubSubscribe(String creatorId) =>
      '/creators/$creatorId/fan-club/subscribe';
  static String creatorsFanClubMembers(String creatorId) =>
      '/creators/$creatorId/fan-club/members';
  static const String usersMeFanClubs = '/users/me/fan-clubs';

  /// Builds a full URI for the given [path].
  static Uri uri(String path) => Uri.parse('$baseUrl$path');
}
