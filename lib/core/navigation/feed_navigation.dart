import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigates away from the feed while pausing videos; resumes when the route
/// is popped.
extension FeedNavigation on BuildContext {
  Future<T?> pushFromFeed<T extends Object?>(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) {
    return FeedNavigationHelper.pushNamed<T>(
      this,
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }
}

class FeedNavigationHelper {
  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) async {
    FeedPlaybackGate.instance.setBlocked(true);
    try {
      return await context.pushNamed<T>(
        name,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
        extra: extra,
      );
    } finally {
      FeedPlaybackGate.instance.syncFromRouter();
    }
  }

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    String location, {
    Object? extra,
  }) async {
    FeedPlaybackGate.instance.setBlocked(true);
    try {
      return await context.push<T>(location, extra: extra);
    } finally {
      FeedPlaybackGate.instance.syncFromRouter();
    }
  }
}
