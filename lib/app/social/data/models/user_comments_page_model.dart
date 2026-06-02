import 'package:bimobondapp/app/social/data/models/user_comment_model.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comments_page_entity.dart';

class UserCommentsPageModel extends UserCommentsPageEntity {
  const UserCommentsPageModel({
    required super.comments,
    required super.page,
    required super.lastPage,
    required super.total,
  });

  factory UserCommentsPageModel.fromResponse(
    dynamic body,
    List<UserCommentModel> comments, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final metaRaw = map['meta'];
    final meta = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : map;

    final page = _parseInt(meta['page']) ?? requestedPage;
    final lastPage = _parseInt(meta['lastPage']) ??
        (comments.length < requestedLimit ? page : page + 1);
    final total = _parseInt(meta['total']) ?? comments.length;

    return UserCommentsPageModel(
      comments: comments,
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
