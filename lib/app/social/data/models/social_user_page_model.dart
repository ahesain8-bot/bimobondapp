import 'package:bimobondapp/app/social/data/models/social_user_model.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_page_entity.dart';

class SocialUserPageModel extends SocialUserPageEntity {
  const SocialUserPageModel({
    required super.users,
    required super.page,
    required super.lastPage,
    required super.total,
  });

  factory SocialUserPageModel.fromResponse(
    dynamic body,
    List<SocialUserModel> users, {
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
        (users.length < requestedLimit ? page : page + 1);
    final total = _parseInt(meta['total']) ?? users.length;

    return SocialUserPageModel(
      users: users,
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
