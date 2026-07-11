import 'package:bimobondapp/app/posts/domain/entities/post_privacy_status.dart';

enum HomeFeedTab {
  following,
  forYou,
}

extension HomeFeedTabX on HomeFeedTab {
  String? get feedSort => 'RANKED';

  /// For You shows public posts; Following shows friends-only posts.
  PostPrivacyStatus get feedPrivacyStatus {
    switch (this) {
      case HomeFeedTab.forYou:
        return PostPrivacyStatus.public;
      case HomeFeedTab.following:
        return PostPrivacyStatus.friends;
    }
  }
}
