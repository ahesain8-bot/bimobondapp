import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:equatable/equatable.dart';

enum UserMentionSourceType {
  post,
  comment,
  unknown,
}

class UserMentionEntity extends Equatable {
  const UserMentionEntity({
    required this.id,
    required this.sourceType,
    required this.postId,
    this.commentId,
    required this.content,
    required this.createdAt,
    this.user,
    this.post,
  });

  final String id;
  final UserMentionSourceType sourceType;
  final String postId;
  final String? commentId;
  final String content;
  final String createdAt;
  final SocialUserEntity? user;
  final PostEntity? post;

  bool get isCommentMention => sourceType == UserMentionSourceType.comment;

  @override
  List<Object?> get props => [
        id,
        sourceType,
        postId,
        commentId,
        content,
        createdAt,
        user,
        post,
      ];
}
