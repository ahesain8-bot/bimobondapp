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
    final avatar = json['avatarUrl'] ??
        json['avatar'] ??
        json['image'] ??
        json['profileImage'];
    return ChatParticipantModel(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      username: json['username']?.toString(),
      fullName: json['fullName']?.toString() ?? json['name']?.toString(),
      avatarUrl: avatar != null
          ? MediaUtils.resolveAbsoluteUrl(avatar.toString())
          : null,
      isActive: json['isActive'] as bool? ?? json['active'] as bool?,
    );
  }
}
