import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/network/live_api_client.dart';
import '../../../../../core/services/live_operation_guard.dart';
import '../../../domain/entities/fan_club.dart';
import '../../../domain/usecases/add_fan_club_emote.dart';
import '../../../domain/usecases/get_fan_club.dart';
import '../../../domain/usecases/get_fan_club_members.dart';
import '../../../domain/usecases/get_my_fan_clubs.dart';
import '../../../domain/usecases/subscribe_fan_club.dart';
import '../../../domain/usecases/unsubscribe_fan_club.dart';
import '../../../domain/usecases/update_fan_club.dart';
import 'fan_club_event.dart';
import 'fan_club_state.dart';

/// Orchestrates the Fan Club screen: load club + tiers + emotes + members,
/// join / leave, and host settings (lives/mobile-api.md §20 and
/// lives/live-p0-parity.md §4).
///
/// Subscribing spends coins, so it goes through [LiveOperationGuard]: the
/// attempt is journalled before it is sent, and an uncertain outcome is never
/// re-sent on its own. Unlike a one-off entry ticket, a membership renews, so
/// a settled attempt clears its record once the server's own `membership`
/// proves the tier is active.
class FanClubBloc extends Bloc<FanClubEvent, FanClubState> {
  FanClubBloc({
    required GetFanClub getFanClub,
    required GetFanClubMembers getFanClubMembers,
    required GetMyFanClubs getMyFanClubs,
    required SubscribeFanClub subscribeFanClub,
    required UnsubscribeFanClub unsubscribeFanClub,
    required UpdateFanClub updateFanClub,
    required LiveApiClient apiClient,
    AddFanClubEmote? addFanClubEmote,
    LiveOperationGuard? operationGuard,
    String Function()? userId,
  }) : _getFanClub = getFanClub,
       _getFanClubMembers = getFanClubMembers,
       _getMyFanClubs = getMyFanClubs,
       _subscribeFanClub = subscribeFanClub,
       _unsubscribeFanClub = unsubscribeFanClub,
       _updateFanClub = updateFanClub,
       _addFanClubEmote = addFanClubEmote,
       _apiClient = apiClient,
       _operations = operationGuard ?? LiveOperationGuard.shared,
       _userId =
           userId ?? (() => fb.FirebaseAuth.instance.currentUser?.uid ?? ''),
       super(const FanClubInitial()) {
    on<FanClubLoaded>(_onLoaded);
    on<FanClubSubscribed>(_onSubscribed);
    on<FanClubUnsubscribed>(_onUnsubscribed);
    on<FanClubUpdated>(_onUpdated);
    on<FanClubEmoteAdded>(_onEmoteAdded);
    on<FanClubMessageShown>(_onMessageShown);
  }

  /// Journal scope for a purchase that is not tied to a single LIVE.
  static const String _operationScope = 'fan-club';
  static const String _operationName = 'fanClubSubscribe';

  final GetFanClub _getFanClub;
  final GetFanClubMembers _getFanClubMembers;
  final GetMyFanClubs _getMyFanClubs;
  final SubscribeFanClub _subscribeFanClub;
  final UnsubscribeFanClub _unsubscribeFanClub;
  final UpdateFanClub _updateFanClub;
  final AddFanClubEmote? _addFanClubEmote;
  final LiveApiClient _apiClient;
  final LiveOperationGuard _operations;
  final String Function() _userId;

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
      final club = results[0] as FanClub;
      final unresolved = await _unresolvedTier(creatorId, club);
      if (isClosed) return;
      emit(
        FanClubReady(
          club: club,
          members: results[1] as List<FanClubMember>,
          myClubs: results[2] as List<FanClubSubscription>,
          creatorId: creatorId,
          unresolvedTierSlug: unresolved,
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
    final creatorId = ready.creatorId!;
    final slug = event.tierSlug.trim().toUpperCase();
    final tier = ready.club.tierBySlug(slug);

    if (tier == null || !tier.isPurchasable) {
      // No server price for this tier: say so rather than charge a guess.
      emit(
        ready.copyWith(
          message: 'سعر هذه العضوية غير متاح الآن، لذلك لا يمكن الاشتراك.',
        ),
      );
      return;
    }
    if (ready.club.alreadyCovers(slug)) {
      // The server treats this as `alreadyMember`; do not send a paid request.
      emit(ready.copyWith(message: 'لديك بالفعل هذه العضوية أو أعلى منها.'));
      return;
    }

    emit(ready.copyWith(busy: true, clearMessage: true));
    try {
      final result = await _operations.run(
        userId: _userId,
        liveId: _operationScope,
        operation: _operationName,
        entityId: '$creatorId:$slug',
        // A membership renews after 30 days, so a completed purchase must not
        // leave a record that blocks the next one. An uncertain outcome still
        // keeps its pending record.
        retainSuccess: false,
        send: () => _subscribeFanClub(
          creatorId,
          club: ready.club,
          tierSlug: slug,
        ),
      );
      if (isClosed) return;
      // Membership is what grants SUBSCRIBERS chat and emotes, so it is
      // re-read from the server rather than assumed.
      final club = await _refreshClub(creatorId);
      if (isClosed) return;
      emit(
        ready.copyWith(
          busy: false,
          club: club ?? ready.club,
          clearUnresolvedTier: true,
          // A failed re-read does not undo a completed subscription and is
          // never retried as another POST.
          message: result.alreadyMember
              ? 'لديك بالفعل هذه العضوية، ولم يُخصم شيء.'
              : club == null
              ? 'تم الاشتراك، وجارٍ تأكيد العضوية'
              : 'تم الاشتراك في ${tier.displayName}',
        ),
      );
    } on FanClubPriceUnverified {
      if (isClosed) return;
      emit(
        ready.copyWith(
          busy: false,
          message: 'سعر هذه العضوية غير متاح الآن، لذلك لا يمكن الاشتراك.',
        ),
      );
    } on LiveOperationUnresolved {
      if (isClosed) return;
      emit(
        ready.copyWith(
          busy: false,
          unresolvedTierSlug: slug,
          message:
              'هناك عملية اشتراك سابقة لم تتأكد بعد. افتح الصفحة لاحقًا '
              'للتحقق من عضويتك قبل محاولة جديدة.',
        ),
      );
    } on LiveOperationNotSent catch (e) {
      if (isClosed) return;
      emit(ready.copyWith(busy: false, message: e.message));
    } catch (e) {
      if (isClosed) return;
      // The request may have reached the server. Re-read membership; if it is
      // now active the purchase completed, otherwise it stays unresolved.
      final club = await _refreshClub(creatorId);
      if (isClosed) return;
      final settled = club != null && club.alreadyCovers(slug);
      if (settled) {
        await _settle(creatorId, slug);
        if (isClosed) return;
        emit(
          ready.copyWith(
            busy: false,
            club: club,
            clearUnresolvedTier: true,
            message: 'تم الاشتراك في ${tier.displayName}',
          ),
        );
        return;
      }
      emit(
        ready.copyWith(
          busy: false,
          club: club ?? ready.club,
          unresolvedTierSlug: slug,
          message:
              'تعذر تأكيد الاشتراك. لن نعيد إرسال العملية؛ تحقق من عضويتك '
              'ورصيدك ثم حاول لاحقًا.',
        ),
      );
    }
  }

  /// Re-reads the club after a membership change. Returns null when the read
  /// fails, so the caller keeps the previous, conservative membership.
  Future<FanClub?> _refreshClub(String creatorId) async {
    try {
      return await _getFanClub(creatorId);
    } catch (_) {
      return null;
    }
  }

  /// Returns the tier of a still-open purchase, and clears the record when the
  /// server's own membership already proves that purchase landed.
  Future<String?> _unresolvedTier(String creatorId, FanClub club) async {
    final account = _userId();
    if (account.isEmpty) return null;
    for (final tier in club.tiers) {
      final record = await _operations.read(
        userId: account,
        liveId: _operationScope,
        operation: _operationName,
        entityId: '$creatorId:${tier.slug}',
      );
      if (record.outcome == LiveOperationOutcome.notSent ||
          record.outcome == LiveOperationOutcome.rejected) {
        continue;
      }
      if (club.alreadyCovers(tier.slug)) {
        await _settle(creatorId, tier.slug);
        continue;
      }
      return tier.slug;
    }
    return null;
  }

  Future<void> _settle(String creatorId, String tierSlug) async {
    final account = _userId();
    if (account.isEmpty) return;
    try {
      await _operations.settle(
        userId: account,
        liveId: _operationScope,
        operation: _operationName,
        entityId: '$creatorId:$tierSlug',
      );
    } catch (_) {
      // Keeping the record is the safe outcome; it only delays a renewal.
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
      // Member count and membership come from the server, never from local
      // arithmetic on the previous card.
      final club = await _refreshClub(ready.creatorId!);
      if (isClosed) return;
      emit(
        ready.copyWith(
          busy: false,
          club:
              club ??
              ready.club.copyWith(
                isMember: false,
                membership: const FanClubMembership(),
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
        priceCoins: event.priceCoins,
      );
      if (isClosed) return;
      emit(
        ready.copyWith(
          busy: false,
          club: updated.copyWith(
            isMember: ready.club.isMember,
            memberCount: ready.club.memberCount,
            membership: ready.club.membership,
          ),
          message: 'تم حفظ الإعدادات',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(ready.copyWith(busy: false, message: 'تعذر الحفظ: $e'));
    }
  }

  Future<void> _onEmoteAdded(
    FanClubEmoteAdded event,
    Emitter<FanClubState> emit,
  ) async {
    final ready = _readyOrNull(state);
    final addEmote = _addFanClubEmote;
    if (ready == null || ready.busy || ready.creatorId == null) return;
    if (addEmote == null) return;
    emit(ready.copyWith(busy: true));
    try {
      final club = await addEmote(
        ready.creatorId!,
        code: event.code,
        imageUrl: event.imageUrl,
        minTier: event.minTier,
      );
      if (isClosed) return;
      emit(
        ready.copyWith(
          busy: false,
          club: club,
          message: 'تمت إضافة الملصق',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(ready.copyWith(busy: false, message: 'تعذرت إضافة الملصق: $e'));
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
