import 'package:bimobondapp/app/auth/data/models/user_activity_model.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_activity_page_entity.dart';

class UserActivityPageModel extends UserActivityPageEntity {
  const UserActivityPageModel({
    required super.activities,
    required super.page,
    required super.lastPage,
    required super.total,
  });

  factory UserActivityPageModel.fromResponse(
    dynamic body, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

    final activitiesRaw = map['activities'];
    final activities = <UserActivityModel>[];
    if (activitiesRaw is List) {
      for (final item in activitiesRaw) {
        if (item is Map) {
          activities.add(
            UserActivityModel.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final metaRaw = map['meta'];
    final meta = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : map;

    final page = _parseInt(meta['page']) ?? requestedPage;
    final lastPage = _parseInt(meta['lastPage']) ??
        (activities.length < requestedLimit ? page : page + 1);
    final total = _parseInt(meta['total']) ?? activities.length;

    return UserActivityPageModel(
      activities: activities,
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
