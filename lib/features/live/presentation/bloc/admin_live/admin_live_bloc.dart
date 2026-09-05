import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_interactive.dart';
import '../../../domain/usecases/live_interactive_usecases.dart';
import '../../../../live_viewer/data/services/fake_socket_service.dart';
import '../../../../live_viewer/domain/entities/socket_event.dart';

sealed class AdminLiveEvent {
  const AdminLiveEvent();
}

class AdminLivesRequested extends AdminLiveEvent {
  const AdminLivesRequested({this.page = 1, this.status, this.userId, this.search});

  final int page;
  final String? status;
  final String? userId;
  final String? search;
}

class AdminLiveDetailRequested extends AdminLiveEvent {
  const AdminLiveDetailRequested(this.liveId);

  final String liveId;
}

class AdminLiveEnded extends AdminLiveEvent {
  const AdminLiveEnded(this.liveId);

  final String liveId;
}

class AdminLiveBanned extends AdminLiveEvent {
  const AdminLiveBanned({required this.liveId, required this.reason});

  final String liveId;
  final String reason;
}

class AdminGuestKicked extends AdminLiveEvent {
  const AdminGuestKicked({required this.liveId, required this.userId});

  final String liveId;
  final String userId;
}

class AdminLiveBoosted extends AdminLiveEvent {
  const AdminLiveBoosted({required this.liveId, this.durationMinutes = 60});

  final String liveId;
  final int durationMinutes;
}

class AdminLiveErrorCleared extends AdminLiveEvent {
  const AdminLiveErrorCleared();
}

class AdminLiveSocketEventReceived extends AdminLiveEvent {
  const AdminLiveSocketEventReceived(this.event);

  final SocketEvent event;
}

class AdminLiveState {
  const AdminLiveState({
    this.isLoading = false,
    this.isActionBusy = false,
    this.permissionsLoading = false,
    this.permissionsLoaded = false,
    this.canRead = false,
    this.canModerate = false,
    this.page,
    this.selected,
    this.guests = const [],
    this.comments = const [],
    this.battle,
    this.poll,
    this.questions = const [],
    this.treasureBoxes = const [],
    this.hourlyRank,
    this.gifters = const [],
    this.auctions = const [],
    this.realtimeEvent,
    this.error,
  });

  final bool isLoading;
  final bool isActionBusy;
  final bool permissionsLoading;
  final bool permissionsLoaded;
  final bool canRead;
  final bool canModerate;
  final AdminLivePage? page;
  final AdminLive? selected;
  final List<Map<String, dynamic>> guests;
  final List<Map<String, dynamic>> comments;
  final Map<String, dynamic>? battle;
  final LivePoll? poll;
  final List<LiveQA> questions;
  final List<LiveTreasureBox> treasureBoxes;
  final LiveHourlyLeaderboardEntry? hourlyRank;
  final List<LiveGifterLeaderboardEntry> gifters;
  final List<LiveAuction> auctions;
  final String? realtimeEvent;
  final String? error;

  AdminLiveState copyWith({
    bool? isLoading,
    bool? isActionBusy,
    bool? permissionsLoading,
    bool? permissionsLoaded,
    bool? canRead,
    bool? canModerate,
    AdminLivePage? page,
    AdminLive? selected,
    List<Map<String, dynamic>>? guests,
    List<Map<String, dynamic>>? comments,
    Map<String, dynamic>? battle,
    bool clearBattle = false,
    LivePoll? poll,
    bool clearPoll = false,
    List<LiveQA>? questions,
    List<LiveTreasureBox>? treasureBoxes,
    LiveHourlyLeaderboardEntry? hourlyRank,
    bool clearHourlyRank = false,
    List<LiveGifterLeaderboardEntry>? gifters,
    List<LiveAuction>? auctions,
    String? realtimeEvent,
    String? error,
    bool clearError = false,
  }) {
    return AdminLiveState(
      isLoading: isLoading ?? this.isLoading,
      isActionBusy: isActionBusy ?? this.isActionBusy,
      permissionsLoading: permissionsLoading ?? this.permissionsLoading,
      permissionsLoaded: permissionsLoaded ?? this.permissionsLoaded,
      canRead: canRead ?? this.canRead,
      canModerate: canModerate ?? this.canModerate,
      page: page ?? this.page,
      selected: selected ?? this.selected,
      guests: guests ?? this.guests,
      comments: comments ?? this.comments,
      battle: clearBattle ? null : (battle ?? this.battle),
      poll: clearPoll ? null : (poll ?? this.poll),
      questions: questions ?? this.questions,
      treasureBoxes: treasureBoxes ?? this.treasureBoxes,
      hourlyRank: clearHourlyRank ? null : (hourlyRank ?? this.hourlyRank),
      gifters: gifters ?? this.gifters,
      auctions: auctions ?? this.auctions,
      realtimeEvent: realtimeEvent ?? this.realtimeEvent,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AdminLiveBloc extends Bloc<AdminLiveEvent, AdminLiveState> {
  AdminLiveBloc({
    required LiveInteractiveUseCases useCases,
    SocketService? socket,
    this.staffUserId,
  }) : _useCases = useCases,
       _socket = socket,
       super(const AdminLiveState()) {
    on<AdminLivesRequested>(_onLivesRequested);
    on<AdminLiveDetailRequested>(_onDetailRequested);
    on<AdminLiveEnded>(_onEnd);
    on<AdminLiveBanned>(_onBan);
    on<AdminGuestKicked>(_onKick);
    on<AdminLiveBoosted>(_onBoost);
    on<AdminLiveErrorCleared>(_onErrorCleared);
    on<AdminLiveSocketEventReceived>(_onSocketEvent);
    _socketSub = socket?.events.listen((event) => add(AdminLiveSocketEventReceived(event)));
  }

  final LiveInteractiveUseCases _useCases;
  final SocketService? _socket;
  final String? staffUserId;
  StreamSubscription<SocketEvent>? _socketSub;
  String? _inspectedLiveId;

  Future<void> _onLivesRequested(
    AdminLivesRequested event,
    Emitter<AdminLiveState> emit,
  ) async {
    if (!state.permissionsLoaded) {
      emit(state.copyWith(permissionsLoading: true, clearError: true));
      try {
        final permissions = await _useCases.getAdminPermissions();
        if (isClosed) return;
        emit(
          state.copyWith(
            permissionsLoading: false,
            permissionsLoaded: true,
            canRead: permissions.contains('lives.admin.read'),
            canModerate: permissions.contains('lives.admin.moderate'),
          ),
        );
      } catch (error) {
        if (!isClosed) {
          emit(
            state.copyWith(
              permissionsLoading: false,
              error: error.toString(),
            ),
          );
        }
        return;
      }
    }
    if (!state.canRead) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'You do not have permission to view live administration.',
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final page = await _useCases.getAdminLives(
        page: event.page,
        status: event.status,
        userId: event.userId,
        search: event.search,
      );
      if (!isClosed) emit(state.copyWith(isLoading: false, page: page));
    } catch (error) {
      if (!isClosed) emit(state.copyWith(isLoading: false, error: error.toString()));
    }
  }

  Future<void> _onDetailRequested(
    AdminLiveDetailRequested event,
    Emitter<AdminLiveState> emit,
  ) async {
    if (!state.canRead) {
      emit(state.copyWith(error: 'You do not have permission to inspect lives.'));
      return;
    }
    _inspectedLiveId = event.liveId;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final inspection = await _useCases.inspectLive(event.liveId);
      final socket = _socket;
      final activeStaffUserId = staffUserId;
      if (socket != null &&
          activeStaffUserId != null &&
          activeStaffUserId.isNotEmpty) {
        await socket.connect(
          liveId: event.liveId,
          token: '',
          userId: activeStaffUserId,
          includeUserIdInLiveJoin: true,
        );
      }
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            selected: inspection.live,
            guests: inspection.guests,
            comments: inspection.comments,
            battle: inspection.battle,
            clearBattle: inspection.battle == null,
            poll: inspection.poll,
            clearPoll: inspection.poll == null,
            questions: inspection.questions,
            treasureBoxes: inspection.treasureBoxes,
            hourlyRank: inspection.hourlyRank,
            clearHourlyRank: inspection.hourlyRank == null,
            gifters: inspection.gifters,
            auctions: inspection.auctions,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, error: error.toString()));
      }
    }
  }

  Future<void> _runAction(
    Emitter<AdminLiveState> emit,
    Future<void> Function() action, {
    String? liveId,
  }) async {
    if (!state.canModerate) {
      emit(
        state.copyWith(
          error: 'You do not have permission to moderate live streams.',
        ),
      );
      return;
    }

    emit(state.copyWith(isActionBusy: true, clearError: true));
    try {
      await action();
      if (!isClosed) {
        emit(state.copyWith(isActionBusy: false));
        if (liveId != null && liveId == _inspectedLiveId) {
          add(AdminLiveDetailRequested(liveId));
        }
      }
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(isActionBusy: false, error: error.toString()));
      }
    }
  }

  Future<void> _onEnd(AdminLiveEnded event, Emitter<AdminLiveState> emit) =>
      _runAction(
        emit,
        () => _useCases.adminEndLive(event.liveId),
        liveId: event.liveId,
      );

  Future<void> _onBan(AdminLiveBanned event, Emitter<AdminLiveState> emit) =>
      _runAction(
        emit,
        () => _useCases.adminBanLive(
          liveId: event.liveId,
          reason: event.reason,
        ),
        liveId: event.liveId,
      );

  Future<void> _onKick(AdminGuestKicked event, Emitter<AdminLiveState> emit) =>
      _runAction(
        emit,
        () => _useCases.adminKickGuest(
          liveId: event.liveId,
          userId: event.userId,
        ),
        liveId: event.liveId,
      );

  Future<void> _onBoost(AdminLiveBoosted event, Emitter<AdminLiveState> emit) =>
      _runAction(
        emit,
        () => _useCases.adminBoostLive(
          liveId: event.liveId,
          durationMinutes: event.durationMinutes,
        ),
        liveId: event.liveId,
      );

  void _onErrorCleared(
    AdminLiveErrorCleared event,
    Emitter<AdminLiveState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  void _onSocketEvent(
    AdminLiveSocketEventReceived event,
    Emitter<AdminLiveState> emit,
  ) {
    final socketEvent = event.event;
    if (isClosed || socketEvent.liveId != _inspectedLiveId) return;
    final label = switch (socketEvent) {
      LiveCommentEvent() => 'New comment received',
      LiveGiftEvent(:final gift) => 'Gift received: ${gift.totalCost} coins',
      LiveGuestUpdateEvent(:final updateType) => 'Guest update: $updateType',
      LiveBattleEvent(:final updateType) => 'Battle update: $updateType',
      LiveEndedEvent() => 'Live ended',
      LiveInteractiveSocketEvent(:final payload) => 'Interactive: ${payload.event}',
      _ => 'Live event: ${socketEvent.type.name}',
    };
    var comments = state.comments;
    if (socketEvent is LiveCommentEvent) {
      comments = [
        {
          'id': socketEvent.comment.id,
          'content': socketEvent.comment.content,
          'userId': socketEvent.comment.userId,
          'username': socketEvent.comment.username,
          'createdAt': socketEvent.comment.createdAt.toIso8601String(),
        },
        ...comments,
      ];
    }
    emit(state.copyWith(comments: comments, realtimeEvent: label));
  }

  @override
  Future<void> close() async {
    await _socketSub?.cancel();
    await _socket?.disconnect();
    return super.close();
  }
}
