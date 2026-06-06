import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:equatable/equatable.dart';

class PostViewEntity extends Equatable {
  const PostViewEntity({
    required this.id,
    required this.userId,
    required this.postId,
    this.watchedDuration,
    this.createdAt,
    this.user,
  });

  final String id;
  final String userId;
  final String postId;
  final int? watchedDuration;
  final DateTime? createdAt;
  final SocialUserEntity? user;

  bool get hasViewerProfile =>
      user != null || userId.trim().isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        userId,
        postId,
        watchedDuration,
        createdAt,
        user,
      ];
}
