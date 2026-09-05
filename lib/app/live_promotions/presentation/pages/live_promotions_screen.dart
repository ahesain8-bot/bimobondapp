import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:bimobondapp/core/services/live_feed_refresh_bus.dart';
import '../../domain/live_promotion_models.dart';
import '../controllers/live_promotions_controller.dart';
import '../di/live_promotions_injector.dart';
import '../widgets/live_promotion_form.dart';

class LivePromotionsScreen extends StatefulWidget {
  const LivePromotionsScreen({
    super.key,
    this.liveId,
    this.campaignId,
    this.preLive = false,
    this.controller,
  });
  final String? liveId, campaignId;
  final bool preLive;
  final LivePromotionsController? controller;

  /// A modal owns its own route. Opening/closing it leaves the host's room
  /// mounted and never dispatches a room-end/leave event.
  static Future<void> show(
    BuildContext context, {
    String? liveId,
    bool preLive = false,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: LivePromotionsScreen(liveId: liveId, preLive: preLive),
    ),
  );
  @override
  State<LivePromotionsScreen> createState() => _LivePromotionsScreenState();
}

class _LivePromotionsScreenState extends State<LivePromotionsScreen>
    with WidgetsBindingObserver {
  late final LivePromotionsController _controller;
  bool _editing = false;
  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? createLivePromotionsController();
    WidgetsBinding.instance.addObserver(this);
    LiveFeedRefreshBus.instance.addListener(_ended);
    if (!widget.preLive) {
      if (widget.campaignId != null) {
        unawaited(_controller.openCampaign(widget.campaignId!));
      } else {
        unawaited(_controller.initialize(liveId: widget.liveId));
      }
    }
  }

  void _ended() {
    final id = LiveFeedRefreshBus.instance.lastEndedLiveId;
    if (id != null &&
        id == (_controller.state.campaign?.liveId ?? widget.liveId)) {
      _controller.onLiveEnded();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.preLive) return;
    if (state == AppLifecycleState.resumed) {
      _controller.onForeground();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _controller.onBackground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LiveFeedRefreshBus.instance.removeListener(_ended);
    if (widget.controller == null) unawaited(_controller.close());
    super.dispose();
  }

  String _status(LivePromotionStatus s, AppLocalizations l) => switch (s) {
    LivePromotionStatus.pendingPayment => l.lpPending,
    LivePromotionStatus.active => l.lpActive,
    LivePromotionStatus.paused => l.lpPaused,
    LivePromotionStatus.completed => l.lpCompleted,
    LivePromotionStatus.cancelled => l.lpCancelled,
    LivePromotionStatus.unknown => l.lpUnknownStatus,
  };
  String _number(num? value) => value == null
      ? AppLocalizations.of(context)!.lpUnknown
      : NumberFormat.decimalPattern(
          Localizations.localeOf(context).toString(),
        ).format(value);
  Widget _value(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
  String _objective(LivePromotionObjective? o, AppLocalizations l) => o == null
      ? l.lpUnknown
      : o == LivePromotionObjective.views
      ? l.lpViews
      : l.lpFollowers;
  List<Widget> _summary(
    LivePromotionCampaign c,
    LivePromotionsState s,
    AppLocalizations l,
  ) => [
    _value(l.lpCost, '${_number(c.budgetCoins)} ${l.lpCoins}'),
    _value(l.lpBalance, '${_number(s.balanceCoins)} ${l.lpCoins}'),
    _value(l.lpObjective, _objective(c.objective, l)),
    _value(
      l.lpAudience,
      c.automaticAudience == null
          ? l.lpUnknown
          : c.automaticAudience!
          ? l.lpAutomatic
          : l.lpCustomAudience,
    ),
    if (c.automaticAudience == false && c.draft != null) ...[
      if (c.draft!.targetGenders.isNotEmpty)
        _value(l.lpGenders, c.draft!.targetGenders.join(', ')),
      if (c.draft!.targetCountryCodes.isNotEmpty)
        _value(l.lpCountries, c.draft!.targetCountryCodes.join(', ')),
      if (c.draft!.targetLanguages.isNotEmpty)
        _value(l.lpLanguages, c.draft!.targetLanguages.join(', ')),
      if (c.draft!.targetCategoryIds.isNotEmpty)
        _value(
          l.lpCategories,
          c.draft!.targetCategoryIds
              .map(
                (id) =>
                    s.options?.categories
                        .where((o) => o.value == id)
                        .firstOrNull
                        ?.label ??
                    l.lpUnknown,
              )
              .join(', '),
        ),
      if (c.draft!.targetAgeMin != null)
        _value(l.lpAgeMin, _number(c.draft!.targetAgeMin)),
      if (c.draft!.targetAgeMax != null)
        _value(l.lpAgeMax, _number(c.draft!.targetAgeMax)),
      if (c.draft!.targetLatitude != null) ...[
        _value(l.lpLatitude, _number(c.draft!.targetLatitude)),
        _value(l.lpLongitude, _number(c.draft!.targetLongitude)),
        _value(l.lpRadius, _number(c.draft!.targetRadiusKm)),
      ],
    ],
    _value(l.lpDuration, _number(c.durationDays)),
    if (s.preview?.estimatedViewers != null)
      _value(l.lpViews, _number(s.preview!.estimatedViewers)),
    if (s.preview?.estimatedFollowers != null)
      _value(l.lpFollowers, _number(s.preview!.estimatedFollowers)),
    if (s.preview != null) Text(l.lpEstimateHint),
  ];
  Future<void> _confirmPay() async {
    await _controller.refresh();
    if (!mounted) return;
    final s = _controller.state,
        c = s.campaign,
        l = AppLocalizations.of(context)!;
    if (c == null ||
        !c.hasPaymentSummary ||
        s.balanceCoins == null ||
        s.paymentUncertain) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.lpPay),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _summary(c, s, l),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.lpBack),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.lpConfirmPay),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _controller.pay(confirmedCampaign: c);
    }
  }

  Future<void> _cancel() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.lpCancel),
        content: Text(l.lpCancelHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.lpBack),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.lpCancel),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _controller.cancel();
  }

  Future<void> _topUp() async {
    await context.pushNamed('wallet');
    if (mounted) await _controller.refresh();
  }

  Widget _details(LivePromotionsState s, AppLocalizations l) {
    final c = s.campaign!;
    final busy = s.mutating || s.loading;
    if (_editing && c.status.canEdit && c.draft != null) {
      return Column(
        children: [
          TextButton(
            onPressed: () => setState(() => _editing = false),
            child: Text(l.lpBack),
          ),
          LivePromotionForm(
            controller: _controller,
            state: s,
            liveId: c.liveId,
            initial: c.draft,
            editing: true,
            onSaved: () => setState(() => _editing = false),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _status(c.status, l),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        ..._summary(c, s, l),
        const Divider(),
        _value(l.lpImpressions, _number(s.stats?.impressions)),
        _value(l.lpSpend, _number(s.stats?.spendCoins)),
        _value(l.lpRemaining, _number(s.stats?.remainingCoins)),
        if (s.paymentUncertain) Text(l.lpPaymentUnknown),
        if (s.cleanupPending) Text(l.lpCleanup),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (c.status.canPay)
              FilledButton(
                onPressed:
                    busy ||
                        s.paymentUncertain ||
                        !c.hasPaymentSummary ||
                        !_controller.responseContractVerified
                    ? null
                    : _confirmPay,
                child: Text(l.lpPay),
              ),
            if (c.status.canEdit)
              OutlinedButton(
                onPressed: busy || c.draft == null
                    ? null
                    : () => setState(() => _editing = true),
                child: Text(l.lpEdit),
              ),
            if (c.status.canPause)
              OutlinedButton(
                onPressed: busy ? null : _controller.pause,
                child: Text(l.lpPause),
              ),
            if (c.status.canResume)
              OutlinedButton(
                onPressed: busy ? null : _controller.resume,
                child: Text(l.lpResume),
              ),
            if (c.status.canCancel)
              OutlinedButton(
                onPressed: busy ? null : _cancel,
                child: Text(l.lpCancel),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BlocBuilder<LivePromotionsController, LivePromotionsState>(
      bloc: _controller,
      builder: (context, s) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.liveId != null || widget.preLive ? l.lpTitle : l.lpMine,
          ),
          leading: IconButton(
            tooltip: l.lpClose,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (!widget.preLive)
              IconButton(
                tooltip: l.lpRefresh,
                onPressed: s.loading || s.mutating ? null : _controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (s.loading || s.mutating) const LinearProgressIndicator(),
                if (widget.preLive) ...[
                  const Icon(Icons.live_tv, size: 56),
                  const SizedBox(height: 16),
                  Text(livePromotionsEnabled ? l.lpPreLive : l.lpDisabled),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LivePromotionsScreen(),
                      ),
                    ),
                    child: Text(l.lpMine),
                  ),
                ] else ...[
                  if (s.error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              s.error is LivePromotionInsufficientBalance
                                  ? l.lpInsufficient
                                  : l.lpUnavailable,
                            ),
                            if (s.error is LivePromotionInsufficientBalance)
                              TextButton(
                                onPressed: _topUp,
                                child: Text(l.lpTopUp),
                              ),
                            TextButton(
                              onPressed: s.loading || s.mutating
                                  ? null
                                  : _controller.refresh,
                              child: Text(l.lpRetry),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (s.campaign != null)
                    _details(s, l)
                  else if (widget.liveId != null)
                    LivePromotionForm(
                      controller: _controller,
                      state: s,
                      liveId: widget.liveId!,
                    )
                  else if (!s.loading &&
                      s.error == null &&
                      s.items.isEmpty) ...[
                    Text(l.lpEmpty),
                    const SizedBox(height: 8),
                    Text(l.lpEmptyHint),
                  ] else ...[
                    for (final c in s.items)
                      Card(
                        child: ListTile(
                          title: Text(_objective(c.objective, l)),
                          subtitle: Text(_status(c.status, l)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  LivePromotionsScreen(campaignId: c.id),
                            ),
                          ),
                        ),
                      ),
                    if (s.hasMore)
                      TextButton(
                        onPressed: s.loadingMore ? null : _controller.loadMore,
                        child: Text(l.lpLoadMore),
                      ),
                  ],
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
