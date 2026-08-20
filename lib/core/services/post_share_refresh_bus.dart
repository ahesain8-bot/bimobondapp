import 'package:flutter/foundation.dart';

/// Minimal signal bus: notifies the feed when a post is shared so its share
/// counter moves straight away, instead of waiting for the next refetch.
///
/// The share is tracked from the options sheet, which sits outside the post
/// widget, so there is no callback path back down to it.
class PostShareRefreshBus extends ChangeNotifier {
  PostShareRefreshBus._();

  static final PostShareRefreshBus instance = PostShareRefreshBus._();

  String? _lastSharedPostId;
  int? _lastShareCount;

  String? get lastSharedPostId => _lastSharedPostId;

  /// Server-reported total after the share, or `null` when it did not say.
  int? get lastShareCount => _lastShareCount;

  void notifyPostShared(String postId, {int? shareCount}) {
    _lastSharedPostId = postId;
    _lastShareCount = shareCount;
    notifyListeners();
  }
}
