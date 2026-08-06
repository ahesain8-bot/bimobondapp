import 'package:bimobondapp/core/constants/traffic_source.dart';

enum HomeFeedTab {
  following,
  forYou,
}

extension HomeFeedTabX on HomeFeedTab {
  String? get feedSort => 'RANKED';

  /// Following feed uses `GET /posts/feed?from=FRIEND`.
  /// For You (public) omits `from`.
  String? get feedFrom {
    switch (this) {
      case HomeFeedTab.forYou:
        return null;
      case HomeFeedTab.following:
        return 'FRIEND';
    }
  }

  String get trafficSource {
    switch (this) {
      case HomeFeedTab.forYou:
        return TrafficSource.forYou;
      case HomeFeedTab.following:
        return TrafficSource.following;
    }
  }
}
