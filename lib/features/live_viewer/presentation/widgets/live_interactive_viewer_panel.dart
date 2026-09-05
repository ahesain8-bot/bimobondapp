import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../live/domain/entities/live_interactive.dart';
import '../../../live/presentation/bloc/live_interactive/live_interactive_bloc.dart';
import '../../../live/presentation/bloc/live_interactive/live_interactive_event.dart';
import '../../../live/presentation/bloc/live_interactive/live_interactive_state.dart';

/// Viewer surface for server-backed polls, Q&A and treasure boxes. It stays
/// hidden until the active live has data, so ordinary rooms keep their current
/// layout.
class LiveInteractiveViewerPanel extends StatelessWidget {
  const LiveInteractiveViewerPanel({
    super.key,
    required this.liveId,
    required this.isHost,
  });

  final String liveId;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    return BlocListener<LiveInteractiveBloc, LiveInteractiveState>(
      listenWhen: (previous, current) =>
          previous.lastUserLevelUp != current.lastUserLevelUp,
      listener: (context, state) {
        final levelUp = state.lastUserLevelUp;
        if (levelUp == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Level up: Lv. ${levelUp.newLevel}')),
          );
      },
      child: BlocConsumer<LiveInteractiveBloc, LiveInteractiveState>(
      listenWhen: (previous, current) =>
          previous.lastTreasureClaim != current.lastTreasureClaim,
      listener: (context, state) {
        final claim = state.lastTreasureClaim;
        if (claim == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('You won ${claim.coinsWon} coins')),
          );
      },
      buildWhen: (previous, current) =>
          previous.giftGoal != current.giftGoal ||
          previous.hostLeague != current.hostLeague ||
          previous.lastUserLevelUp != current.lastUserLevelUp ||
          previous.poll != current.poll ||
          previous.questions != current.questions ||
          previous.treasureBoxes != current.treasureBoxes ||
          previous.auctions != current.auctions,
      builder: (context, state) {
        final poll = state.poll;
        final boxes = state.treasureBoxes
            .where((box) {
              final status = box.status.toUpperCase();
              return status != 'ENDED' && status != 'EXPIRED';
            })
            .toList(growable: false);
        final questions = state.questions.take(2).toList(growable: false);
        final pinnedQuestions = state.questions.where((question) => question.isPinned);
        final pinnedQuestion = pinnedQuestions.isEmpty ? null : pinnedQuestions.first;
        final auctions = state.auctions
            .where((auction) => auction.status.toUpperCase() == 'ACTIVE')
            .toList(growable: false);
        if (state.giftGoal == null &&
            state.hostLeague == null &&
            state.lastUserLevelUp == null &&
            poll == null &&
            boxes.isEmpty &&
            questions.isEmpty &&
            auctions.isEmpty &&
            isHost) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.giftGoal != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${state.giftGoal!.title ?? 'Gift goal'} · ${state.giftGoal!.current}/${state.giftGoal!.target} Coins',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (state.giftGoal!.isReached)
                        const _ConfettiBurst(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: state.giftGoal!.progress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.amber),
                    ),
                  ),
                ],
                if (state.hostLeague != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Host league ${state.hostLeague!.hostLeagueTier} · ${state.hostLeague!.progressPercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w600),
                  ),
                ],
                if (state.lastUserLevelUp != null) ...[
                  const SizedBox(height: 6),
                  _LevelUpBanner(levelUp: state.lastUserLevelUp!),
                ],
                if (poll != null && poll.status.toUpperCase() == 'ACTIVE')
                  _PollCard(poll: poll),
                if (questions.isNotEmpty || !isHost) ...[
                  const SizedBox(height: 6),
                  if (pinnedQuestion != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.55)),
                      ),
                      child: Text(
                        'Pinned: ${pinnedQuestion.question}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (pinnedQuestion != null) const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.question_answer_outlined, color: Colors.white70, size: 15),
                      const SizedBox(width: 5),
                      const Text('Q&A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _askQuestion(context),
                        child: const Text('Ask'),
                      ),
                    ],
                  ),
                  ...questions.map(
                    (qa) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        qa.question,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: qa.isAnswered
                          ? const Text('Answered', style: TextStyle(color: Colors.greenAccent))
                          : null,
                      trailing: isHost
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.push_pin_outlined, color: Colors.white70, size: 18),
                                  onPressed: () => context.read<LiveInteractiveBloc>().add(
                                    LiveInteractiveQuestionPinned(qa.id),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.done, color: Colors.white70, size: 18),
                                  onPressed: () => context.read<LiveInteractiveBloc>().add(
                                    LiveInteractiveQuestionAnswered(qa.id),
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                ],
                if (boxes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...boxes.map(
                    (box) => _TreasureBoxTile(
                      box: box,
                      onClaim: () => context.read<LiveInteractiveBloc>().add(
                        LiveInteractiveTreasureBoxClaimed(box.id),
                      ),
                    ),
                  ),
                ],
                if (auctions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.storefront_outlined, color: Colors.white70, size: 15),
                      SizedBox(width: 5),
                      Text('Live showcase', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  ...auctions.map(
                    (auction) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(auction.itemName, style: const TextStyle(color: Colors.white)),
                      trailing: Text('${auction.currentPrice} coins', style: const TextStyle(color: Colors.amberAccent)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  Future<void> _askQuestion(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ask a question'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'Your question'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (result != true || !context.mounted || controller.text.trim().isEmpty) {
      return;
    }
    context.read<LiveInteractiveBloc>().add(
      LiveInteractiveQuestionCreated(controller.text.trim()),
    );
  }
}

class _LevelUpBanner extends StatelessWidget {
  const _LevelUpBanner({required this.levelUp});

  final LiveUserLevelUp levelUp;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey(levelUp.newLevel),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.55)),
        ),
        child: Text(
          '🎉 Gifter level ${levelUp.newLevel} · ${levelUp.progressPercentage.toStringAsFixed(0)}% XP',
          style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll});

  final LivePoll poll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          poll.question,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        for (var index = 0; index < poll.options.length; index++)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: (poll.options[index].percentage / 100)
                    .clamp(0.0, 1.0)
                    .toDouble(),
              ),
              duration: const Duration(milliseconds: 350),
              builder: (context, progress, child) => OutlinedButton(
                onPressed: () => context.read<LiveInteractiveBloc>().add(
                      LiveInteractivePollVoted(index),
                    ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(
                    color: poll.options[index].percentage >=
                            poll.options.map((option) => option.percentage).reduce(math.max)
                        ? Colors.amberAccent
                        : Colors.white38,
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
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                              '${poll.options[index].text}  ${poll.options[index].percentage.toStringAsFixed(0)}%',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

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
        oldWidget.box.delaySeconds != widget.box.delaySeconds ||
        oldWidget.box.unlocksAt != widget.box.unlocksAt) {
      _refresh();
    }
  }

  void _refresh() {
    final createdAt = widget.box.createdAt;
    final unlocksAt = widget.box.unlocksAt;
    final delay = widget.box.delaySeconds;
    final remaining = unlocksAt != null
        ? unlocksAt.difference(DateTime.now()).inSeconds.clamp(0, 1 << 31).toInt()
        : createdAt == null
            ? 0
            : (delay - DateTime.now().difference(createdAt).inSeconds)
                  .clamp(0, delay)
                  .toInt();
    if (mounted && remaining != _remaining) setState(() => _remaining = remaining);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exhausted = widget.box.claimedCount >= widget.box.maxClaims ||
        widget.box.remainingCoins <= 0;
    final waiting = _remaining > 0 && widget.box.status.toUpperCase() == 'WAITING';
    return OutlinedButton.icon(
      onPressed: exhausted || waiting ? null : widget.onClaim,
      icon: const Icon(Icons.card_giftcard, size: 16),
      label: Text(
        waiting
            ? 'Treasure chest in ${_remaining}s'
            : 'Treasure box · ${widget.box.claimedCount}/${widget.box.maxClaims}',
      ),
    );
  }
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst();

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 26,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _ConfettiPainter(_controller.value),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [Colors.amber, Colors.pinkAccent, Colors.lightBlueAccent, Colors.greenAccent];
    for (var i = 0; i < 10; i++) {
      final x = (i * 17.0 + progress * 8) % size.width;
      final y = (i * 7.0 + progress * 18) % size.height;
      final paint = Paint()..color = colors[i % colors.length];
      canvas.drawRect(Rect.fromLTWH(x, y, 4, 7), paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
