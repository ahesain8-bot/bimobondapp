import 'package:bimobondapp/app/auth/data/models/user_model.dart';
import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';

class CommentModel extends CommentEntity {
  const CommentModel({
    required super.id,
    required super.content,
    required super.postId,
    required super.user,
    super.parentId,
    super.likeCount,
    super.replyCount,
    super.isLiked,
    super.isGift,
    super.giftName,
    super.giftIcon,
    required super.createdAt,
    required super.updatedAt,
  });

  static String? _giftField(Map<String, dynamic> json, String key) {
    final gift = json['gift'];
    if (gift is Map) {
      final value = gift[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final directKey = key == 'name' ? 'giftName' : 'giftIcon';
    final direct = json[directKey]?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return null;
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    UserModel parsedUser;
    if (json['user'] is Map) {
      parsedUser = UserModel.fromJson(Map<String, dynamic>.from(json['user']));
    } else if (json['user'] is String) {
      parsedUser = UserModel(id: json['user']);
    } else {
      parsedUser = const UserModel(id: '');
    }

    return CommentModel(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      user: parsedUser,
      parentId: json['parentId']?.toString(),
      likeCount: json['likeCount'] is num 
          ? (json['likeCount'] as num).toInt() 
          : int.tryParse(json['likeCount']?.toString() ?? '0') ?? 0,
      replyCount: json['replyCount'] is num 
          ? (json['replyCount'] as num).toInt() 
          : int.tryParse(json['replyCount']?.toString() ?? '0') ?? 0,
      isLiked: json['isLiked'] is bool 
          ? json['isLiked'] 
          : json['isLiked']?.toString().toLowerCase() == 'true',
      isGift: json['isGift'] is bool
          ? json['isGift']
          : json['isGift']?.toString().toLowerCase() == 'true',
      giftName: _giftField(json, 'name'),
      giftIcon: _giftField(json, 'icon'),
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'postId': postId,
      'parentId': parentId,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'isLiked': isLiked,
      'isGift': isGift,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
