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
    return BlocProvider(
      create: (_) => LiveSummaryBloc(repository: repository)
        ..add(LiveSummaryRequested(liveId)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Live summary')),
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
              return const Center(child: Text('No summary available.'));
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
                  label: 'Duration',
                  value: '${summary.durationSeconds}s',
                ),
                _Metric(label: 'Peak viewers', value: '${summary.peakViewers}'),
                _Metric(
                  label: 'Viewer sessions',
                  value: '${summary.totalViewerSessions}',
                ),
                _Metric(label: 'Likes', value: '${summary.totalLikes}'),
                _Metric(label: 'Comments', value: '${summary.totalComments}'),
                _Metric(
                  label: 'Earned coins',
                  value: '${summary.totalEarnedCoins}',
                ),
                const SizedBox(height: 18),
                Text(
                  'Top gifters',
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
