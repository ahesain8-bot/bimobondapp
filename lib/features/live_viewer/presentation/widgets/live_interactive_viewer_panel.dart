import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../live/domain/entities/live_interactive.dart';
import '../../../live/presentation/bloc/live_interactive/live_interactive_bloc.dart';
import '../../../live/presentation/bloc/live_interactive/live_interactive_event.dart';
import '../../../live/presentation/bloc/live_interactive/live_interactive_state.dart';
import '../../../live/presentation/widgets/room/live_interactive_tools.dart';

/// Viewer entry point to the room's interactions, opened from the bottom bar.
///
/// Only the actions a viewer can actually take are live rows; the host-driven
/// ones carry their current state and hand over to
/// [LiveInteractiveViewerPanel] rather than repeating it in a menu.
abstract final class LiveInteractiveViewerToolsSheet {
  LiveInteractiveViewerToolsSheet._();

  /// [bloc] is passed in because the room provides it below the state that
  /// owns it, so the calling context cannot look it up.
  static Future<void> show(
    BuildContext context, {
    required LiveInteractiveBloc bloc,
    required VoidCallback onSendGift,
    required VoidCallback onShowActivity,
  }) {
    final state = bloc.state;
    final poll = state.activePoll;
    final boxes = state.openTreasureBoxes;
    final auctions = state.activeAuctions;

    return AppActionSheet.show<void>(
      context,
      title: LiveInteractiveTools.label,
      subtitle: 'Join in without leaving the stream',
      brightness: Brightness.dark,
      children: [
        AppActionTile(
          icon: Icons.card_giftcard_rounded,
          title: 'Send a gift',
          subtitle: 'Back the host with coins',
          featured: true,
          onTap: onSendGift,
        ),
        AppActionTile(
          icon: Icons.help_outline_rounded,
          title: 'Ask a question',
          subtitle: 'Goes straight to the host Q&A',
          onTap: () => _askQuestion(context, bloc),
        ),
        AppActionTile(
          icon: Icons.bar_chart_rounded,
          title: 'Poll',
          subtitle: poll?.question ?? 'No poll running right now',
          enabled: poll != null,
          onTap: onShowActivity,
        ),
        AppActionTile(
          icon: Icons.inventory_2_rounded,
          title: 'Treasure box',
          subtitle: boxes.isEmpty
              ? 'Nothing to claim yet'
              : '${boxes.length} open — tap to claim',
          enabled: boxes.isNotEmpty,
          onTap: onShowActivity,
        ),
        AppActionTile(
          icon: Icons.storefront_rounded,
          title: 'Live showcase',
          subtitle: auctions.isEmpty
              ? 'The host is not showcasing anything'
              : '${auctions.length} up for bids',
          enabled: auctions.isNotEmpty,
          onTap: onShowActivity,
        ),
      ],
    );
  }
}

Future<void> _askQuestion(
  BuildContext context,
  LiveInteractiveBloc bloc,
) async {
  final question = await showDialog<String>(
    context: context,
    builder: (_) => const _AskQuestionDialog(),
  );
  if (question == null || question.isEmpty) return;
  bloc.add(LiveInteractiveQuestionCreated(question));
}

/// Viewer surface for the host's polls, Q&A, treasure boxes and showcase.
/// Viewers can always ask a question; the rest appears only once the host has
/// started something, so ordinary rooms keep their current layout.
class LiveInteractiveViewerPanel extends StatelessWidget {
  const LiveInteractiveViewerPanel({super.key, this.onClose});

  /// Dismisses the panel. The interactions sheet on the bottom bar is what
  /// brings it back.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LiveInteractiveBloc, LiveInteractiveState>(
      listenWhen: (previous, current) =>
          (previous.lastClaim != current.lastClaim &&
              current.lastClaim != null) ||
          (previous.error != current.error && current.error != null),
      listener: (context, state) {
        final bloc = context.read<LiveInteractiveBloc>();
        final claim = state.lastClaim;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                claim != null ? 'You won ${claim.coinsWon} coins' : state.error!,
              ),
            ),
          );
        bloc.add(
          claim != null
              ? const LiveInteractiveClaimShown()
              : const LiveInteractiveErrorCleared(),
        );
      },
      buildWhen: (previous, current) =>
          previous.poll != current.poll ||
          previous.questions != current.questions ||
          previous.treasureBoxes != current.treasureBoxes ||
          previous.auctions != current.auctions,
      builder: (context, state) {
        final poll = state.activePoll;
        final boxes = state.openTreasureBoxes;
        final auctions = state.activeAuctions;
        final pinned = state.pinnedQuestion;
        final questions = state.questions.take(2).toList(growable: false);

        return Material(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onClose != null) _PanelHeader(onClose: onClose!),
                if (poll != null) _PollCard(poll: poll),
                if (pinned != null) ...[
                  const SizedBox(height: 6),
                  _PinnedQuestion(question: pinned),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.question_answer_outlined,
                      color: Colors.white70,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Q&A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _askQuestion(
                        context,
                        context.read<LiveInteractiveBloc>(),
                      ),
                      child: const Text('Ask'),
                    ),
                  ],
                ),
                for (final question in questions)
                  _QuestionTile(question: question),
                if (boxes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final box in boxes)
                    _TreasureBoxTile(
                      box: box,
                      onClaim: () => context.read<LiveInteractiveBloc>().add(
                        LiveInteractiveTreasureBoxClaimed(box.id),
                      ),
                    ),
                ],
                if (auctions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        color: Colors.white70,
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Live showcase',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  for (final auction in auctions)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        auction.itemName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Text(
                        '${auction.currentPrice} coins',
                        style: const TextStyle(color: Colors.amberAccent),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Names the panel and gives it a way out, now that the bottom bar owns the
/// way in.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(LiveInteractiveTools.icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Live activity',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, color: Colors.white70, size: 16),
          ),
        ),
      ],
    );
  }
}

class _AskQuestionDialog extends StatefulWidget {
  const _AskQuestionDialog();

  @override
  State<_AskQuestionDialog> createState() => _AskQuestionDialogState();
}

class _AskQuestionDialogState extends State<_AskQuestionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Ask a question',
      // Opened over the stream, so it stays dark whatever the app theme is.
      brightness: Brightness.dark,
      primaryLabel: 'Send',
      onPrimary: () => Navigator.pop(context, _controller.text.trim()),
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.pop(context),
      children: [
        AppFormField(
          controller: _controller,
          hintText: 'Your question',
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          bottomGap: 0,
        ),
      ],
    );
  }
}

class _PinnedQuestion extends StatelessWidget {
  const _PinnedQuestion({required this.question});

  final LiveQA question;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.55)),
      ),
      child: Text(
        'Pinned: ${question.question}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.amberAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.question});

  final LiveQA question;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        question.question,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: question.isAnswered
          ? const Text('Answered', style: TextStyle(color: Colors.greenAccent))
          : null,
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll});

  final LivePoll poll;

  @override
  Widget build(BuildContext context) {
    final leading = poll.options.isEmpty
        ? 0.0
        : poll.options
              .map((option) => option.percentage)
              .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          poll.question,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        for (var index = 0; index < poll.options.length; index++)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _PollOptionBar(
              option: poll.options[index],
              isLeading: poll.options[index].percentage >= leading,
              onVote: () => context.read<LiveInteractiveBloc>().add(
                LiveInteractivePollVoted(index),
              ),
            ),
          ),
      ],
    );
  }
}

class _PollOptionBar extends StatelessWidget {
  const _PollOptionBar({
    required this.option,
    required this.isLeading,
    required this.onVote,
  });

  final LivePollOption option;
  final bool isLeading;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 0,
        end: (option.percentage / 100).clamp(0.0, 1.0).toDouble(),
      ),
      duration: const Duration(milliseconds: 350),
      builder: (context, progress, _) => OutlinedButton(
        onPressed: onVote,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(
            color: isLeading ? Colors.amberAccent : Colors.white38,
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 40,
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 40,
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.42),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${option.text}  ${option.percentage.toStringAsFixed(0)}%',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the countdown while the box is still locked, then becomes claimable.
class _TreasureBoxTile extends StatefulWidget {
  const _TreasureBoxTile({required this.box, required this.onClaim});

  final LiveTreasureBox box;
  final VoidCallback onClaim;

  @override
  State<_TreasureBoxTile> createState() => _TreasureBoxTileState();
}

class _TreasureBoxTileState extends State<_TreasureBoxTile> {
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant _TreasureBoxTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.box.createdAt != widget.box.createdAt ||
        oldWidget.box.unlocksAt != widget.box.unlocksAt ||
        oldWidget.box.delaySeconds != widget.box.delaySeconds) {
      _refresh();
    }
  }

  void _refresh() {
    final remaining = widget.box.secondsUntilUnlock(DateTime.now());
    if (remaining == _remaining) return;
    if (remaining == 0) _timer?.cancel();
    if (mounted) setState(() => _remaining = remaining);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = _remaining > 0;
    return OutlinedButton.icon(
      onPressed: locked || widget.box.isExhausted ? null : widget.onClaim,
      icon: const Icon(Icons.card_giftcard, size: 16),
      label: Text(
        locked
            ? 'Treasure box in ${_remaining}s'
            : 'Treasure box · ${widget.box.claimedCount}/${widget.box.maxClaims}',
      ),
    );
  }
}
