import 'package:bimobondapp/app/posts/data/models/feed_item_model.dart';
import 'package:bimobondapp/app/posts/data/models/post_model.dart';
import 'package:bimobondapp/app/posts/domain/entities/repost_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/user_repost_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

int? _parsePaginationInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class RepostUserModel extends RepostUserEntity {
  const RepostUserModel({
    required super.id,
    required super.username,
    super.fullName,
    super.avatarUrl,
    super.isVerified,
    super.repostedAt,
    super.quote,
  });

  static String? _parseQuote(Map<String, dynamic> json) {
    for (final key in ['quote', 'comment', 'caption', 'text', 'message']) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  factory RepostUserModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final source = userJson is Map
        ? Map<String, dynamic>.from(userJson)
        : json;

    final avatarRaw = source['avatarUrl'] ??
        source['profilePicture'] ??
        source['profileImage'] ??
        source['photoURL'] ??
        source['photoUrl'] ??
        source['image'] ??
        source['avatar'] ??
        json['avatarUrl'];

    return RepostUserModel(
      id: source['id']?.toString() ?? json['userId']?.toString() ?? '',
      username: source['username']?.toString() ?? '',
      fullName: source['fullName']?.toString() ?? source['name']?.toString(),
      avatarUrl: avatarRaw != null
          ? MediaUtils.resolveAbsoluteUrl(avatarRaw.toString())
          : null,
      isVerified: source['isVerified'] == true,
      repostedAt: json['repostedAt'] != null
          ? DateTime.tryParse(json['repostedAt'].toString())
          : source['repostedAt'] != null
              ? DateTime.tryParse(source['repostedAt'].toString())
              : null,
      quote: _parseQuote(json),
    );
  }
}

class RepostModel extends RepostEntity {
  const RepostModel({
    required super.id,
    required super.userId,
    required super.postId,
    super.quote,
    required super.createdAt,
    super.user,
  });

  static String? _parseQuote(Map<String, dynamic> json) {
    for (final key in ['quote', 'comment', 'caption', 'text', 'message']) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  factory RepostModel.fromJson(Map<String, dynamic> json) {
    return RepostModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      quote: _parseQuote(json),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      user: json['user'] is Map<String, dynamic>
          ? RepostUserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

class RepostsPageModel extends RepostsPageEntity {
  const RepostsPageModel({
    required super.reposts,
    required super.page,
    required super.lastPage,
    required super.total,
  });

  factory RepostsPageModel.fromResponse(
    dynamic body, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final root = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final data = root['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : root;
    final raw = map['reposts'] ?? map['items'] ?? root['reposts'];
    final reposts = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => RepostModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <RepostModel>[];

    final metaRaw = map['meta'];
    final meta = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : map;

    final page = _parsePaginationInt(meta['page']) ?? requestedPage;
    final lastPage = _parsePaginationInt(meta['lastPage']) ??
        (reposts.length < requestedLimit ? page : page + 1);
    final total = _parsePaginationInt(meta['total']) ?? reposts.length;

    return RepostsPageModel(
      reposts: reposts,
      page: page,
      lastPage: lastPage,
      total: total,
    );
  }
}

class UserRepostModel extends UserRepostEntity {
  const UserRepostModel({
    required super.id,
    required super.userId,
    required super.postId,
    super.quote,
    required super.createdAt,
    required super.post,
  });

  factory UserRepostModel.fromFeedItemJson(Map<String, dynamic> json) {
    if (json.containsKey('feedType') && json['post'] is Map) {
      final item = FeedItemModel.fromJson(json);
      return UserRepostModel(
        id: item.repostId ?? item.id,
        userId: item.repostedBy?.id ?? '',
        postId: item.post.id,
        quote: item.quote ?? item.repostedBy?.quote,
        createdAt: item.repostedAt ?? item.sortAt,
        post: item.post.copyWith(isReposted: true),
      );
    }
    return UserRepostModel.fromJson(json);
  }

  factory UserRepostModel.fromJson(Map<String, dynamic> json) {
    final postJson = json['post'];
    return UserRepostModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      quote: json['quote']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      post: postJson is Map<String, dynamic>
          ? PostModel.fromJson(postJson)
          : PostModel(
              id: '',
              userId: '',
              type: 'VIDEO',
              privacyStatus: 'PUBLIC',
              viewCount: 0,
              likeCount: 0,
              commentCount: 0,
              saveCount: 0,
              shareCount: 0,
              repostCount: 0,
              isLiked: false,
              isSaved: false,
              isReposted: false,
              recentReposters: const [],
              createdAt: DateTime.now(),
              media: const [],
              hashtags: const [],
              mentions: const [],
            ),
    );
  }
}

class UserRepostsPageModel extends UserRepostsPageEntity {
  const UserRepostsPageModel({
    required super.reposts,
    required super.page,
    required super.lastPage,
    required super.total,
  });

  factory UserRepostsPageModel.fromResponse(
    dynamic body, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final root = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final data = root['data'];

    late final List<UserRepostModel> reposts;
    late final Map<String, dynamic> meta;

    if (data is List) {
      // Feed alias: GET /users/me/reposts → same shape as contentType=REPOSTS.
      reposts = data
          .whereType<Map>()
          .map((e) => UserRepostModel.fromFeedItemJson(
                Map<String, dynamic>.from(e),
              ))
          .where((item) => item.post.id.isNotEmpty)
          .toList();
      final metaRaw = root['meta'];
      meta = metaRaw is Map
          ? Map<String, dynamic>.from(metaRaw)
          : root;
    } else {
      final map = data is Map ? Map<String, dynamic>.from(data) : root;
      final raw = map['reposts'] ?? map['items'] ?? root['reposts'];
      reposts = raw is List
          ? raw
              .whereType<Map>()
              .map(
                (e) => UserRepostModel.fromFeedItemJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((item) => item.post.id.isNotEmpty)
              .toList()
          : const <UserRepostModel>[];
      final metaRaw = map['meta'];
      meta = metaRaw is Map
          ? Map<String, dynamic>.from(metaRaw)
          : map;
    }

    final page = _parsePaginationInt(meta['page']) ?? requestedPage;
    final lastPage = _parsePaginationInt(meta['lastPage']) ??
        (reposts.length < requestedLimit ? page : page + 1);
    final total = _parsePaginationInt(meta['total']) ?? reposts.length;

    return UserRepostsPageModel(
      reposts: reposts,
      page: page,
      lastPage: lastPage,
      total: total,
    );
  }
}
