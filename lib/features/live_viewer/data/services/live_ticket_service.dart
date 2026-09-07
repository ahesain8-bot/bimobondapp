import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import '../../../../core/services/live_operation_guard.dart';

/// Server-authoritative entry status for a ticketed LIVE.
///
/// The documented ticket endpoint exposes these fields at the response root.
/// Keeping the decoder deliberately strict prevents a UI card or an unrelated
/// wallet response from being mistaken for proof that a paid entry succeeded.
class LiveTicketAccess {
  const LiveTicketAccess({
    required this.priceCoins,
    required this.hasTicket,
    this.awaitingConfirmation = false,
  });

  final int priceCoins;
  final bool hasTicket;
  final bool awaitingConfirmation;

  factory LiveTicketAccess.fromPayload(Map<String, dynamic> payload) {
    final hasTicket = payload['hasTicket'];
    final price = payload['ticketPriceCoins'];
    if (hasTicket is! bool || price is! int || price < 0) {
      throw const FormatException('INVALID_LIVE_TICKET_RESPONSE');
    }
    return LiveTicketAccess(priceCoins: price, hasTicket: hasTicket);
  }
}

/// Reads and purchases `POST /lives/:id/ticket` without retrying an uncertain
/// charge.  A successful POST is followed by the authoritative GET; no local
/// balance change or a socket event is accepted as purchase confirmation.
class LiveTicketService {
  LiveTicketService({
    required LiveApiClient apiClient,
    String Function()? userId,
    LiveOperationGuard? operationGuard,
  }) : _api = apiClient,
       _userId =
           userId ?? (() => fb.FirebaseAuth.instance.currentUser?.uid ?? ''),
       _operations = operationGuard ?? LiveOperationGuard.shared;

  final LiveApiClient _api;
  final String Function() _userId;
  final LiveOperationGuard _operations;

  Future<LiveTicketAccess> status(String liveId) async {
    if (liveId.trim().isEmpty) {
      throw const LiveOperationNotSent('Select a valid LIVE first.');
    }
    final account = _userId();
    final payload = await _api.get(ApiEndpoints.liveTicket(liveId));
    final access = LiveTicketAccess.fromPayload(payload);
    if (account != _userId())
      throw const LiveOperationNotSent('The signed-in account changed.');
    if (access.hasTicket) {
      await _operations.confirm(
        userId: account,
        liveId: liveId,
        operation: 'ticket',
        entityId: 'entry',
      );
      return access;
    }
    final record = await _operations.read(
      userId: account,
      liveId: liveId,
      operation: 'ticket',
      entityId: 'entry',
    );
    return LiveTicketAccess(
      priceCoins: access.priceCoins,
      hasTicket: false,
      awaitingConfirmation:
          record.outcome == LiveOperationOutcome.unknown ||
          record.outcome == LiveOperationOutcome.confirmed,
    );
  }

  Future<LiveTicketAccess> purchase(String liveId) {
    return _operations.run(
      userId: _userId,
      liveId: liveId,
      operation: 'ticket',
      entityId: 'entry',
      send: () async {
        await _api.post(ApiEndpoints.liveTicket(liveId));
        final confirmed = await status(liveId);
        if (!confirmed.hasTicket) {
          throw const FormatException('LIVE_TICKET_NOT_CONFIRMED');
        }
        return confirmed;
      },
    );
  }
}
