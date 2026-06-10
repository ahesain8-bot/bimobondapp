import 'package:bimobondapp/app/posts/data/models/post_model.dart';
import 'package:bimobondapp/app/posts/data/models/repost_model.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';

class FeedItemModel extends FeedItemEntity {
  const FeedItemModel({
    required super.id,
    required super.feedType,
    required super.sortAt,
    required super.post,
    super.repostId,
    super.repostedAt,
    super.quote,
    super.repostedBy,
  });

  factory FeedItemModel.fromJson(Map<String, dynamic> json) {
    final postJson = json['post'];
    final hasUnifiedShape =
        json.containsKey('feedType') && postJson is Map<String, dynamic>;

    if (!hasUnifiedShape) {
      final post = PostModel.fromJson(json);
      return FeedItemModel(
        id: post.id,
        feedType: FeedItemType.post,
        sortAt: post.createdAt,
        post: post,
      );
    }

    final post = PostModel.fromJson(postJson);
    final feedTypeRaw = json['feedType']?.toString().toUpperCase() ?? 'POST';
    final sortAt = _parseDateTime(json['sortAt']) ?? post.createdAt;
    final recentRepostersRaw = json['recentReposters'];
    final postWithReposters = recentRepostersRaw is List && post.recentReposters.isEmpty
        ? post.copyWith(
            recentReposters: recentRepostersRaw
                .whereType<Map>()
                .map((e) => RepostUserModel.fromJson(Map<String, dynamic>.from(e)))
                .toList(),
          )
        : post;

    final quote = _parseQuote(json);

    if (feedTypeRaw == 'REPOST') {
      final repostedByJson = json['repostedBy'];
      return FeedItemModel(
        id: json['repostId']?.toString() ??
            '${postWithReposters.id}_${repostedByJson is Map ? repostedByJson['id'] : 'repost'}',
        feedType: FeedItemType.repost,
        sortAt: sortAt,
        post: postWithReposters,
        repostId: json['repostId']?.toString(),
        repostedAt: _parseDateTime(json['repostedAt']),
        quote: quote,
        repostedBy: repostedByJson is Map<String, dynamic>
            ? RepostUserModel.fromJson(repostedByJson)
            : null,
      );
    }

    return FeedItemModel(
      id: postWithReposters.id,
      feedType: FeedItemType.post,
      sortAt: sortAt,
      post: postWithReposters,
      quote: quote,
    );
  }

  static String? _parseQuote(Map<String, dynamic> json) {
    for (final key in ['quote', 'comment', 'caption', 'text', 'message']) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final repost = json['repost'];
    if (repost is Map) {
      return _parseQuote(Map<String, dynamic>.from(repost));
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
