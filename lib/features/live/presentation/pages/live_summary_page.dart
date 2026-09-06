import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/live_interactive_repository.dart';
import '../bloc/live_summary/live_summary_bloc.dart';

/// Recap shown to the host once their live has ended.
class LiveSummaryPage extends StatelessWidget {
  const LiveSummaryPage({
    super.key,
    required this.liveId,
    required this.repository,
  });

  final String liveId;
  final LiveInteractiveRepository repository;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String value(num? number) => number?.toString() ?? l.liveMetricUnavailable;
    return BlocProvider(
      create: (_) =>
          LiveSummaryBloc(repository: repository)
            ..add(LiveSummaryRequested(liveId)),
      child: Scaffold(
        appBar: AppBar(title: Text(l.liveSummaryTitle)),
        body: BlocBuilder<LiveSummaryBloc, LiveSummaryState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(state.error!, textAlign: TextAlign.center),
                ),
              );
            }
            final summary = state.summary;
            if (summary == null) {
              return Center(child: Text(l.liveSummaryEmpty));
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  summary.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                _Metric(
                  label: l.liveSummaryDuration,
                  value: '${summary.durationSeconds}s',
                ),
                _Metric(
                  label: l.liveSummaryPeak,
                  value: '${summary.peakViewers}',
                ),
                _Metric(
                  label: l.liveSummarySessions,
                  value: '${summary.totalViewerSessions}',
                ),
                _Metric(
                  label: l.liveSummaryLikes,
                  value: '${summary.totalLikes}',
                ),
                _Metric(
                  label: l.liveSummaryComments,
                  value: '${summary.totalComments}',
                ),
                _Metric(
                  label: l.liveSummaryCoins,
                  value: '${summary.totalEarnedCoins}',
                ),
                _Metric(
                  label: l.liveSummaryUnique,
                  value: value(summary.uniqueViewers),
                ),
                _Metric(
                  label: l.liveSummaryWatch,
                  value: value(summary.totalWatchSeconds),
                ),
                _Metric(
                  label: l.liveSummaryAverage,
                  value: value(summary.avgWatchSeconds),
                ),
                _Metric(
                  label: l.liveSummaryFollowers,
                  value: value(summary.newFollowers),
                ),
                _Metric(
                  label: l.liveSummaryShares,
                  value: value(summary.shareCount),
                ),
                _Metric(
                  label: l.liveSummaryOrders,
                  value: value(summary.shopOrders),
                ),
                _Metric(
                  label: l.liveSummaryRevenue,
                  value: value(summary.shopRevenueCoins),
                ),
                const SizedBox(height: 18),
                Text(
                  l.liveSummaryTraffic,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (summary.trafficSourceBreakdown == null)
                  Text(l.liveMetricUnavailable)
                else
                  for (final entry in summary.trafficSourceBreakdown!.entries)
                    _Metric(label: entry.key, value: '${entry.value}'),
                const SizedBox(height: 18),
                Text(
                  l.liveSummaryGifters,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final gifter in summary.topGifters)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(gifter.displayName),
                    trailing: Text('${gifter.totalCoins}'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
