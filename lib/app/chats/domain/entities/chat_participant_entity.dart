import 'package:equatable/equatable.dart';

class ChatParticipantEntity extends Equatable {
  const ChatParticipantEntity({
    required this.id,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.isActive,
  });

  final String id;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final bool? isActive;

  String get displayName =>
      (fullName?.trim().isNotEmpty == true ? fullName : username) ?? 'User';

  @override
  List<Object?> get props => [id, username, fullName, avatarUrl, isActive];
}
