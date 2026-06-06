import 'package:equatable/equatable.dart';

/// Resolved @mention from the API (post caption or comment body).
class MentionRefEntity extends Equatable {
  const MentionRefEntity({
    required this.userId,
    this.username,
  });

  final String userId;
  final String? username;

  @override
  List<Object?> get props => [userId, username];
}
