import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:equatable/equatable.dart';

class UserLikeEntity extends Equatable {
  const UserLikeEntity({
    required this.id,
    required this.postId,
    required this.createdAt,
    this.user,
    this.post,
  });

  final String id;
  final String postId;
  final String createdAt;
  /// User who liked the post (incoming like).
  final SocialUserEntity? user;
  final PostEntity? post;

  @override
  List<Object?> get props => [id, postId, createdAt, user, post];
}
