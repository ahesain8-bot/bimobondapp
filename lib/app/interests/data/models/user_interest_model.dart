import 'package:bimobondapp/app/interests/domain/entities/user_interest_entity.dart';

class UserInterestCategoryModel extends UserInterestCategoryEntity {
  const UserInterestCategoryModel({
    required super.id,
    required super.name,
    required super.slug,
    super.iconUrl,
    super.parentId,
    super.isActive,
    super.order,
  });

  factory UserInterestCategoryModel.fromJson(Map<String, dynamic> json) {
    return UserInterestCategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      iconUrl: json['iconUrl']?.toString(),
      parentId: json['parentId']?.toString(),
      isActive: json['isActive'] != false,
      order: _asInt(json['order']) ?? 0,
    );
  }
}

class UserInterestModel extends UserInterestEntity {
  const UserInterestModel({
    required super.categoryId,
    required super.preference,
    super.source,
    super.createdAt,
    super.updatedAt,
    super.category,
  });

  factory UserInterestModel.fromJson(Map<String, dynamic> json) {
    final categoryRaw = json['category'];
    return UserInterestModel(
      categoryId: json['categoryId']?.toString() ??
          (categoryRaw is Map ? categoryRaw['id']?.toString() : null) ??
          '',
      preference: json['preference']?.toString() ??
          UserInterestPreference.interested,
      source: json['source']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      category: categoryRaw is Map
          ? UserInterestCategoryModel.fromJson(
              Map<String, dynamic>.from(categoryRaw),
            )
          : null,
    );
  }
}

class UserInterestsResultModel extends UserInterestsResult {
  const UserInterestsResultModel({
    required super.interests,
    required super.notInterests,
    required super.meta,
  });

  factory UserInterestsResultModel.fromJson(Map<String, dynamic> json) {
    final interests = _parseList(json['interests']);
    final notInterests = _parseList(json['notInterests']);
    final metaRaw = json['meta'];
    final metaMap = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : <String, dynamic>{};

    return UserInterestsResultModel(
      interests: interests,
      notInterests: notInterests,
      meta: UserInterestsMeta(
        totalInterests:
            _asInt(metaMap['totalInterests']) ?? interests.length,
        totalNotInterests:
            _asInt(metaMap['totalNotInterests']) ?? notInterests.length,
        minRequired: _asInt(metaMap['minRequired']) ?? 3,
        maxAllowed: _asInt(metaMap['maxAllowed']) ?? 20,
        maxNotInterestsAllowed:
            _asInt(metaMap['maxNotInterestsAllowed']) ?? 20,
        needsInterests: metaMap['needsInterests'] == true,
      ),
    );
  }

  static List<UserInterestModel> _parseList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => UserInterestModel.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.categoryId.isNotEmpty)
        .toList();
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
