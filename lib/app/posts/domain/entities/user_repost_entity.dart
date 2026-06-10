import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:equatable/equatable.dart';

class UserRepostEntity extends Equatable {
  const UserRepostEntity({
    required this.id,
    required this.userId,
    required this.postId,
    this.quote,
    required this.createdAt,
    required this.post,
  });

  final String id;
  final String userId;
  final String postId;
  final String? quote;
  final DateTime createdAt;
  final PostEntity post;

  @override
  List<Object?> get props => [id, userId, postId, quote, createdAt, post];
}

class UserRepostsPageEntity extends Equatable {
  const UserRepostsPageEntity({
    required this.reposts,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<UserRepostEntity> reposts;
  final int page;
  final int lastPage;
  final int total;

  bool get hasReachedMax => page >= lastPage;

  @override
  List<Object?> get props => [reposts, page, lastPage, total];
}
