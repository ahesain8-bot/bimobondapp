import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/mention_ref_entity.dart';
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
  final String? giftThumbnailUrl;
  final String? giftAnimationUrl;
  final GiftCatalogType? giftCatalogType;
  final String? giftColor;
  final String? giftAudioUrl;
  final String createdAt;
  final String updatedAt;
  final List<MentionRefEntity> mentions;

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
    this.giftThumbnailUrl,
    this.giftAnimationUrl,
    this.giftCatalogType,
    this.giftColor,
    this.giftAudioUrl,
    required this.createdAt,
    required this.updatedAt,
    this.mentions = const [],
  });

  CommentEntity copyWith({
    int? likeCount,
    bool? isLiked,
    int? replyCount,
    bool? isGift,
    String? giftName,
    String? giftIcon,
    String? giftThumbnailUrl,
    String? giftAnimationUrl,
    GiftCatalogType? giftCatalogType,
    String? giftColor,
    String? giftAudioUrl,
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
      giftThumbnailUrl: giftThumbnailUrl ?? this.giftThumbnailUrl,
      giftAnimationUrl: giftAnimationUrl ?? this.giftAnimationUrl,
      giftCatalogType: giftCatalogType ?? this.giftCatalogType,
      giftColor: giftColor ?? this.giftColor,
      giftAudioUrl: giftAudioUrl ?? this.giftAudioUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      mentions: mentions,
    );
  }

  bool get isAudioGiftComment =>
      giftCatalogType == GiftCatalogType.audio ||
      (giftAudioUrl != null && giftAudioUrl!.trim().isNotEmpty);

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
        giftThumbnailUrl,
        giftAnimationUrl,
        giftCatalogType,
        giftColor,
        giftAudioUrl,
        createdAt,
        updatedAt,
        mentions,
      ];
}
