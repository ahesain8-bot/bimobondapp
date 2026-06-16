import 'package:bimobondapp/app/chats/domain/entities/chat_participant_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

class ChatParticipantModel extends ChatParticipantEntity {
  const ChatParticipantModel({
    required super.id,
    super.username,
    super.fullName,
    super.avatarUrl,
    super.isActive,
  });

  factory ChatParticipantModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : null;
    final source = userMap ?? json;

    final avatar = source['avatarUrl'] ??
        source['avatar'] ??
        source['image'] ??
        source['profileImage'] ??
        json['avatarUrl'] ??
        json['avatar'] ??
        json['image'] ??
        json['profileImage'];

    return ChatParticipantModel(
      id: (source['id'] ?? source['userId'] ?? json['id'] ?? json['userId'] ?? '').toString(),
      username: source['username']?.toString() ?? json['username']?.toString(),
      fullName: source['fullName']?.toString() ??
          source['displayName']?.toString() ??
          source['name']?.toString() ??
          json['fullName']?.toString() ??
          json['displayName']?.toString() ??
          json['name']?.toString(),
      avatarUrl: avatar != null
          ? MediaUtils.resolveAbsoluteUrl(avatar.toString())
          : null,
      isActive: (source['isActive'] ?? source['active'] ?? json['isActive'] ?? json['active']) as bool?,
    );
  }
}
