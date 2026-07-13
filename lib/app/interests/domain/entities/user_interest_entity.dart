import 'package:equatable/equatable.dart';

class UserInterestPreference {
  UserInterestPreference._();

  static const String interested = 'INTERESTED';
  static const String notInterested = 'NOT_INTERESTED';
}

class UserInterestSource {
  UserInterestSource._();

  static const String onboarding = 'ONBOARDING';
  static const String manual = 'MANUAL';
  static const String like = 'LIKE';
  static const String comment = 'COMMENT';
}

class UserInterestCategoryEntity extends Equatable {
  const UserInterestCategoryEntity({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl,
    this.parentId,
    this.isActive = true,
    this.order = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? iconUrl;
  final String? parentId;
  final bool isActive;
  final int order;

  @override
  List<Object?> get props =>
      [id, name, slug, iconUrl, parentId, isActive, order];
}

class UserInterestEntity extends Equatable {
  const UserInterestEntity({
    required this.categoryId,
    required this.preference,
    this.source,
    this.createdAt,
    this.updatedAt,
    this.category,
  });

  final String categoryId;
  final String preference;
  final String? source;
  final String? createdAt;
  final String? updatedAt;
  final UserInterestCategoryEntity? category;

  bool get isInterested => preference == UserInterestPreference.interested;

  @override
  List<Object?> get props =>
      [categoryId, preference, source, createdAt, updatedAt, category];
}

class UserInterestsMeta extends Equatable {
  const UserInterestsMeta({
    this.totalInterests = 0,
    this.totalNotInterests = 0,
    this.minRequired = 3,
    this.maxAllowed = 20,
    this.maxNotInterestsAllowed = 20,
    this.needsInterests = false,
  });

  final int totalInterests;
  final int totalNotInterests;
  final int minRequired;
  final int maxAllowed;
  final int maxNotInterestsAllowed;
  final bool needsInterests;

  @override
  List<Object?> get props => [
        totalInterests,
        totalNotInterests,
        minRequired,
        maxAllowed,
        maxNotInterestsAllowed,
        needsInterests,
      ];
}

class UserInterestsResult extends Equatable {
  const UserInterestsResult({
    required this.interests,
    required this.notInterests,
    required this.meta,
  });

  final List<UserInterestEntity> interests;
  final List<UserInterestEntity> notInterests;
  final UserInterestsMeta meta;

  @override
  List<Object?> get props => [interests, notInterests, meta];
}
