import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:equatable/equatable.dart';

class CommentEntity extends Equatable {
  final String id;
  final String content;
  final String postId;
  final UserEntity user;
  final String? parentId;
  final int likeCount;
  final int replyCount;
  final bool isLiked;
  final bool isGift;
  final String? giftName;
  final String? giftIcon;
  final String createdAt;
  final String updatedAt;

  const CommentEntity({
    required this.id,
    required this.content,
    required this.postId,
    required this.user,
    this.parentId,
    this.likeCount = 0,
    this.replyCount = 0,
    this.isLiked = false,
    this.isGift = false,
    this.giftName,
    this.giftIcon,
    required this.createdAt,
    required this.updatedAt,
  });

  CommentEntity copyWith({
    int? likeCount,
    bool? isLiked,
    int? replyCount,
    bool? isGift,
    String? giftName,
    String? giftIcon,
  }) {
    return CommentEntity(
      id: id,
      content: content,
      postId: postId,
      user: user,
      parentId: parentId,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      isLiked: isLiked ?? this.isLiked,
      isGift: isGift ?? this.isGift,
      giftName: giftName ?? this.giftName,
      giftIcon: giftIcon ?? this.giftIcon,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        content,
        postId,
        user,
        parentId,
        likeCount,
        replyCount,
        isLiked,
        isGift,
        giftName,
        giftIcon,
        createdAt,
        updatedAt,
      ];
}
