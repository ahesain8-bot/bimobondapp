import 'package:flutter/material.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import '../../../domain/entities/live_host_league.dart';

/// Reads on open, explicit refresh and foreground restoration. No guessed
/// rank, next-tier threshold, promotion calculation or unscoped socket patch.
class LiveHostLeagueSheet extends StatefulWidget {
  const LiveHostLeagueSheet({super.key, required this.loadLeague, required this.loadTiers});
  final Future<LiveHostLeague?> Function() loadLeague;
  final Future<List<LiveLeagueTier>> Function() loadTiers;

  static Future<void> show(BuildContext context, {
    required Future<LiveHostLeague?> Function() loadLeague,
    required Future<List<LiveLeagueTier>> Function() loadTiers,
  }) => showModalBottomSheet<void>(context: context, isScrollControlled: true,
    builder: (_) => SizedBox(height: MediaQuery.sizeOf(context).height * .7,
      child: LiveHostLeagueSheet(loadLeague: loadLeague, loadTiers: loadTiers)));

  @override
  State<LiveHostLeagueSheet> createState() => _LiveHostLeagueSheetState();
}

class _LiveHostLeagueSheetState extends State<LiveHostLeagueSheet> with WidgetsBindingObserver {
  LiveHostLeague? _league;
  List<LiveLeagueTier> _tiers = const [];
  bool _loading = true;
  String? _error;
  int _generation = 0;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _load(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) _load();
  }
  @override
  void dispose() { _generation++; WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  Future<void> _load() async {
    final generation = ++_generation;
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait<Object?>([widget.loadLeague(), widget.loadTiers()]);
      if (!mounted || generation != _generation) return;
      setState(() { _league = values[0] as LiveHostLeague?; _tiers = values[1] as List<LiveLeagueTier>; });
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error.toString());
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final league = _league;
    String value(Object? v) => v?.toString() ?? l.liveMetricUnavailable;
    return SafeArea(child: Column(children: [
      ListTile(title: Text(l.liveLeagueTitle), trailing: IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) :
        _error != null ? Center(child: Text(_error!, textAlign: TextAlign.center)) :
        ListView(padding: const EdgeInsets.all(20), children: [
          Text(value(league?.tier), style: Theme.of(context).textTheme.headlineMedium),
          ListTile(title: Text(l.liveLeagueProgress), subtitle: Text(value(league?.nextTier)),
            trailing: Text(league?.progressPercentage == null ? l.liveMetricUnavailable : '${league!.progressPercentage}%')),
          if (league?.progressPercentage != null) LinearProgressIndicator(value: (league!.progressPercentage! / 100).clamp(0.0, 1.0)),
          ListTile(title: Text(l.liveSummaryCoins), trailing: Text(value(league?.totalLiveEarnedCoins))),
          ListTile(title: Text(l.followers), trailing: Text(value(league?.followerCount))),
          for (final tier in _tiers) ListTile(title: Text(tier.tier),
            subtitle: Text('${value(tier.minCoins)} ${l.coinsUnit} · ${value(tier.minFollowers)} ${l.followers}')),
        ])),
    ]));
  }
}
