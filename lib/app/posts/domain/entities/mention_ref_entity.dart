import 'package:equatable/equatable.dart';

/// Resolved @mention from the API (post caption or comment body).
class MentionRefEntity extends Equatable {
  const MentionRefEntity({
    required this.userId,
    this.username,
    this.fullName,
  });

  final String userId;
  final String? username;
  final String? fullName;

  String? get displayName {
    final fn = fullName?.trim();
    if (fn != null && fn.isNotEmpty) return fn;
    return username;
  }

  @override
  List<Object?> get props => [userId, username, fullName];
}
