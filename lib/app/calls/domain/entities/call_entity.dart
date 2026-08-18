import 'package:equatable/equatable.dart';

class CallUserEntity extends Equatable {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;

  const CallUserEntity({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [id, username, fullName, avatarUrl];
}

class CallParticipantEntity extends Equatable {
  final String id;
  final String userId;
  final String role; // CALLER, CALLEE
  final String status; // INVITED, RINGING, JOINED, LEFT, DECLINED, MISSED
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final CallUserEntity? user;

  const CallParticipantEntity({
    required this.id,
    required this.userId,
    required this.role,
    required this.status,
    this.joinedAt,
    this.leftAt,
    this.user,
  });

  CallParticipantEntity copyWith({
    String? id,
    String? userId,
    String? role,
    String? status,
    DateTime? joinedAt,
    DateTime? leftAt,
    CallUserEntity? user,
  }) {
    return CallParticipantEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      user: user ?? this.user,
    );
  }

  @override
  List<Object?> get props => [id, userId, role, status, joinedAt, leftAt, user];
}

class CallChatEntity extends Equatable {
  final String id;
  final bool isGroup;
  final String? name;

  const CallChatEntity({
    required this.id,
    required this.isGroup,
    this.name,
  });

  @override
  List<Object?> get props => [id, isGroup, name];
}

class CallEntity extends Equatable {
  final String id;
  final String chatId;
  final String type; // AUDIO, VIDEO
  final String status; // RINGING, ACTIVE, ENDED, MISSED, REJECTED, CANCELLED
  final String roomName;
  final int maxParticipants;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final CallUserEntity initiatedBy;
  final List<CallParticipantEntity> participants;
  final CallChatEntity? chat;

  const CallEntity({
    required this.id,
    required this.chatId,
    required this.type,
    required this.status,
    required this.roomName,
    this.maxParticipants = 8,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    required this.initiatedBy,
    required this.participants,
    this.chat,
  });

  bool get isAudio => type.toUpperCase() == 'AUDIO';
  bool get isVideo => type.toUpperCase() == 'VIDEO';
  bool get isRinging => status.toUpperCase() == 'RINGING';
  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isEnded =>
      status.toUpperCase() == 'ENDED' ||
      status.toUpperCase() == 'MISSED' ||
      status.toUpperCase() == 'REJECTED' ||
      status.toUpperCase() == 'CANCELLED';

  CallUserEntity getDisplayUser(String currentUserId, {bool isOutgoing = false}) {
    if (isOutgoing || (currentUserId.isNotEmpty && initiatedBy.id == currentUserId)) {
      for (final p in participants) {
        if (p.role.toUpperCase() == 'CALLEE' && p.user != null) {
          return p.user!;
        }
      }
      for (final p in participants) {
        if (p.userId != currentUserId && p.userId != initiatedBy.id && p.user != null) {
          return p.user!;
        }
      }
      for (final p in participants) {
        if (p.userId != currentUserId && p.user != null) {
          return p.user!;
        }
      }
      for (final p in participants) {
        if (p.role.toUpperCase() == 'CALLEE' && p.userId.isNotEmpty) {
          return CallUserEntity(id: p.userId, username: 'User');
        }
      }
      for (final p in participants) {
        if (p.userId != currentUserId && p.userId.isNotEmpty) {
          return CallUserEntity(id: p.userId, username: 'User');
        }
      }
    }

    if (initiatedBy.id.isNotEmpty && initiatedBy.id != currentUserId) {
      return initiatedBy;
    }

    for (final p in participants) {
      if (p.userId != currentUserId && p.user != null) {
        return p.user!;
      }
    }

    return initiatedBy;
  }

  Map<String, dynamic> toCallkitData() {
    final callerName = (initiatedBy.fullName != null && initiatedBy.fullName!.isNotEmpty)
        ? initiatedBy.fullName!
        : initiatedBy.username;
    return {
      'callId': id,
      'chatId': chatId,
      'type': type,
      'isVideo': isVideo,
      'callerName': callerName,
      'callerAvatar': initiatedBy.avatarUrl,
    };
  }

  CallEntity copyWith({
    String? id,
    String? chatId,
    String? type,
    String? status,
    String? roomName,
    int? maxParticipants,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
    CallUserEntity? initiatedBy,
    List<CallParticipantEntity>? participants,
    CallChatEntity? chat,
  }) {
    return CallEntity(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      type: type ?? this.type,
      status: status ?? this.status,
      roomName: roomName ?? this.roomName,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt ?? this.createdAt,
      initiatedBy: initiatedBy ?? this.initiatedBy,
      participants: participants ?? this.participants,
      chat: chat ?? this.chat,
    );
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        type,
        status,
        roomName,
        maxParticipants,
        startedAt,
        endedAt,
        createdAt,
        initiatedBy,
        participants,
        chat,
      ];
}

class CallSessionEntity extends Equatable {
  final CallEntity call;
  final String livekitUrl;
  final String token;
  final String roomName;

  const CallSessionEntity({
    required this.call,
    required this.livekitUrl,
    required this.token,
    required this.roomName,
  });

  @override
  List<Object?> get props => [call, livekitUrl, token, roomName];
}
