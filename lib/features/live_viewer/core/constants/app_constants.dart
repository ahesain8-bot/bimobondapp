class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'TikTok Live';
  static const String appVersion = '1.0.0';

  // Pagination
  static const int defaultPageSize = 10;
  static const int defaultInitialPage = 1;

  // Animation Durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  // Delays
  static const Duration debounceTime = Duration(milliseconds: 500);
  static const Duration throttleTime = Duration(milliseconds: 500);

  // Cache
  static const Duration cacheMaxAge = Duration(hours: 24);
  static const int maxCacheSize = 100;

  // Image
  static const int maxImageWidth = 1200;
  static const int maxImageHeight = 1200;
  static const int imageQuality = 85;

  // Live
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const int maxReconnectAttempts = 5;
  static const Duration heartbeatInterval = Duration(seconds: 30);
}
