import 'dart:convert';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/live_promotions_repository.dart';
import '../../domain/live_promotion_models.dart';

class LivePromotionsState {
  const LivePromotionsState({
    this.loading = false,
    this.loadingMore = false,
    this.mutating = false,
    this.previewLoading = false,
    this.paymentUncertain = false,
    this.cleanupPending = false,
    this.items = const [],
    this.campaign,
    this.options,
    this.packages = const [],
    this.preview,
    this.stats,
    this.balanceCoins,
    this.eligibility,
    this.error,
    this.previewError,
    this.hasMore = false,
  });
  final bool loading,
      loadingMore,
      mutating,
      previewLoading,
      paymentUncertain,
      cleanupPending,
      hasMore;
  final List<LivePromotionCampaign> items;
  final LivePromotionCampaign? campaign;
  final LivePromotionOptions? options;
  final List<LivePromotionPackage> packages;
  final LivePromotionPreview? preview;
  final LivePromotionStats? stats;
  final int? balanceCoins;
  final LivePromotionEligibility? eligibility;
  final Object? error, previewError;
  LivePromotionsState copyWith({
    bool? loading,
    bool? loadingMore,
    bool? mutating,
    bool? previewLoading,
    bool? paymentUncertain,
    bool? cleanupPending,
    bool? hasMore,
    List<LivePromotionCampaign>? items,
    LivePromotionCampaign? campaign,
    LivePromotionOptions? options,
    List<LivePromotionPackage>? packages,
    LivePromotionPreview? preview,
    LivePromotionStats? stats,
    int? balanceCoins,
    LivePromotionEligibility? eligibility,
    Object? error,
    Object? previewError,
    bool clearError = false,
    bool clearPreview = false,
    bool clearWallet = false,
    bool clearStats = false,
  }) => LivePromotionsState(
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    mutating: mutating ?? this.mutating,
    previewLoading: previewLoading ?? this.previewLoading,
    paymentUncertain: paymentUncertain ?? this.paymentUncertain,
    cleanupPending: cleanupPending ?? this.cleanupPending,
    hasMore: hasMore ?? this.hasMore,
    items: items ?? this.items,
    campaign: campaign ?? this.campaign,
    options: options ?? this.options,
    packages: packages ?? this.packages,
    preview: clearPreview ? null : preview ?? this.preview,
    stats: clearStats ? null : stats ?? this.stats,
    balanceCoins: clearWallet ? null : balanceCoins ?? this.balanceCoins,
    eligibility: eligibility ?? this.eligibility,
    error: clearError ? null : error ?? this.error,
    previewError: clearPreview ? null : previewError,
  );
}

class LivePromotionsController extends Cubit<LivePromotionsState> {
  LivePromotionsController({
    required this.repository,
    required this.refreshWallet,
    this.refreshEligibility,
  }) : super(const LivePromotionsState());
  final LivePromotionsRepository repository;
  final Future<int> Function() refreshWallet;
  final Future<LivePromotionEligibility> Function(String)? refreshEligibility;
  String? _liveId;
  int _page = 1, _previewVersion = 0;
  Timer? _previewTimer, _cleanupTimer;
  bool _background = false;
  bool get responseContractVerified => repository.responseContractVerified;
  void _set(LivePromotionsState next) {
    if (!isClosed) emit(next);
  }

  void setEligibility(LivePromotionEligibility value) =>
      _set(state.copyWith(eligibility: value));
  Future<void> _wallet() async {
    _set(state.copyWith(clearWallet: true));
    final balance = await refreshWallet();
    if (balance < 0) throw const LivePromotionUnavailable();
    _set(state.copyWith(balanceCoins: balance));
  }

  Future<void> _eligibility() async {
    if (_liveId != null && refreshEligibility != null) {
      setEligibility(await refreshEligibility!(_liveId!));
    }
  }

  Future<void> initialize({String? liveId}) async {
    _liveId = liveId;
    await refresh();
  }

  Future<void> refresh() async {
    if (state.loading || state.mutating || isClosed) return;
    _set(state.copyWith(loading: true, clearError: true));
    // Independent reads: failure of options never prevents wallet refresh.
    await Future.wait([
      _capture(() async {
        final options = await repository.getOptions();
        _set(state.copyWith(options: options));
      }),
      _capture(() async {
        final packages = await repository.getPackages();
        _set(state.copyWith(packages: packages));
      }),
      if (state.campaign == null) _capture(_wallet),
      _capture(_eligibility),
      _capture(() async {
        final id = state.campaign?.id;
        if (id != null) {
          await _reconcile();
        } else if (_liveId != null) {
          final campaign = await repository.byLive(_liveId!);
          if (campaign != null && campaign.status.isOpen) {
            await _refreshCampaign(campaign.id);
          }
        } else {
          final page = await repository.mine();
          _page = 1;
          _set(state.copyWith(items: page.items, hasMore: page.hasMore));
        }
      }),
    ]);
    _set(state.copyWith(loading: false));
  }

  Future<void> _capture(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _set(state.copyWith(error: e));
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    _set(state.copyWith(loadingMore: true, clearError: true));
    await _capture(() async {
      final page = await repository.mine(page: _page + 1);
      _page++;
      final ids = state.items.map((e) => e.id).toSet();
      _set(
        state.copyWith(
          items: [...state.items, ...page.items.where((e) => ids.add(e.id))],
          hasMore: page.hasMore,
        ),
      );
    });
    _set(state.copyWith(loadingMore: false));
  }

  void schedulePreview(LivePromotionDraft draft) {
    _previewTimer?.cancel();
    final version = ++_previewVersion;
    _set(state.copyWith(clearPreview: true, previewLoading: false));
    if (draft.packageId != null || draft.validate().isNotEmpty || _background) {
      return;
    }
    _set(state.copyWith(previewLoading: true));
    _previewTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final preview = await repository.preview(draft);
        if (!isClosed && version == _previewVersion && !_background) {
          _set(state.copyWith(preview: preview, previewLoading: false));
        }
      } catch (e) {
        if (!isClosed && version == _previewVersion && !_background) {
          _set(state.copyWith(previewError: e, previewLoading: false));
        }
      }
    });
  }

  Future<void> _refreshCampaign(String id) async {
    final campaign = await repository.getCampaign(id);
    _liveId = campaign.liveId;
    _set(
      state.copyWith(
        campaign: campaign,
        clearStats: true,
        clearPreview: true,
        paymentUncertain: repository.uncertainPayments.contains(id),
        cleanupPending: state.cleanupPending && campaign.status.isOpen,
      ),
    );
    await _capture(() async {
      final stats = await repository.stats(id);
      _set(state.copyWith(stats: stats));
    });
  }

  Future<void> openCampaign(String id) async {
    if (state.loading || state.mutating) return;
    _set(state.copyWith(loading: true, clearError: true));
    await _capture(() async {
      await _refreshCampaign(id);
      await _eligibility();
      await _reconcile();
    });
    _set(state.copyWith(loading: false));
  }

  Future<void> _locked(Future<void> Function() action) async {
    if (state.mutating || state.loading || isClosed) return;
    _set(state.copyWith(mutating: true, clearError: true));
    try {
      await action();
    } catch (e) {
      _set(state.copyWith(error: e));
      await _capture(_eligibility);
    } finally {
      _set(state.copyWith(mutating: false));
    }
  }

  Future<void> create(String liveId, LivePromotionDraft draft) =>
      _locked(() async {
        _liveId = liveId;
        draft.toJson();
        await _eligibility();
        if (state.eligibility?.canCreate != true) {
          throw const LivePromotionUnavailable();
        }
        final campaign = await repository.create(liveId, draft);
        _set(state.copyWith(campaign: campaign, clearPreview: true));
        await _capture(_wallet);
      });
  Future<void> edit(LivePromotionDraft draft) => _locked(() async {
    final campaign = state.campaign;
    if (campaign == null || !campaign.status.canEdit) {
      throw const LivePromotionUnavailable();
    }
    // The server is authoritative: a status transition in another client may
    // have made this campaign non-editable after this screen was opened.
    final latest = await repository.getCampaign(campaign.id);
    if (!latest.status.canEdit) {
      _set(state.copyWith(campaign: latest, clearPreview: true));
      throw const LivePromotionUnavailable();
    }
    await repository.edit(campaign.id, draft);
    await _refreshCampaign(campaign.id);
  });
  Future<void> pay({LivePromotionCampaign? confirmedCampaign}) =>
      _locked(() async {
        final campaign = confirmedCampaign ?? state.campaign;
        if (campaign == null ||
            !campaign.status.canPay ||
            !campaign.hasPaymentSummary ||
            state.paymentUncertain) {
          throw const LivePromotionUnavailable();
        }
        final latest = await repository.getCampaign(campaign.id);
        if (!latest.status.canPay ||
            _paymentQuote(latest) != _paymentQuote(campaign)) {
          _set(state.copyWith(campaign: latest, clearPreview: true));
          throw const LivePromotionUnavailable();
        }
        await _wallet();
        if (state.balanceCoins! < campaign.budgetCoins!) {
          throw const LivePromotionInsufficientBalance();
        }
        try {
          await repository.pay(campaign.id);
        } finally {
          _set(
            state.copyWith(
              paymentUncertain: repository.uncertainPayments.contains(
                campaign.id,
              ),
            ),
          );
          await _capture(_reconcile);
        }
      });
  String _paymentQuote(LivePromotionCampaign c) => jsonEncode([
    c.id,
    c.liveId,
    c.budgetCoins,
    c.durationDays,
    c.objective?.wireValue,
    c.automaticAudience,
    c.draft?.toJson(),
  ]);

  Future<void> _reconcile() async {
    final id = state.campaign?.id;
    if (id == null) {
      await _wallet();
      return;
    }
    await Future.wait([_refreshCampaign(id), _wallet()]);
    // An open PENDING_PAYMENT after timeout is not proof that the POST cannot
    // still settle. Keep locked; never automatically replay a financial request.
    if (state.campaign!.status != LivePromotionStatus.pendingPayment &&
        state.campaign!.status != LivePromotionStatus.unknown) {
      await repository.confirmPaymentReconciled(id);
      _set(state.copyWith(paymentUncertain: false));
    }
  }

  Future<void> pause() => _action('pause');
  Future<void> resume() => _action('resume');
  Future<void> cancel() => _action('cancel');
  Future<void> _action(String action) => _locked(() async {
    final c = state.campaign;
    final allowed =
        c != null &&
        switch (action) {
          'pause' => c.status.canPause,
          'resume' => c.status.canResume,
          'cancel' => c.status.canCancel,
          _ => false,
        };
    if (!allowed) throw const LivePromotionUnavailable();
    await repository.action(c.id, action);
    await _refreshCampaign(c.id);
    if (action == 'cancel') await _wallet();
  });
  void onLiveEnded() {
    _set(state.copyWith(cleanupPending: true));
    _pollCleanup(0);
  }

  void _pollCleanup(int attempt) {
    _cleanupTimer?.cancel();
    if (_background || isClosed || attempt >= 4) return;
    _cleanupTimer = Timer(Duration(seconds: attempt == 0 ? 0 : 3), () async {
      if (state.loading || state.mutating) {
        _pollCleanup(attempt + 1);
        return;
      }
      await _capture(_reconcile);
      if (state.cleanupPending) _pollCleanup(attempt + 1);
    });
  }

  void onForeground() {
    _background = false;
    unawaited(refresh());
  }

  void onBackground() {
    _background = true;
    _cleanupTimer?.cancel();
    _previewTimer?.cancel();
    _previewVersion++;
  }

  @override
  Future<void> close() {
    onBackground();
    return super.close();
  }
}
