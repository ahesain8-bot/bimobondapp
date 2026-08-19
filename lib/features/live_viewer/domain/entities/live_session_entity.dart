import 'package:equatable/equatable.dart';
import 'live_entity.dart';

/// Connection lifecycle for a live watch session.
enum LiveConnectionState {
  idle,
  loading,
  connecting,
  connected,
  reconnecting,
  networkLost,
  liveEnded,
  banned,
  error,
  empty,
}

extension LiveConnectionStateX on LiveConnectionState {
  bool get isTerminal =>
      this == LiveConnectionState.liveEnded ||
      this == LiveConnectionState.banned ||
      this == LiveConnectionState.error;

  bool get isActive =>
      this == LiveConnectionState.connected ||
      this == LiveConnectionState.reconnecting;

  String get displayMessage {
    switch (this) {
      case LiveConnectionState.idle:
        return '';
      case LiveConnectionState.loading:
        return 'Loading live…';
      case LiveConnectionState.connecting:
        return 'Connecting…';
      case LiveConnectionState.connected:
        return 'Live';
      case LiveConnectionState.reconnecting:
        return 'Reconnecting…';
      case LiveConnectionState.networkLost:
        return 'Network lost';
      case LiveConnectionState.liveEnded:
        return 'Live ended';
      case LiveConnectionState.banned:
        return 'You are banned from this live';
      case LiveConnectionState.error:
        return 'Something went wrong';
      case LiveConnectionState.empty:
        return 'Live not found';
    }
  }
}

/// Result of joining a live room (REST + LiveKit + socket tokens).
class JoinLiveResult extends Equatable {
  final String liveId;
  final String socketToken;
  final String liveKitToken;
  final String liveKitUrl;
  final LiveEntity live;

  const JoinLiveResult({
    required this.liveId,
    required this.socketToken,
    required this.liveKitToken,
    required this.liveKitUrl,
    required this.live,
  });

  @override
  List<Object?> get props => [
    liveId,
    socketToken,
    liveKitToken,
    liveKitUrl,
    live,
  ];
}

/// Active watch session snapshot.
class LiveSessionEntity extends Equatable {
  final LiveEntity live;
  final LiveConnectionState connectionState;
  final String? socketToken;
  final String? liveKitToken;
  final bool isSocketConnected;
  final bool isLiveKitConnected;
  final int reconnectAttempt;
  final String? errorMessage;
  final int coinBalance;
  final bool hasLiked;

  const LiveSessionEntity({
    required this.live,
    this.connectionState = LiveConnectionState.idle,
    this.socketToken,
    this.liveKitToken,
    this.isSocketConnected = false,
    this.isLiveKitConnected = false,
    this.reconnectAttempt = 0,
    this.errorMessage,
    this.coinBalance = 1250,
    this.hasLiked = false,
  });

  LiveSessionEntity copyWith({
    LiveEntity? live,
    LiveConnectionState? connectionState,
    String? socketToken,
    String? liveKitToken,
    bool? isSocketConnected,
    bool? isLiveKitConnected,
    int? reconnectAttempt,
    String? errorMessage,
    int? coinBalance,
    bool? hasLiked,
  }) {
    return LiveSessionEntity(
      live: live ?? this.live,
      connectionState: connectionState ?? this.connectionState,
      socketToken: socketToken ?? this.socketToken,
      liveKitToken: liveKitToken ?? this.liveKitToken,
      isSocketConnected: isSocketConnected ?? this.isSocketConnected,
      isLiveKitConnected: isLiveKitConnected ?? this.isLiveKitConnected,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      errorMessage: errorMessage,
      coinBalance: coinBalance ?? this.coinBalance,
      hasLiked: hasLiked ?? this.hasLiked,
    );
  }

  @override
  List<Object?> get props => [
    live,
    connectionState,
    socketToken,
    liveKitToken,
    isSocketConnected,
    isLiveKitConnected,
    reconnectAttempt,
    errorMessage,
    coinBalance,
    hasLiked,
  ];
}
