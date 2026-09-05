import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/widgets/app_action_sheet.dart';
import '../../../domain/entities/live_interactive.dart';
import '../../bloc/live_interactive/live_interactive_bloc.dart';
import '../../bloc/live_interactive/live_interactive_event.dart';
import '../../bloc/live_interactive/live_interactive_state.dart';

/// Host status strip for whatever the room is currently running.
///
/// Starting things happens in the interactions sheet on the bottom bar; this
/// only surfaces the live poll, questions and auctions so the host can end or
/// pin them, and it stays out of the frame entirely while nothing is running.
class LiveInteractiveHostToolbar extends StatelessWidget {
  const LiveInteractiveHostToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LiveInteractiveBloc, LiveInteractiveState>(
      listenWhen: (previous, current) =>
          previous.error != current.error && current.error != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.error!)));
        context.read<LiveInteractiveBloc>().add(
          const LiveInteractiveErrorCleared(),
        );
      },
      buildWhen: (previous, current) =>
          previous.hasLiveId != current.hasLiveId ||
          previous.isLoading != current.isLoading ||
          previous.poll != current.poll ||
          previous.questions != current.questions ||
          previous.auctions != current.auctions,
      builder: (context, state) {
        final poll = state.activePoll;
        final hasActivity =
            poll != null ||
            state.questions.isNotEmpty ||
            state.auctions.isNotEmpty;
        if (!state.hasLiveId || !hasActivity) return const SizedBox.shrink();
        final busy = state.isLoading;

        return Material(
          color: Colors.black.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (poll != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Poll: ${poll.question}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => context.read<LiveInteractiveBloc>().add(
                                const LiveInteractivePollEnded(),
                              ),
                        child: const Text('End', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                if (state.questions.isNotEmpty)
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.questions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 5),
                      itemBuilder: (_, index) {
                        final question = state.questions[index];
                        return ActionChip(
                          avatar: Icon(
                            question.isAnswered
                                ? Icons.done
                                : Icons.question_answer_outlined,
                            size: 13,
                          ),
                          label: Text(
                            question.question,
                            style: const TextStyle(fontSize: 10),
                          ),
                          onPressed: busy
                              ? null
                              : () => _questionActions(context, question),
                        );
                      },
                    ),
                  ),
                if (state.auctions.isNotEmpty)
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.auctions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 5),
                      itemBuilder: (_, index) {
                        final auction = state.auctions[index];
                        return ActionChip(
                          avatar: Icon(
                            auction.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            size: 13,
                          ),
                          label: Text(
                            '${auction.itemName} · ${auction.currentPrice}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          onPressed: busy
                              ? null
                              : () => context.read<LiveInteractiveBloc>().add(
                                  LiveInteractiveAuctionPinToggled(
                                    auctionId: auction.id,
                                    pinned: !auction.isPinned,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _questionActions(BuildContext context, LiveQA question) {
    final bloc = context.read<LiveInteractiveBloc>();
    return AppActionSheet.show<void>(
      context,
      title: 'Question',
      subtitle: question.question,
      brightness: Brightness.dark,
      children: [
        AppActionTile(
          icon: Icons.push_pin_rounded,
          title: 'Pin question',
          subtitle: 'Show it to everyone watching',
          onTap: () => bloc.add(LiveInteractiveQuestionPinned(question.id)),
        ),
        AppActionTile(
          icon: Icons.done_rounded,
          title: 'Mark answered',
          subtitle: 'Move it out of the queue',
          onTap: () => bloc.add(LiveInteractiveQuestionAnswered(question.id)),
        ),
      ],
    );
  }
}
