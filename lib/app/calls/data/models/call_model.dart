import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';

class CallUserModel extends CallUserEntity {
  const CallUserModel({
    required super.id,
    required super.username,
    super.fullName,
    super.avatarUrl,
  });

  factory CallUserModel.fromJson(Map<String, dynamic> json) {
    return CallUserModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (fullName != null) 'fullName': fullName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }
}

class CallParticipantModel extends CallParticipantEntity {
  const CallParticipantModel({
    required super.id,
    required super.userId,
    required super.role,
    required super.status,
    super.joinedAt,
    super.leftAt,
    super.user,
  });

  factory CallParticipantModel.fromJson(Map<String, dynamic> json) {
    return CallParticipantModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      role: json['role']?.toString() ?? 'CALLEE',
      status: json['status']?.toString() ?? 'RINGING',
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString())
          : null,
      leftAt: json['leftAt'] != null
          ? DateTime.tryParse(json['leftAt'].toString())
          : null,
      user: json['user'] is Map
          ? CallUserModel.fromJson(Map<String, dynamic>.from(json['user']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'role': role,
      'status': status,
      if (joinedAt != null) 'joinedAt': joinedAt!.toIso8601String(),
      if (leftAt != null) 'leftAt': leftAt!.toIso8601String(),
      if (user != null && user is CallUserModel)
        'user': (user as CallUserModel).toJson(),
    };
  }
}

class CallChatModel extends CallChatEntity {
  const CallChatModel({
    required super.id,
    required super.isGroup,
    super.name,
  });

  factory CallChatModel.fromJson(Map<String, dynamic> json) {
    return CallChatModel(
      id: json['id']?.toString() ?? '',
      isGroup: json['isGroup'] as bool? ?? false,
      name: json['name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isGroup': isGroup,
      if (name != null) 'name': name,
    };
  }
}

class CallModel extends CallEntity {
  const CallModel({
    required super.id,
    required super.chatId,
    required super.type,
    required super.status,
    required super.roomName,
    super.maxParticipants = 8,
    super.startedAt,
    super.endedAt,
    required super.createdAt,
    required super.initiatedBy,
    required super.participants,
    super.chat,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'];
    final participantsList = <CallParticipantModel>[];
    if (rawParticipants is List) {
      for (final p in rawParticipants) {
        if (p is Map) {
          participantsList.add(
            CallParticipantModel.fromJson(Map<String, dynamic>.from(p)),
          );
        }
      }
    }

    final rawInitiatedBy = json['initiatedBy'];
    final initiatedByModel = rawInitiatedBy is Map
        ? CallUserModel.fromJson(Map<String, dynamic>.from(rawInitiatedBy))
        : const CallUserModel(id: '', username: 'User');

    final rawChat = json['chat'];
    final chatModel = rawChat is Map
        ? CallChatModel.fromJson(Map<String, dynamic>.from(rawChat))
        : null;

    return CallModel(
      id: json['id']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'VIDEO',
      status: json['status']?.toString() ?? 'RINGING',
      roomName: json['roomName']?.toString() ?? '',
      maxParticipants: json['maxParticipants'] is int
          ? json['maxParticipants'] as int
          : 8,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      initiatedBy: initiatedByModel,
      participants: participantsList,
      chat: chatModel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'type': type,
      'status': status,
      'roomName': roomName,
      'maxParticipants': maxParticipants,
      if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'initiatedBy': (initiatedBy as CallUserModel).toJson(),
      'participants': participants
          .map((p) => (p as CallParticipantModel).toJson())
          .toList(),
      if (chat != null) 'chat': (chat as CallChatModel).toJson(),
    };
  }
}

class CallSessionModel extends CallSessionEntity {
  const CallSessionModel({
    required super.call,
    required super.livekitUrl,
    required super.token,
    required super.roomName,
  });

  factory CallSessionModel.fromJson(Map<String, dynamic> json) {
    final rawCall = json['call'];
    final callEntity = rawCall is Map
        ? CallModel.fromJson(Map<String, dynamic>.from(rawCall))
        : CallModel.fromJson(json);

    return CallSessionModel(
      call: callEntity,
      livekitUrl: json['livekitUrl']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      roomName: json['roomName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'call': (call as CallModel).toJson(),
      'livekitUrl': livekitUrl,
      'token': token,
      'roomName': roomName,
    };
  }
}
