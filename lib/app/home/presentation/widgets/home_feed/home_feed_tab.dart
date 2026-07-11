enum HomeFeedTab {
  following,
  forYou,
}

extension HomeFeedTabX on HomeFeedTab {
  /// Both tabs use the ranked feed until a dedicated following feed is wired up.
  String? get feedSort => 'RANKED';
}
