import 'package:bimobondapp/app/social/data/models/user_mention_model.dart';
import 'package:bimobondapp/app/social/domain/entities/user_mentions_page_entity.dart';

class UserMentionsPageModel extends UserMentionsPageEntity {
  const UserMentionsPageModel({
    required super.mentions,
    required super.page,
    required super.lastPage,
    required super.total,
  });

  factory UserMentionsPageModel.fromResponse(
    dynamic body,
    List<UserMentionModel> mentions, {
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
        (mentions.length < requestedLimit ? page : page + 1);
    final total = _parseInt(meta['total']) ?? mentions.length;

    return UserMentionsPageModel(
      mentions: mentions,
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
