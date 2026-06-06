import 'package:bimobondapp/app/auth/domain/entities/user_activity_entity.dart';

class UserActivityModel extends UserActivityEntity {
  const UserActivityModel({
    required super.id,
    required super.type,
    required super.createdAt,
    required super.details,
  });

  factory UserActivityModel.fromJson(Map<String, dynamic> json) {
    final detailsRaw = json['details'];
    final details = detailsRaw is Map
        ? Map<String, dynamic>.from(detailsRaw)
        : <String, dynamic>{};

    return UserActivityModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'UNKNOWN',
      createdAt: json['createdAt']?.toString() ?? '',
      details: details,
    );
  }
}
