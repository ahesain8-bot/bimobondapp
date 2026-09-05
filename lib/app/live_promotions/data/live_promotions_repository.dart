import 'package:dio/dio.dart';
import '../domain/live_promotion_models.dart';

/// Implement only against reviewed OpenAPI/response fixtures. The supplied API
/// document specifies requests but NO campaign/options/financial envelopes.
/// Keeping this seam explicit prevents post-model defaults from charging users
/// based on guessed LIVE fields. See docs/live-promotions-integration.md.
abstract class LivePromotionResponseContract {
  bool get verified;
  LivePromotionOptions options(Object? data);
  List<LivePromotionPackage> packages(Object? data);
  LivePromotionPreview preview(Object? data);
  LivePromotionCampaign? campaign(Object? data);
  LivePromotionStats stats(Object? data);
  LivePromotionPage page(Object? data);
}

class UnverifiedLivePromotionContract implements LivePromotionResponseContract {
  const UnverifiedLivePromotionContract();
  @override
  bool get verified => false;
  @override
  LivePromotionOptions options(Object? data) =>
      throw const LivePromotionContractException('options');
  @override
  List<LivePromotionPackage> packages(Object? data) =>
      throw const LivePromotionContractException(
        'packages coin cost and duration',
      );
  @override
  LivePromotionPreview preview(Object? data) =>
      throw const LivePromotionContractException('preview');
  @override
  LivePromotionCampaign? campaign(Object? data) =>
      throw const LivePromotionContractException('campaign');
  @override
  LivePromotionStats stats(Object? data) =>
      throw const LivePromotionContractException('stats');
  @override
  LivePromotionPage page(Object? data) =>
      throw const LivePromotionContractException('mine pagination');
}

class LivePromotionsRepository {
  LivePromotionsRepository({
    required this.dio,
    required this.idTokenProvider,
    this.contract = const UnverifiedLivePromotionContract(),
    Set<String> initialUncertainPayments = const {},
    this.persistUncertainPayments,
  }) : uncertainPayments = {...initialUncertainPayments};
  final Dio dio;
  final Future<String?> Function() idTokenProvider;
  final LivePromotionResponseContract contract;
  final Set<String> _mutations = {};
  final Set<String> uncertainPayments;
  final Future<void> Function(Set<String>)? persistUncertainPayments;

  Future<void> confirmPaymentReconciled(String id) async {
    final next = {...uncertainPayments}..remove(id);
    await persistUncertainPayments?.call(next);
    uncertainPayments.remove(id);
  }

  static const base = '/promotions/lives';
  bool get responseContractVerified => contract.verified;

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final token = await idTokenProvider();
    if (token == null || token.isEmpty) throw const LivePromotionUnavailable();
    final response = await dio.request<Object?>(
      path,
      queryParameters: query,
      data: body,
      options: Options(
        method: method,
        headers: {'Authorization': 'Bearer $token'},
        // Existing ApiClient respects this flag. Never replay a financial POST.
        extra: {if (method != 'GET') 'firebase_auth_retried': true},
      ),
    );
    final code = response.statusCode;
    if (code == null || code < 200 || code >= 300) {
      throw const LivePromotionUnavailable();
    }
    return response.data;
  }

  static String _id(String value) {
    if (value.trim().isEmpty) throw const LivePromotionUnavailable();
    return Uri.encodeComponent(value);
  }

  Future<T> _mutate<T>(String key, Future<T> Function() action) async {
    if (!contract.verified) {
      throw const LivePromotionContractException('mutation response');
    }
    if (!_mutations.add(key)) throw const LivePromotionUnavailable();
    try {
      return await action();
    } finally {
      _mutations.remove(key);
    }
  }

  Future<LivePromotionOptions> getOptions() async =>
      contract.options(await _request('GET', '$base/options'));
  Future<List<LivePromotionPackage>> getPackages() async =>
      contract.packages(await _request('GET', '/promotions/packages'));
  Future<LivePromotionPreview> preview(LivePromotionDraft draft) async {
    draft.toJson();
    if (draft.packageId != null) throw const LivePromotionUnavailable();
    return contract.preview(
      await _request(
        'GET',
        '$base/custom/preview',
        query: {
          'budgetCoins': draft.budgetCoins,
          'durationDays': draft.durationDays,
          'objective': draft.objective.wireValue,
        },
      ),
    );
  }

  Future<LivePromotionPage> mine({int page = 1, int limit = 20}) async =>
      contract.page(
        await _request(
          'GET',
          '$base/mine',
          query: {'page': page, 'limit': limit},
        ),
      );
  Future<LivePromotionCampaign?> byLive(String liveId) async =>
      contract.campaign(await _request('GET', '$base/by-live/${_id(liveId)}'));
  Future<LivePromotionStats> statsByLive(String liveId) async => contract.stats(
    await _request('GET', '$base/by-live/${_id(liveId)}/stats'),
  );
  Future<LivePromotionCampaign> getCampaign(String campaignId) async {
    final campaign = contract.campaign(
      await _request('GET', '$base/${_id(campaignId)}'),
    );
    if (campaign == null || campaign.id != campaignId) {
      throw const LivePromotionUnavailable();
    }
    return campaign;
  }

  Future<LivePromotionStats> stats(String campaignId) async =>
      contract.stats(await _request('GET', '$base/${_id(campaignId)}/stats'));
  Future<LivePromotionCampaign> create(
    String liveId,
    LivePromotionDraft draft,
  ) => _mutate('live:$liveId', () async {
    final existing = await byLive(liveId);
    if (existing != null) {
      if (existing.liveId != liveId ||
          existing.status == LivePromotionStatus.unknown) {
        throw const LivePromotionUnavailable();
      }
      if (existing.status.isOpen) return existing;
    }
    try {
      final result = contract.campaign(
        await _request('POST', base, body: draft.toJson(liveId: liveId)),
      );
      if (result == null ||
          result.id.isEmpty ||
          result.liveId != liveId ||
          result.status != LivePromotionStatus.pendingPayment) {
        throw const LivePromotionUnavailable();
      }
      return result;
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        final existing = await byLive(liveId);
        if (existing != null && existing.status.isOpen) return existing;
      }
      rethrow;
    }
  });
  Future<void> pay(String campaignId) => _mutate(
    'campaign:$campaignId',
    () async {
      if (uncertainPayments.contains(campaignId)) {
        throw const LivePromotionUnavailable();
      }
      uncertainPayments.add(campaignId);
      // Persist uncertainty before sending. Reopening the app cannot replay an
      // in-flight payment whose server outcome is still unknown.
      await persistUncertainPayments?.call({...uncertainPayments});
      // Confirmation comes from a subsequent GET plus server-backed wallet, not
      // from an assumed payment envelope or a locally decremented balance.
      try {
        await _request('POST', '$base/${_id(campaignId)}/pay');
      } on DioException catch (error) {
        final code = error.response?.statusCode;
        // A conclusive rejection did not debit the wallet. Timeouts, 5xx and
        // connection loss keep the persistent lock until a later GET settles.
        if ([400, 401, 402, 403, 404, 422, 429].contains(code)) {
          await confirmPaymentReconciled(campaignId);
        }
        rethrow;
      }
    },
  );
  Future<void> edit(String campaignId, LivePromotionDraft draft) => _mutate(
    'campaign:$campaignId',
    () async {
      await _request('PATCH', '$base/${_id(campaignId)}', body: draft.toJson());
    },
  );
  Future<void> action(String campaignId, String action) =>
      _mutate('campaign:$campaignId', () async {
        if (!['pause', 'resume', 'cancel'].contains(action)) {
          throw const LivePromotionUnavailable();
        }
        await _request('PATCH', '$base/${_id(campaignId)}/$action');
      });
}
