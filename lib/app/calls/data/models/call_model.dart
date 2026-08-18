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
      if (user != null)
        'user': {
          'id': user!.id,
          'username': user!.username,
          if (user!.fullName != null) 'fullName': user!.fullName,
          if (user!.avatarUrl != null) 'avatarUrl': user!.avatarUrl,
        },
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
        if (p is CallParticipantModel) {
          participantsList.add(p);
        } else if (p is CallParticipantEntity) {
          participantsList.add(
            CallParticipantModel(
              id: p.id,
              userId: p.userId,
              role: p.role,
              status: p.status,
              joinedAt: p.joinedAt,
              leftAt: p.leftAt,
              user: p.user,
            ),
          );
        } else if (p is Map) {
          participantsList.add(
            CallParticipantModel.fromJson(Map<String, dynamic>.from(p)),
          );
        }
      }
    }

    CallUserModel? extraCalleeUser;
    for (final key in ['callee', 'recipient', 'targetUser', 'otherUser', 'invitee', 'user', 'receiver', 'toUser']) {
      final val = json[key];
      if (val is Map) {
        extraCalleeUser = CallUserModel.fromJson(Map<String, dynamic>.from(val));
        break;
      }
    }

    if (extraCalleeUser != null && extraCalleeUser.id.isNotEmpty) {
      final calleeId = extraCalleeUser.id;
      final existingIdx = participantsList.indexWhere(
        (p) => p.userId == calleeId || p.role.toUpperCase() == 'CALLEE',
      );
      if (existingIdx >= 0) {
        final existing = participantsList[existingIdx];
        if (existing.user == null) {
          participantsList[existingIdx] = CallParticipantModel(
            id: existing.id,
            userId: existing.userId,
            role: existing.role,
            status: existing.status,
            joinedAt: existing.joinedAt,
            leftAt: existing.leftAt,
            user: extraCalleeUser,
          );
        }
      } else {
        participantsList.add(
          CallParticipantModel(
            id: 'callee_$calleeId',
            userId: calleeId,
            role: 'CALLEE',
            status: 'RINGING',
            user: extraCalleeUser,
          ),
        );
      }
    }

    final nameCandidates = [
      json['callerName'],
      json['caller_name'],
      json['fullName'],
      json['full_name'],
      json['actorName'],
      json['actor_name'],
      json['senderName'],
      json['sender_name'],
      json['displayName'],
      json['display_name'],
      json['userName'],
      json['user_name'],
      json['username'],
      json['name'],
      json['title'],
    ];

    String? callerName;
    for (final candidate in nameCandidates) {
      if (candidate != null && candidate is String && candidate.trim().isNotEmpty && candidate.trim() != 'null') {
        final lower = candidate.trim().toLowerCase();
        if (lower != 'incoming call' &&
            lower != 'incoming voice call' &&
            lower != 'incoming video call' &&
            lower != 'bimo bond' &&
            lower != 'مكالمة واردة' &&
            lower != 'مكالمة') {
          callerName = candidate.trim();
          break;
        }
      }
    }
    callerName ??= json['callerName']?.toString() ?? json['username']?.toString() ?? json['title']?.toString() ?? 'User';

    final avatarCandidates = [
      json['callerAvatar'],
      json['caller_avatar'],
      json['avatarUrl'],
      json['avatar_url'],
      json['avatar'],
      json['userAvatar'],
      json['user_avatar'],
      json['imageUrl'],
      json['image_url'],
      json['image'],
      json['icon'],
      json['picture'],
      json['profile_pic'],
    ];

    String? callerAvatar;
    for (final candidate in avatarCandidates) {
      if (candidate != null && candidate is String && candidate.trim().isNotEmpty && candidate.trim() != 'null') {
        callerAvatar = candidate.trim();
        break;
      }
    }

    final callerId = json['callerId']?.toString() ??
        json['initiatorId']?.toString() ??
        json['userId']?.toString() ??
        '';

    final rawInitiatedBy = json['initiatedBy'];
    CallUserModel initiatedByModel;
    if (rawInitiatedBy is CallUserModel) {
      initiatedByModel = rawInitiatedBy;
    } else if (rawInitiatedBy is CallUserEntity) {
      initiatedByModel = CallUserModel(
        id: rawInitiatedBy.id,
        username: rawInitiatedBy.username,
        fullName: rawInitiatedBy.fullName,
        avatarUrl: rawInitiatedBy.avatarUrl,
      );
    } else if (rawInitiatedBy is Map) {
      initiatedByModel =
          CallUserModel.fromJson(Map<String, dynamic>.from(rawInitiatedBy));
    } else {
      initiatedByModel = CallUserModel(
        id: callerId,
        username: callerName,
        fullName: callerName,
        avatarUrl: callerAvatar,
      );
    }

    final rawChat = json['chat'];
    CallChatModel? chatModel;
    if (rawChat is CallChatModel) {
      chatModel = rawChat;
    } else if (rawChat is CallChatEntity) {
      chatModel = CallChatModel(
        id: rawChat.id,
        isGroup: rawChat.isGroup,
        name: rawChat.name,
      );
    } else if (rawChat is Map) {
      chatModel = CallChatModel.fromJson(Map<String, dynamic>.from(rawChat));
    }

    return CallModel(
      id: json['id']?.toString() ?? json['callId']?.toString() ?? '',
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
      'initiatedBy': {
        'id': initiatedBy.id,
        'username': initiatedBy.username,
        if (initiatedBy.fullName != null) 'fullName': initiatedBy.fullName,
        if (initiatedBy.avatarUrl != null) 'avatarUrl': initiatedBy.avatarUrl,
      },
      'participants': participants.map((p) {
        if (p is CallParticipantModel) return p.toJson();
        return {
          'id': p.id,
          'userId': p.userId,
          'role': p.role,
          'status': p.status,
          if (p.joinedAt != null) 'joinedAt': p.joinedAt!.toIso8601String(),
          if (p.leftAt != null) 'leftAt': p.leftAt!.toIso8601String(),
          if (p.user != null)
            'user': {
              'id': p.user!.id,
              'username': p.user!.username,
              if (p.user!.fullName != null) 'fullName': p.user!.fullName,
              if (p.user!.avatarUrl != null) 'avatarUrl': p.user!.avatarUrl,
            },
        };
      }).toList(),
      if (chat != null)
        'chat': {
          'id': chat!.id,
          'isGroup': chat!.isGroup,
          if (chat!.name != null) 'name': chat!.name,
        },
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
    final Map<String, dynamic> callData = rawCall is Map
        ? Map<String, dynamic>.from(rawCall)
        : Map<String, dynamic>.from(json);

    for (final key in ['callee', 'recipient', 'targetUser', 'otherUser', 'invitee', 'user', 'receiver', 'toUser']) {
      if (json[key] != null && callData[key] == null) {
        callData[key] = json[key];
      }
    }

    final callEntity = CallModel.fromJson(callData);

    return CallSessionModel(
      call: callEntity,
      livekitUrl: json['livekitUrl']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      roomName: json['roomName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> callMap;
    if (call is CallModel) {
      callMap = (call as CallModel).toJson();
    } else {
      callMap = {
        'id': call.id,
        'chatId': call.chatId,
        'type': call.type,
        'status': call.status,
        'roomName': call.roomName,
        'maxParticipants': call.maxParticipants,
        if (call.startedAt != null) 'startedAt': call.startedAt!.toIso8601String(),
        if (call.endedAt != null) 'endedAt': call.endedAt!.toIso8601String(),
        'createdAt': call.createdAt.toIso8601String(),
      };
    }
    return {
      'call': callMap,
      'livekitUrl': livekitUrl,
      'token': token,
      'roomName': roomName,
    };
  }
}
