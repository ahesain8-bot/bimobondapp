import 'package:equatable/equatable.dart';

class UserActivityEntity extends Equatable {
  const UserActivityEntity({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.details,
  });

  final String id;
  final String type;
  final String createdAt;
  final Map<String, dynamic> details;

  @override
  List<Object?> get props => [id, type, createdAt, details];
}
