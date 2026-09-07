import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bimobondapp/app/live_promotions/domain/live_promotion_models.dart';
import 'package:bimobondapp/app/live_promotions/data/live_promotions_repository.dart';
import 'package:bimobondapp/app/live_promotions/presentation/controllers/live_promotions_controller.dart';
import 'package:bimobondapp/app/wallets/data/models/wallet_model.dart';

const draft = LivePromotionDraft(budgetCoins: 20, durationDays: 1);
LivePromotionCampaign campaign([
  LivePromotionStatus status = LivePromotionStatus.pendingPayment,
]) => LivePromotionCampaign(
  id: 'campaign-1',
  liveId: 'live-1',
  status: status,
  rawStatus: status.wireValue,
  budgetCoins: 20,
  durationDays: 1,
  objective: LivePromotionObjective.views,
  automaticAudience: true,
  draft: draft,
);
const eligible = LivePromotionEligibility(
  liveId: 'live-1',
  authenticatedUserId: 'host-1',
  hostUserId: 'host-1',
  visibility: 'PUBLIC',
  liveStatus: 'LIVE',
  accountPrivate: false,
  accountBanned: false,
);

// Test-only synthetic adapter, NOT an assertion about any production JSON.
class TestContract implements LivePromotionResponseContract {
  @override
  bool get verified => true;
  @override
  LivePromotionOptions options(Object? d) => const LivePromotionOptions();
  @override
  List<LivePromotionPackage> packages(Object? d) => [];
  @override
  LivePromotionPreview preview(Object? d) =>
      const LivePromotionPreview(estimatedViewers: 100);
  @override
  LivePromotionCampaign? campaign(Object? d) {
    final marker = (d as Map)['testStatus'];
    if (marker == null) return null;
    final status = LivePromotionStatus.parse(marker as String);
    return LivePromotionCampaign(
      id: 'campaign-1',
      liveId: 'live-1',
      status: status,
      rawStatus: marker,
      budgetCoins: 20,
      durationDays: 1,
      objective: LivePromotionObjective.views,
      automaticAudience: true,
    );
  }

  @override
  LivePromotionStats stats(Object? d) => const LivePromotionStats();
  @override
  LivePromotionPage page(Object? d) =>
      const LivePromotionPage(items: [], hasMore: false);
}

class Adapter implements HttpClientAdapter {
  Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) => handler(o);
  @override
  void close({bool force = false}) {}
}

ResponseBody body([String? status, int code = 200]) => ResponseBody.fromString(
  jsonEncode({'testStatus': status}),
  code,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class Repo extends LivePromotionsRepository {
  Repo()
    : super(
        dio: Dio(),
        idTokenProvider: () async => 'test',
        contract: TestContract(),
      );
  LivePromotionCampaign current = campaign();
  int creates = 0, pays = 0, cancels = 0, reads = 0;
  Completer<LivePromotionCampaign>? createGate;
  Completer<void>? payGate;
  // Opt-in gates: default false keeps every pre-existing test unchanged.
  Completer<LivePromotionCampaign>? readGate;
  bool gateStats = false, gateMine = false;
  final statsGates = <Completer<LivePromotionStats>>[];
  final mineGates = <Completer<LivePromotionPage>>[];
  final minePages = <int>[];
  bool settlePay = true;
  final previews = <Completer<LivePromotionPreview>>[];
  @override
  Future<LivePromotionOptions> getOptions() async =>
      const LivePromotionOptions();
  @override
  Future<List<LivePromotionPackage>> getPackages() async => [];
  @override
  Future<LivePromotionCampaign?> byLive(String id) async => null;
  @override
  Future<LivePromotionCampaign> create(String id, LivePromotionDraft d) async {
    creates++;
    return createGate?.future ?? current;
  }

  @override
  Future<LivePromotionCampaign> getCampaign(String id) async {
    reads++;
    if (readGate != null) await readGate!.future;
    return current;
  }

  @override
  Future<LivePromotionStats> stats(String id) async {
    // Only the first call is held open; later calls resolve normally so a test
    // can let a newer campaign finish while an older read is still pending.
    if (!gateStats || statsGates.isNotEmpty) {
      return const LivePromotionStats(
        impressions: 4,
        spendCoins: 1,
        remainingCoins: 19,
      );
    }
    final gate = Completer<LivePromotionStats>();
    statsGates.add(gate);
    return gate.future;
  }

  @override
  Future<LivePromotionPage> mine({int page = 1, int limit = 20}) async {
    minePages.add(page);
    if (!gateMine) {
      return LivePromotionPage(items: [current], hasMore: page == 1);
    }
    final gate = Completer<LivePromotionPage>();
    mineGates.add(gate);
    return gate.future;
  }

  @override
  Future<void> pay(String id) async {
    pays++;
    uncertainPayments.add(id);
    if (payGate != null) await payGate!.future;
    if (settlePay) current = campaign(LivePromotionStatus.active);
  }

  @override
  Future<void> action(String id, String action) async {
    if (action == 'cancel') {
      cancels++;
      current = campaign(LivePromotionStatus.cancelled);
    }
  }

  @override
  Future<LivePromotionPreview> preview(LivePromotionDraft d) {
    final c = Completer<LivePromotionPreview>();
    previews.add(c);
    return c.future;
  }
}

void main() {
  test(
    'budget exclusivity, minimum, durations, no package duration override',
    () {
      expect(draft.validate(), isEmpty);
      for (final value in [0, 4]) {
        expect(
          LivePromotionDraft(budgetCoins: value, durationDays: 1).validate(),
          contains(LivePromotionValidation.minimumBudget),
        );
      }
      for (final d in [1, 3, 7, 14]) {
        expect(
          LivePromotionDraft(budgetCoins: 5, durationDays: d).validate(),
          isEmpty,
        );
      }
      expect(
        const LivePromotionDraft(budgetCoins: 5, durationDays: 2).validate(),
        contains(LivePromotionValidation.duration),
      );
      expect(
        const LivePromotionDraft(packageId: 'p', budgetCoins: 5).validate(),
        contains(LivePromotionValidation.budgetMode),
      );
      expect(
        const LivePromotionDraft(packageId: 'p', durationDays: 1).validate(),
        contains(LivePromotionValidation.budgetMode),
      );
      expect(
        const LivePromotionDraft(packageId: 'p').toJson().keys,
        contains('packageId'),
      );
      expect(
        const LivePromotionDraft(
          packageId: 'p',
        ).toJson().containsKey('durationDays'),
        false,
      );
    },
  );
  test('automatic audience drops every stale custom field', () {
    final data = const LivePromotionDraft(
      budgetCoins: 5,
      durationDays: 1,
      targetGenders: ['FEMALE'],
      targetAgeMin: 30,
      targetAgeMax: 10,
      targetCountryCodes: ['EG'],
      targetLanguages: ['ar'],
      targetCategoryIds: ['c'],
      targetLatitude: 20,
    ).toJson(liveId: 'live-1');
    expect(data, {
      'liveId': 'live-1',
      'objective': 'VIEWS',
      'automaticAudience': true,
      'budgetCoins': 5,
      'durationDays': 1,
    });
  });
  test(
    'custom ages and geographic all-or-none, finite bounds and positive radius',
    () {
      LivePromotionDraft geo(double? lat, double? lng, double? r) =>
          LivePromotionDraft(
            budgetCoins: 5,
            durationDays: 1,
            automaticAudience: false,
            targetLatitude: lat,
            targetLongitude: lng,
            targetRadiusKm: r,
          );
      expect(geo(null, null, null).validate(), isEmpty);
      expect(geo(90, -180, 1).validate(), isEmpty);
      for (final d in [
        geo(1, null, null),
        geo(null, 1, 1),
        geo(91, 0, 1),
        geo(0, 181, 1),
        geo(0, 0, 0),
        geo(double.nan, 0, 1),
        geo(0, 0, double.infinity),
      ]) {
        expect(d.validate(), contains(LivePromotionValidation.geo));
      }
      expect(
        const LivePromotionDraft(
          budgetCoins: 5,
          durationDays: 1,
          automaticAudience: false,
          targetAgeMin: 35,
          targetAgeMax: 18,
        ).validate(),
        contains(LivePromotionValidation.ages),
      );
    },
  );
  test(
    'unknown/terminal statuses are read only and only pending can edit/pay',
    () {
      for (final s in LivePromotionStatus.values) {
        expect(s.canEdit, s == LivePromotionStatus.pendingPayment);
        expect(s.canPay, s.canEdit);
        expect(
          s.canCancel,
          [
            LivePromotionStatus.pendingPayment,
            LivePromotionStatus.active,
            LivePromotionStatus.paused,
          ].contains(s),
        );
      }
      expect(
        LivePromotionStatus.parse('NEW_SERVER_STATUS'),
        LivePromotionStatus.unknown,
      );
      expect(const LivePromotionStats().spendCoins, isNull);
    },
  );
  test(
    'eligibility requires persisted public host live, known account and enabled flag',
    () {
      expect(eligible.canCreate, true);
      expect(const LivePromotionEligibility().canCreate, false);
      for (final e in [
        const LivePromotionEligibility(
          liveId: '',
          authenticatedUserId: 'h',
          hostUserId: 'h',
          visibility: 'PUBLIC',
          liveStatus: 'LIVE',
          accountPrivate: false,
          accountBanned: false,
        ),
        const LivePromotionEligibility(
          liveId: 'l',
          authenticatedUserId: 'v',
          hostUserId: 'h',
          visibility: 'PUBLIC',
          liveStatus: 'LIVE',
          accountPrivate: false,
          accountBanned: false,
        ),
        const LivePromotionEligibility(
          liveId: 'l',
          authenticatedUserId: 'h',
          hostUserId: 'h',
          visibility: 'PUBLIC',
          liveStatus: 'LIVE',
          accountPrivate: false,
          accountBanned: false,
          promotionsEnabled: false,
        ),
        const LivePromotionEligibility(
          liveId: 'l',
          authenticatedUserId: 'h',
          hostUserId: 'h',
          visibility: 'PRIVATE',
          liveStatus: 'LIVE',
          accountPrivate: false,
          accountBanned: false,
        ),
        const LivePromotionEligibility(
          liveId: 'l',
          authenticatedUserId: 'h',
          hostUserId: 'h',
          visibility: 'PUBLIC',
          liveStatus: 'ENDED',
          accountPrivate: false,
          accountBanned: false,
        ),
        const LivePromotionEligibility(
          liveId: 'l',
          authenticatedUserId: 'h',
          hostUserId: 'h',
          visibility: 'PUBLIC',
          liveStatus: 'LIVE',
          accountPrivate: true,
          accountBanned: false,
        ),
        const LivePromotionEligibility(
          liveId: 'l',
          authenticatedUserId: 'h',
          hostUserId: 'h',
          visibility: 'PUBLIC',
          liveStatus: 'LIVE',
          accountPrivate: false,
          accountBanned: true,
        ),
      ]) {
        expect(e.canCreate, false);
      }
    },
  );
  test(
    'missing wallet/legacy USD is not a verified coin balance; zero coins is valid',
    () {
      expect(WalletModel.fromJson({}).hasVerifiedCoinBalance, false);
      expect(
        WalletModel.fromJson({'balanceUsd': 100}).hasVerifiedCoinBalance,
        false,
      );
      expect(
        WalletModel.fromJson({'balanceCoins': 0}).hasVerifiedCoinBalance,
        true,
      );
      expect(
        WalletModel.fromJson({'balanceCoins': 'bad'}).hasVerifiedCoinBalance,
        false,
      );
    },
  );
  test(
    'all documented endpoints, dynamic auth, query and verb exact; accepts 2xx',
    () async {
      final requests = <RequestOptions>[];
      var token = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = Adapter((o) async {
          requests.add(o);
          return body(
            o.path.contains('by-live') ? null : 'PENDING_PAYMENT',
            o.method == 'POST' ? 201 : 200,
          );
        });
      final repo = LivePromotionsRepository(
        dio: dio,
        idTokenProvider: () async => 'mock-${++token}',
        contract: TestContract(),
      );
      await repo.getOptions();
      await repo.getPackages();
      await repo.preview(draft);
      await repo.mine(page: 2);
      await repo.byLive('live-1');
      await repo.statsByLive('live-1');
      await repo.getCampaign('campaign-1');
      await repo.stats('campaign-1');
      await repo.create('live-1', draft);
      await repo.edit('campaign-1', draft);
      await repo.pay('campaign-1');
      for (final action in ['pause', 'resume', 'cancel']) {
        await repo.action('campaign-1', action);
      }
      expect(requests.map((r) => '${r.method} ${r.path}'), [
        'GET /promotions/lives/options',
        'GET /promotions/packages',
        'GET /promotions/lives/custom/preview',
        'GET /promotions/lives/mine',
        'GET /promotions/lives/by-live/live-1',
        'GET /promotions/lives/by-live/live-1/stats',
        'GET /promotions/lives/campaign-1',
        'GET /promotions/lives/campaign-1/stats',
        'GET /promotions/lives/by-live/live-1',
        'POST /promotions/lives',
        'PATCH /promotions/lives/campaign-1',
        'POST /promotions/lives/campaign-1/pay',
        'PATCH /promotions/lives/campaign-1/pause',
        'PATCH /promotions/lives/campaign-1/resume',
        'PATCH /promotions/lives/campaign-1/cancel',
      ]);
      expect(requests[2].queryParameters, {
        'budgetCoins': 20,
        'durationDays': 1,
        'objective': 'VIEWS',
      });
      expect(requests[3].queryParameters, {'page': 2, 'limit': 20});
      expect(requests[9].data, draft.toJson(liveId: 'live-1'));
      for (var i = 0; i < requests.length; i++) {
        expect(requests[i].headers['Authorization'], 'Bearer mock-${i + 1}');
      }
      expect(
        requests
            .where((r) => r.method != 'GET')
            .every((r) => r.extra['firebase_auth_retried'] == true),
        true,
      );
    },
  );
  test(
    'open campaign reused, completed permits create, unknown blocks',
    () async {
      for (final status in LivePromotionStatus.values) {
        var posts = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
          ..httpClientAdapter = Adapter((o) async {
            if (o.method == 'POST') {
              posts++;
              return body('PENDING_PAYMENT', 201);
            }
            return body(status.wireValue);
          });
        final repo = LivePromotionsRepository(
          dio: dio,
          idTokenProvider: () async => 'test',
          contract: TestContract(),
        );
        if (status == LivePromotionStatus.unknown) {
          await expectLater(
            repo.create('live-1', draft),
            throwsA(isA<LivePromotionUnavailable>()),
          );
        } else {
          await repo.create('live-1', draft);
        }
        expect(
          posts,
          status == LivePromotionStatus.completed ||
                  status == LivePromotionStatus.cancelled
              ? 1
              : 0,
        );
      }
    },
  );
  test(
    'unverified schema blocks mutation before any POST and rejects malformed success',
    () async {
      var calls = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = Adapter((o) async {
          calls++;
          return body();
        });
      final repo = LivePromotionsRepository(
        dio: dio,
        idTokenProvider: () async => 'test',
      );
      await expectLater(
        repo.create('live-1', draft),
        throwsA(isA<LivePromotionContractException>()),
      );
      expect(calls, 0);
      await expectLater(
        repo.getOptions(),
        throwsA(isA<LivePromotionContractException>()),
      );
    },
  );
  test(
    'double taps cannot overlap creation or payment; wallet is fetched, never charged locally',
    () async {
      final repo = Repo()
        ..createGate = Completer<LivePromotionCampaign>()
        ..payGate = Completer<void>();
      var walletReads = 0;
      final c = LivePromotionsController(
        repository: repo,
        refreshWallet: () async {
          walletReads++;
          return repo.pays == 0 ? 100 : 80;
        },
        refreshEligibility: (_) async => eligible,
      );
      final creating = c.create('live-1', draft);
      await Future<void>.delayed(Duration.zero);
      await c.create('live-1', draft);
      await c.pay();
      expect(repo.creates, 1);
      expect(repo.pays, 0);
      repo.createGate!.complete(campaign());
      await creating;
      final paying = c.pay();
      await Future<void>.delayed(Duration.zero);
      await c.pay();
      expect(repo.pays, 1);
      repo.payGate!.complete();
      await paying;
      expect(c.state.balanceCoins, 80);
      expect(walletReads, 3);
      expect(c.state.campaign!.status, LivePromotionStatus.active);
      await c.close();
    },
  );
  test('insufficient balance does not POST', () async {
    final repo = Repo();
    final c = LivePromotionsController(
      repository: repo,
      refreshWallet: () async => 4,
    );
    await c.openCampaign('campaign-1');
    await c.pay();
    expect(repo.pays, 0);
    expect(c.state.error, isA<LivePromotionInsufficientBalance>());
    await c.close();
  });
  test(
    'timeout reconciles campaign and wallet and stays locked while pending',
    () async {
      final repo = Repo()
        ..payGate = Completer<void>()
        ..settlePay = false;
      var wallets = 0;
      final c = LivePromotionsController(
        repository: repo,
        refreshWallet: () async {
          wallets++;
          return 100;
        },
      );
      await c.openCampaign('campaign-1');
      final before = wallets;
      final paying = c.pay();
      await Future<void>.delayed(Duration.zero);
      repo.payGate!.completeError(TimeoutException('unknown'));
      await paying;
      expect(c.state.paymentUncertain, true);
      expect(wallets, greaterThan(before));
      await c.pay();
      expect(repo.pays, 1);
      repo.current = campaign(LivePromotionStatus.active);
      await c.openCampaign('campaign-1');
      expect(c.state.paymentUncertain, false);
      await c.close();
    },
  );
  test(
    'cancellation refreshes status statistics and authoritative wallet',
    () async {
      final repo = Repo()..current = campaign(LivePromotionStatus.active);
      var wallets = 0;
      final c = LivePromotionsController(
        repository: repo,
        refreshWallet: () async {
          wallets++;
          return 99;
        },
      );
      await c.openCampaign('campaign-1');
      final before = wallets;
      await c.cancel();
      expect(repo.cancels, 1);
      expect(wallets, before + 1);
      expect(c.state.campaign!.status, LivePromotionStatus.cancelled);
      expect(c.state.stats!.remainingCoins, 19);
      await c.close();
    },
  );
  testWidgets('preview ignores stale responses and disposal cancels debounce', (
    tester,
  ) async {
    final repo = Repo();
    final c = LivePromotionsController(
      repository: repo,
      refreshWallet: () async => 100,
    );
    c.schedulePreview(draft);
    await tester.pump(const Duration(milliseconds: 401));
    c.schedulePreview(
      const LivePromotionDraft(budgetCoins: 50, durationDays: 3),
    );
    await tester.pump(const Duration(milliseconds: 401));
    repo.previews[1].complete(
      const LivePromotionPreview(estimatedViewers: 222),
    );
    await tester.pump();
    repo.previews[0].complete(
      const LivePromotionPreview(estimatedViewers: 111),
    );
    await tester.pump();
    expect(c.state.preview!.estimatedViewers, 222);
    c.schedulePreview(draft);
    await c.close();
    await tester.pump(const Duration(seconds: 1));
    expect(repo.previews.length, 2);
  });
  testWidgets(
    'live end waits for server terminal status and cancels background polling',
    (tester) async {
      final repo = Repo()..current = campaign(LivePromotionStatus.active);
      final c = LivePromotionsController(
        repository: repo,
        refreshWallet: () async => 100,
      );
      await c.openCampaign('campaign-1');
      c.onLiveEnded();
      await tester.pump();
      expect(c.state.cleanupPending, true);
      c.onBackground();
      final before = repo.reads;
      await tester.pump(const Duration(seconds: 20));
      expect(repo.reads, before);
      repo.current = campaign(LivePromotionStatus.completed);
      c.onForeground();
      await tester.pump();
      expect(c.state.cleanupPending, false);
      await c.close();
    },
  );

  // --- Regression tests for defects proven in the current controller. ---

  LivePromotionCampaign listed(String id) => LivePromotionCampaign(
    id: id,
    liveId: 'live-1',
    status: LivePromotionStatus.active,
    rawStatus: 'ACTIVE',
    budgetCoins: 20,
    durationDays: 1,
    objective: LivePromotionObjective.views,
    automaticAudience: true,
    draft: draft,
  );

  test('a stored package campaign is comparable without request validation', () {
    // A package create request omits durationDays, but the campaign the server
    // stores has one. Re-validating stored data as a request is a category
    // error: it makes a legitimate campaign unquotable.
    const stored = LivePromotionDraft(
      packageId: 'package-1',
      durationDays: 7,
      automaticAudience: false,
      targetCountryCodes: ['EG'],
    );
    expect(
      stored.validate(),
      contains(LivePromotionValidation.budgetMode),
      reason: 'still invalid as a create request',
    );
    expect(
      () => stored.toJson(),
      throwsA(isA<LivePromotionValidationException>()),
    );
    final comparable = stored.toComparableJson();
    expect(comparable['packageId'], 'package-1');
    expect(comparable['targetCountryCodes'], ['EG']);
  });

  test('a package campaign with a custom audience can still be paid', () async {
    final packageCampaign = LivePromotionCampaign(
      id: 'campaign-1',
      liveId: 'live-1',
      status: LivePromotionStatus.pendingPayment,
      rawStatus: 'PENDING_PAYMENT',
      budgetCoins: 20,
      durationDays: 7,
      objective: LivePromotionObjective.views,
      automaticAudience: false,
      draft: const LivePromotionDraft(
        packageId: 'package-1',
        durationDays: 7,
        automaticAudience: false,
        targetCountryCodes: ['EG'],
      ),
    );
    final repo = Repo()..current = packageCampaign;
    final c = LivePromotionsController(
      repository: repo,
      refreshWallet: () async => 100,
    );
    await c.openCampaign('campaign-1');
    await c.pay();
    expect(c.state.error, isNull);
    expect(repo.pays, 1);
    await c.close();
  });

  test(
    'late stats never land on a campaign the user has switched away from',
    () async {
      final repo = Repo();
      final c = LivePromotionsController(
        repository: repo,
        refreshWallet: () async => 100,
      );
      await c.openCampaign('campaign-1');
      repo.gateStats = true;
      // Background cleanup reads campaign-1 without taking the loading flag.
      c.onLiveEnded();
      await Future.delayed(Duration.zero);
      expect(repo.statsGates.length, 1);
      // Meanwhile the user opens a different campaign, which completes first.
      repo.current = listed('campaign-2');
      await c.openCampaign('campaign-2');
      expect(c.state.campaign!.id, 'campaign-2');
      expect(c.state.stats!.impressions, 4);
      // campaign-1's stats resolve last; they must be discarded, not displayed.
      repo.statsGates[0].complete(const LivePromotionStats(impressions: 7));
      await Future.delayed(Duration.zero);
      expect(c.state.campaign!.id, 'campaign-2');
      expect(c.state.stats!.impressions, 4);
      await c.close();
    },
  );

  test('a stale loadMore page never lands on a refreshed list', () async {
    final repo = Repo()..gateMine = true;
    final c = LivePromotionsController(
      repository: repo,
      refreshWallet: () async => 100,
    );
    final first = c.refresh();
    await Future.delayed(Duration.zero);
    repo.mineGates[0].complete(
      LivePromotionPage(items: [listed('c1')], hasMore: true),
    );
    await first;
    expect(c.state.items.map((e) => e.id).toList(), ['c1']);

    final second = c.loadMore();
    await Future.delayed(Duration.zero);
    repo.mineGates[1].complete(
      LivePromotionPage(items: [listed('c2')], hasMore: true),
    );
    await second;
    expect(c.state.items.map((e) => e.id).toList(), ['c1', 'c2']);

    // Page 3 is in flight when the list is reloaded from page 1.
    final stale = c.loadMore();
    await Future.delayed(Duration.zero);
    final reload = c.refresh();
    await Future.delayed(Duration.zero);
    repo.mineGates[3].complete(
      LivePromotionPage(items: [listed('c1')], hasMore: true),
    );
    await reload;
    repo.mineGates[2].complete(
      LivePromotionPage(items: [listed('c3')], hasMore: true),
    );
    await stale;
    expect(c.state.items.map((e) => e.id).toList(), ['c1']);

    // The cursor must still be at page 1, so the next fetch is page 2 - not 3.
    final next = c.loadMore();
    await Future.delayed(Duration.zero);
    repo.mineGates[4].complete(
      const LivePromotionPage(items: [], hasMore: false),
    );
    await next;
    expect(repo.minePages, [1, 2, 3, 1, 2]);
    await c.close();
  });

  test('closing the screen mid-flight never sends the payment POST', () async {
    final repo = Repo();
    final c = LivePromotionsController(
      repository: repo,
      refreshWallet: () async => 100,
    );
    await c.refresh();
    expect(c.state.balanceCoins, 100);
    repo.readGate = Completer<LivePromotionCampaign>();
    final paying = c.pay(confirmedCampaign: campaign());
    await Future.delayed(Duration.zero);
    await c.close();
    repo.readGate!.complete(campaign());
    await paying;
    expect(repo.pays, 0);
    // Nothing was sent, so no uncertainty may be recorded either.
    expect(repo.uncertainPayments, isEmpty);
  });

  test('a failed eligibility re-check clears the previous verdict', () async {
    final repo = Repo();
    var failing = false;
    final c = LivePromotionsController(
      repository: repo,
      refreshWallet: () async => 100,
      refreshEligibility: (id) async {
        if (failing) throw const LivePromotionUnavailable();
        return eligible;
      },
    );
    await c.initialize(liveId: 'live-1');
    expect(c.state.eligibility?.canCreate, true);
    failing = true;
    await c.refresh();
    expect(c.state.eligibility, isNull);
    expect(c.state.error, isA<LivePromotionUnavailable>());
    await c.close();
  });
}
