import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/repost_entity.dart';
import 'package:equatable/equatable.dart';

enum FeedItemType { post, repost }

enum FeedContentType { all, posts, reposts }

extension FeedContentTypeQuery on FeedContentType {
  String get apiValue {
    switch (this) {
      case FeedContentType.all:
        return 'ALL';
      case FeedContentType.posts:
        return 'POSTS';
      case FeedContentType.reposts:
        return 'REPOSTS';
    }
  }
}

class FeedItemEntity extends Equatable {
  const FeedItemEntity({
    required this.id,
    required this.feedType,
    required this.sortAt,
    required this.post,
    this.repostId,
    this.repostedAt,
    this.quote,
    this.repostedBy,
  });

  final String id;
  final FeedItemType feedType;
  final DateTime sortAt;
  final PostEntity post;
  final String? repostId;
  final DateTime? repostedAt;
  final String? quote;
  final RepostUserEntity? repostedBy;

  bool get isRepost => feedType == FeedItemType.repost;

  FeedItemEntity copyWith({PostEntity? post}) {
    return FeedItemEntity(
      id: id,
      feedType: feedType,
      sortAt: sortAt,
      post: post ?? this.post,
      repostId: repostId,
      repostedAt: repostedAt,
      quote: quote,
      repostedBy: repostedBy,
    );
  }

  @override
  List<Object?> get props => [
    id,
    feedType,
    sortAt,
    post,
    repostId,
    repostedAt,
    quote,
    repostedBy,
  ];
}
