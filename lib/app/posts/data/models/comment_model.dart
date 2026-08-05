import 'package:bimobondapp/app/auth/data/models/user_model.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/posts/data/models/mention_ref_model.dart';
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
    super.giftThumbnailUrl,
    super.giftAnimationUrl,
    super.giftCatalogType,
    super.giftColor,
    super.giftAudioUrl,
    super.giftSize,
    required super.createdAt,
    required super.updatedAt,
    super.mentions = const [],
  });

  static String? _giftField(Map<String, dynamic> json, String key) {
    final gift = json['gift'];
    if (gift is Map) {
      final value = gift[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final directKey = switch (key) {
      'name' => 'giftName',
      'icon' => 'giftIcon',
      'thumbnailUrl' => 'giftThumbnailUrl',
      'animationUrl' => 'giftAnimationUrl',
      _ => key,
    };
    final direct = json[directKey]?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return null;
  }

  static GiftCatalogType? _giftCatalogType(Map<String, dynamic> json) {
    final gift = json['gift'];
    final candidates = <dynamic>[
      if (gift is Map) gift['type'],
      if (gift is Map) gift['catalogType'],
      if (gift is Map) gift['tag'],
      json['giftType'],
      json['giftCatalogType'],
    ];
    for (final raw in candidates) {
      final value = raw?.toString().trim().toUpperCase();
      if (value == null || value.isEmpty) continue;
      if (value == 'AUDIO' ||
          value == 'SONG' ||
          value == 'SONGS' ||
          value == 'SOUND' ||
          value == 'MUSIC') {
        return GiftCatalogType.audio;
      }
      if (value == 'IMAGE') return GiftCatalogType.image;
    }
    final audioUrl = _giftAudioUrl(json);
    if (audioUrl != null && audioUrl.isNotEmpty) {
      return GiftCatalogType.audio;
    }
    return null;
  }

  static String? _giftColor(Map<String, dynamic> json) {
    final gift = json['gift'];
    if (gift is Map) {
      final value = gift['color']?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _giftAudioUrl(Map<String, dynamic> json) {
    final gift = json['gift'];
    if (gift is Map) {
      for (final key in ['audioUrl', 'audio_url']) {
        final value = gift[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    for (final key in ['giftAudioUrl', 'audioUrl', 'audio_url']) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    UserModel parsedUser;
    if (json['user'] is Map) {
      parsedUser = UserModel.fromJson(Map<String, dynamic>.from(json['user']));
    } else if (json['user'] is String) {
      parsedUser = UserModel(id: json['user']);
    } else if (json['userId'] != null &&
        json['userId'].toString().trim().isNotEmpty) {
      parsedUser = UserModel(id: json['userId'].toString());
    } else {
      parsedUser = const UserModel(id: '');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final thumbnail = _giftField(json, 'thumbnailUrl') ??
        _giftField(json, 'imageUrl');
    final iconRaw = _giftField(json, 'icon');
    final iconIsUrl =
        iconRaw != null &&
        (iconRaw.startsWith('http://') ||
            iconRaw.startsWith('https://') ||
            iconRaw.startsWith('/') ||
            iconRaw.contains('uploads/'));

    final catalogType = _giftCatalogType(json);
    final isAudio = catalogType == GiftCatalogType.audio;

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
      giftIcon: isAudio ? null : (iconIsUrl ? null : iconRaw),
      giftThumbnailUrl: isAudio
          ? null
          : (thumbnail ?? (iconIsUrl ? iconRaw : null)),
      giftAnimationUrl: isAudio ? null : _giftField(json, 'animationUrl'),
      giftCatalogType: catalogType,
      giftColor: _giftColor(json),
      giftAudioUrl: _giftAudioUrl(json),
      giftSize: _giftSize(json),
      createdAt: json['createdAt']?.toString() ?? now,
      updatedAt: json['updatedAt']?.toString() ?? now,
      mentions: MentionRefModel.listFromJson(json['mentions']),
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

  static GiftCatalogSize? _giftSize(Map<String, dynamic> json) {
    final raw = _giftField(json, 'size');
    if (raw == null || raw.isEmpty) return null;
    final value = raw.toUpperCase();
    return switch (value) {
      'MEDIUM' => GiftCatalogSize.medium,
      'LARGE' => GiftCatalogSize.large,
      'SMALL' => GiftCatalogSize.small,
      _ => null,
    };
  }
}
