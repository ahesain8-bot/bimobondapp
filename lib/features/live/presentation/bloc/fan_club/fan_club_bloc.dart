import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/network/live_api_client.dart';
import '../../../domain/entities/fan_club.dart';
import '../../../domain/usecases/get_fan_club.dart';
import '../../../domain/usecases/get_fan_club_members.dart';
import '../../../domain/usecases/get_my_fan_clubs.dart';
import '../../../domain/usecases/subscribe_fan_club.dart';
import '../../../domain/usecases/unsubscribe_fan_club.dart';
import '../../../domain/usecases/update_fan_club.dart';
import 'fan_club_event.dart';
import 'fan_club_state.dart';

/// Orchestrates the Fan Club screen: load club + members + my-clubs,
/// join / leave, and host settings (lives/mobile-api.md §20).
class FanClubBloc extends Bloc<FanClubEvent, FanClubState> {
  FanClubBloc({
    required GetFanClub getFanClub,
    required GetFanClubMembers getFanClubMembers,
    required GetMyFanClubs getMyFanClubs,
    required SubscribeFanClub subscribeFanClub,
    required UnsubscribeFanClub unsubscribeFanClub,
    required UpdateFanClub updateFanClub,
    required LiveApiClient apiClient,
  })  : _getFanClub = getFanClub,
        _getFanClubMembers = getFanClubMembers,
        _getMyFanClubs = getMyFanClubs,
        _subscribeFanClub = subscribeFanClub,
        _unsubscribeFanClub = unsubscribeFanClub,
        _updateFanClub = updateFanClub,
        _apiClient = apiClient,
        super(const FanClubInitial()) {
    on<FanClubLoaded>(_onLoaded);
    on<FanClubSubscribed>(_onSubscribed);
    on<FanClubUnsubscribed>(_onUnsubscribed);
    on<FanClubUpdated>(_onUpdated);
    on<FanClubMessageShown>(_onMessageShown);
  }

  final GetFanClub _getFanClub;
  final GetFanClubMembers _getFanClubMembers;
  final GetMyFanClubs _getMyFanClubs;
  final SubscribeFanClub _subscribeFanClub;
  final UnsubscribeFanClub _unsubscribeFanClub;
  final UpdateFanClub _updateFanClub;
  final LiveApiClient _apiClient;

  Future<void> _onLoaded(
    FanClubLoaded event,
    Emitter<FanClubState> emit,
  ) async {
    emit(const FanClubLoading());

    String creatorId;
    try {
      creatorId = await _resolveCreatorId(event.creatorId);
    } catch (e) {
      emit(FanClubFailure(message: e.toString()));
      return;
    }
    if (isClosed) return;

    try {
      final results = await Future.wait<Object>([
        _getFanClub(creatorId),
        _getFanClubMembers(creatorId),
        _getMyFanClubs(),
      ]);
      if (isClosed) return;
      emit(
        FanClubReady(
          club: results[0] as FanClub,
          members: results[1] as List<FanClubMember>,
          myClubs: results[2] as List<FanClubSubscription>,
          creatorId: creatorId,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(FanClubFailure(message: e.toString()));
    }
  }

  Future<void> _onSubscribed(
    FanClubSubscribed event,
    Emitter<FanClubState> emit,
  ) async {
    final ready = _readyOrNull(state);
    if (ready == null || ready.busy || ready.creatorId == null) return;
    emit(ready.copyWith(busy: true));
    try {
      await _subscribeFanClub(ready.creatorId!);
      if (isClosed) return;
      emit(
        ready.copyWith(
          busy: false,
          club: FanClub(
            enabled: ready.club.enabled,
            name: ready.club.name,
            memberCount: ready.club.memberCount + 1,
            isMember: true,
          ),
          message: 'تم الانضمام إلى مجتمع المعجبين',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(ready.copyWith(busy: false, message: 'تعذر الانضمام: $e'));
    }
  }

  Future<void> _onUnsubscribed(
    FanClubUnsubscribed event,
    Emitter<FanClubState> emit,
  ) async {
    final ready = _readyOrNull(state);
    if (ready == null || ready.busy || ready.creatorId == null) return;
    emit(ready.copyWith(busy: true));
    try {
      await _unsubscribeFanClub(ready.creatorId!);
      if (isClosed) return;
      emit(
        ready.copyWith(
          busy: false,
          club: FanClub(
            enabled: ready.club.enabled,
            name: ready.club.name,
            memberCount: (ready.club.memberCount - 1).clamp(0, 1 << 31),
            isMember: false,
          ),
          message: 'تمت مغادرة المجتمع',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(ready.copyWith(busy: false, message: 'تعذر المغادرة: $e'));
    }
  }

  Future<void> _onUpdated(
    FanClubUpdated event,
    Emitter<FanClubState> emit,
  ) async {
    final ready = _readyOrNull(state);
    if (ready == null || ready.busy || ready.creatorId == null) return;
    emit(ready.copyWith(busy: true));
    try {
      final updated = await _updateFanClub(
        ready.creatorId!,
        name: event.name,
        enabled: event.enabled,
      );
      if (isClosed) return;
      emit(
        ready.copyWith(
          busy: false,
          club: updated.copyWith(
            isMember: ready.club.isMember,
            memberCount: ready.club.memberCount,
          ),
          message: 'تم حفظ الإعدادات',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(ready.copyWith(busy: false, message: 'تعذر الحفظ: $e'));
    }
  }

  void _onMessageShown(
    FanClubMessageShown event,
    Emitter<FanClubState> emit,
  ) {
    final ready = _readyOrNull(state);
    if (ready == null || ready.message == null) return;
    emit(ready.copyWith(clearMessage: true));
  }

  Future<String> _resolveCreatorId(String? explicit) async {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final me = await _apiClient.get('/auth/me');
    final id = me['id']?.toString();
    if (id == null || id.isEmpty) {
      throw StateError('Missing creator id');
    }
    return id;
  }

  FanClubReady? _readyOrNull(FanClubState state) =>
      state is FanClubReady ? state : null;
}
