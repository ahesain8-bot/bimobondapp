import 'package:bimobondapp/app/posts/domain/entities/post_view_entity.dart';
import 'package:bimobondapp/app/social/data/models/social_user_model.dart';

class PostViewModel extends PostViewEntity {
  const PostViewModel({
    required super.id,
    required super.userId,
    required super.postId,
    super.watchedDuration,
    super.createdAt,
    super.user,
  });

  factory PostViewModel.fromJson(Map<String, dynamic> json) {
    final nestedUser =
        json['user'] ?? json['viewer'] ?? json['viewedBy'] ?? json['viewedUser'];

    if (nestedUser is! Map &&
        (json['username'] != null ||
            json['fullName'] != null ||
            json['avatarUrl'] != null ||
            json['avatar'] != null) &&
        json['watchedDuration'] == null &&
        json['postId'] == null) {
      final user = SocialUserModel.fromJson(json);
      return PostViewModel(
        id: '',
        userId: user.id,
        postId: '',
        user: user,
      );
    }

    SocialUserModel? user;
    if (nestedUser is Map) {
      user = SocialUserModel.fromJson(Map<String, dynamic>.from(nestedUser));
    }

    final userId = _nullableId(
      json['userId'] ??
          json['viewerId'] ??
          json['viewerUserId'] ??
          user?.id,
    );
    if (user == null && userId != null && userId.isNotEmpty) {
      user = SocialUserModel(id: userId);
    }

    final watched = json['watchedDuration'];
    final watchedDuration = watched is num
        ? watched.toInt()
        : int.tryParse(watched?.toString() ?? '');

    final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';

    return PostViewModel(
      id: id,
      userId: userId ?? '',
      postId: json['postId']?.toString() ?? '',
      watchedDuration: watchedDuration,
      createdAt: _parseDate(json['createdAt']),
      user: user,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _nullableId(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }
}
