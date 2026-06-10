import 'package:equatable/equatable.dart';

class RepostEntity extends Equatable {
  const RepostEntity({
    required this.id,
    required this.userId,
    required this.postId,
    this.quote,
    required this.createdAt,
    this.user,
  });

  final String id;
  final String userId;
  final String postId;
  final String? quote;
  final DateTime createdAt;
  final RepostUserEntity? user;

  @override
  List<Object?> get props => [id, userId, postId, quote, createdAt, user];
}

class RepostUserEntity extends Equatable {
  const RepostUserEntity({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.isVerified = false,
    this.repostedAt,
    this.quote,
  });

  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime? repostedAt;
  final String? quote;

  @override
  List<Object?> get props =>
      [id, username, fullName, avatarUrl, isVerified, repostedAt, quote];
}

class RepostsPageEntity extends Equatable {
  const RepostsPageEntity({
    required this.reposts,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<RepostEntity> reposts;
  final int page;
  final int lastPage;
  final int total;

  bool get hasReachedMax => page >= lastPage;

  @override
  List<Object?> get props => [reposts, page, lastPage, total];
}
