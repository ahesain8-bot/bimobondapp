import 'package:bimobondapp/app/posts/data/models/feed_item_model.dart';

class FeedRemotePage {
  const FeedRemotePage({
    required this.items,
    this.nextCursor,
    required this.hasReachedMax,
  });

  final List<FeedItemModel> items;
  final String? nextCursor;
  final bool hasReachedMax;
}
