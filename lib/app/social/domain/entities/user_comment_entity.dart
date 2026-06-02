import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comment_post_entity.dart';
import 'package:equatable/equatable.dart';

class UserCommentEntity extends Equatable {
  const UserCommentEntity({
    required this.id,
    required this.content,
    required this.postId,
    required this.userId,
    this.parentId,
    this.likeCount = 0,
    this.replyCount = 0,
    this.isGift = false,
    this.giftId,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.post,
  });

  final String id;
  final String content;
  final String postId;
  final String userId;
  final String? parentId;
  final int likeCount;
  final int replyCount;
  final bool isGift;
  final String? giftId;
  final String createdAt;
  final String updatedAt;
  final SocialUserEntity? user;
  final UserCommentPostEntity? post;

  SocialUserEntity? get author => user;

  bool get isReply => parentId != null && parentId!.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        content,
        postId,
        userId,
        parentId,
        likeCount,
        replyCount,
        isGift,
        giftId,
        createdAt,
        updatedAt,
        user,
        post,
      ];
}
