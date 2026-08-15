class ApiConstants {
  ApiConstants._();

  // Base URLs
  static const String baseUrl = 'https://api.tiktoklive.com/v1';
  static const String websocketUrl = 'wss://ws.tiktoklive.com';

  // Endpoints
  static const String livesFeed = '/lives/feed';
  static const String liveDetails = '/lives/{id}';
  static const String joinLive = '/lives/{id}/join';
  static const String leaveLive = '/lives/{id}/leave';
  static const String comments = '/comments';
  static const String sendGift = '/gifts/send';
  static const String likeLive = '/lives/{id}/like';

  // Timeouts
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;
  static const int sendTimeout = 30000;
}
