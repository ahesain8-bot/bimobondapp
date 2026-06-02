import 'package:bimobondapp/app/social/data/models/user_like_model.dart';
import 'package:bimobondapp/app/social/domain/entities/user_likes_page_entity.dart';

class UserLikesPageModel extends UserLikesPageEntity {
  const UserLikesPageModel({
    required super.likes,
    required super.page,
    required super.lastPage,
    required super.total,
  });

  factory UserLikesPageModel.fromResponse(
    dynamic body,
    List<UserLikeModel> likes, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final map =
        body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final metaRaw = map['meta'];
    final meta =
        metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : map;

    final page = _parseInt(meta['page']) ?? requestedPage;
    final lastPage = _parseInt(meta['lastPage']) ??
        (likes.length < requestedLimit ? page : page + 1);
    final total = _parseInt(meta['total']) ?? likes.length;

    return UserLikesPageModel(
      likes: likes,
      page: page,
      lastPage: lastPage,
      total: total,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
