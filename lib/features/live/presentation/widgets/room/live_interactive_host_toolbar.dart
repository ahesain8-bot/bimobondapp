import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/live_interactive/live_interactive_bloc.dart';
import '../../bloc/live_interactive/live_interactive_event.dart';
import '../../bloc/live_interactive/live_interactive_state.dart';
import '../../../domain/entities/live_interactive.dart';

/// Small control used to show or hide the existing live-interaction panel.
/// The panel itself remains responsible for all host/viewer actions.
class LiveInteractiveToggleButton extends StatelessWidget {
  const LiveInteractiveToggleButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Toggle live features',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.widgets_outlined,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// Small host-only command surface for M6–M10. It deliberately exposes the
/// server-backed actions as commands; all loading/error handling remains in
/// [LiveInteractiveBloc].
class LiveInteractiveHostToolbar extends StatelessWidget {
  const LiveInteractiveHostToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<LiveInteractiveBloc, LiveInteractiveState>(
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
      child: BlocBuilder<LiveInteractiveBloc, LiveInteractiveState>(
        buildWhen: (previous, current) =>
            previous.isLoading != current.isLoading ||
            previous.giftGoal != current.giftGoal ||
            previous.hostLeague != current.hostLeague ||
            previous.poll != current.poll ||
            previous.questions != current.questions ||
            previous.treasureBoxes != current.treasureBoxes ||
            previous.auctions != current.auctions,
        builder: (context, state) {
          if (state.liveId == null || state.liveId!.isEmpty) {
            return const SizedBox.shrink();
          }
          return Material(
            color: Colors.black.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Action(
                        icon: Icons.flag_outlined,
                        label: 'Goal',
                        onTap: state.isLoading
                            ? null
                            : () => _showGiftGoal(context),
                      ),
                      _Action(
                        icon: Icons.poll_outlined,
                        label: 'Poll',
                        onTap: state.isLoading
                            ? null
                            : () => _showPoll(context),
                      ),
                      _Action(
                        icon: Icons.question_answer_outlined,
                        label: 'Q&A',
                        onTap: state.isLoading
                            ? null
                            : () => _showQuestion(context),
                      ),
                      _Action(
                        icon: Icons.card_giftcard_outlined,
                        label: 'Box',
                        onTap: state.isLoading
                            ? null
                            : () => _showTreasureBox(context),
                      ),
                      _Action(
                        icon: Icons.gavel_outlined,
                        label: 'Auction',
                        onTap: state.isLoading
                            ? null
                            : () => _showAuction(context),
                      ),
                    ],
                  ),
                  if (state.hostLeague != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'League ${state.hostLeague!.hostLeagueTier} · ${state.hostLeague!.progressPercentage.toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                      ),
                    ),
                  if (state.poll != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Poll: ${state.poll!.question}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: state.isLoading
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
                      height: 30,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: state.questions.take(5).map(
                          (question) => Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: ActionChip(
                              label: Text(
                                question.question,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                              avatar: Icon(
                                question.isAnswered ? Icons.done : Icons.question_answer_outlined,
                                size: 13,
                              ),
                              onPressed: state.isLoading
                                  ? null
                                  : () => _showQuestionActions(context, question.id),
                            ),
                          ),
                        ).toList(),
                      ),
                    ),
                  if (state.auctions.isNotEmpty)
                    SizedBox(
                      height: 28,
                      child: Row(
                        children: [
                          Expanded(
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: state.auctions
                                  .map(
                                    (auction) => Padding(
                                      padding: const EdgeInsets.only(right: 5),
                                      child: ActionChip(
                                        label: Text(
                                          '${auction.itemName} · ${auction.currentPrice}',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        avatar: Icon(
                                          auction.isPinned
                                              ? Icons.push_pin
                                              : Icons.push_pin_outlined,
                                          size: 13,
                                        ),
                                        onPressed: state.isLoading
                                            ? null
                                            : () => context
                                                  .read<LiveInteractiveBloc>()
                                                  .add(
                                                    LiveInteractiveAuctionPinToggled(
                                                      auctionId: auction.id,
                                                      pinned: !auction.isPinned,
                                                    ),
                                                  ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          TextButton(
                            onPressed: state.isLoading
                                ? null
                                : () => _showReorder(context, state.auctions),
                            child: const Text('Order', style: TextStyle(fontSize: 10)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showGiftGoal(BuildContext context) async {
    final title = TextEditingController();
    final target = TextEditingController();
    final result = await _formDialog(
      context,
      title: 'Create gift goal',
      fields: [
        (title, 'Title (optional)', TextInputType.text),
        (target, 'Target coins', TextInputType.number),
      ],
    );
    if (result != true || !context.mounted) return;
    final value = int.tryParse(target.text.trim());
    if (value == null || value <= 0) return;
    context.read<LiveInteractiveBloc>().add(
      LiveInteractiveGiftGoalCreated(
        title: title.text.trim().isEmpty ? null : title.text.trim(),
        target: value,
      ),
    );
  }

  Future<void> _showPoll(BuildContext context) async {
    final question = TextEditingController();
    final optionControllers = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create poll'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: question,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Question'),
                ),
                ...optionControllers.asMap().entries.map(
                  (entry) => TextField(
                    controller: entry.value,
                    maxLength: 100,
                    decoration: InputDecoration(labelText: 'Option ${entry.key + 1}'),
                  ),
                ),
                if (optionControllers.length < 5)
                  TextButton.icon(
                    onPressed: () => setState(
                      () => optionControllers.add(TextEditingController()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add option'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    final options = optionControllers
        .map((controller) => controller.text.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final questionText = question.text.trim();
    for (final controller in [question, ...optionControllers]) {
      controller.dispose();
    }
    if (result != true || !context.mounted) return;
    if (questionText.isEmpty || options.length < 2 || options.length > 5) {
      return;
    }
    context.read<LiveInteractiveBloc>().add(
      LiveInteractivePollCreated(question: questionText, options: options),
    );
  }

  Future<void> _showQuestion(BuildContext context) async {
    final question = TextEditingController();
    final result = await _formDialog(
      context,
      title: 'Ask a question',
      fields: [(question, 'Question', TextInputType.text)],
    );
    if (result != true || !context.mounted || question.text.trim().isEmpty) {
      return;
    }
    context.read<LiveInteractiveBloc>().add(
      LiveInteractiveQuestionCreated(question.text.trim()),
    );
  }

  Future<void> _showTreasureBox(BuildContext context) async {
    final coins = TextEditingController();
    final claims = TextEditingController();
    final delay = TextEditingController(text: '180');
    final result = await _formDialog(
      context,
      title: 'Spawn treasure box',
      fields: [
        (coins, 'Total coins', TextInputType.number),
        (claims, 'Maximum claims', TextInputType.number),
        (delay, 'Unlock delay seconds (10–600)', TextInputType.number),
      ],
    );
    if (result != true || !context.mounted) return;
    final total = int.tryParse(coins.text.trim());
    final maxClaims = int.tryParse(claims.text.trim());
    final delaySeconds = int.tryParse(delay.text.trim());
    if (total == null ||
        maxClaims == null ||
        delaySeconds == null ||
        total < 10 ||
        maxClaims < 1 ||
        maxClaims > 100 ||
        delaySeconds < 10 ||
        delaySeconds > 600) {
      return;
    }
    context.read<LiveInteractiveBloc>().add(
      LiveInteractiveTreasureBoxCreated(
        totalCoins: total,
        maxClaims: maxClaims,
        delaySeconds: delaySeconds,
      ),
    );
  }

  Future<void> _showQuestionActions(BuildContext context, String questionId) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('Pin question'),
              onTap: () => Navigator.pop(sheetContext, 'pin'),
            ),
            ListTile(
              leading: const Icon(Icons.done),
              title: const Text('Mark answered'),
              onTap: () => Navigator.pop(sheetContext, 'answer'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    final bloc = context.read<LiveInteractiveBloc>();
    if (action == 'pin') {
      bloc.add(LiveInteractiveQuestionPinned(questionId));
    } else if (action == 'answer') {
      bloc.add(LiveInteractiveQuestionAnswered(questionId));
    }
  }

  Future<void> _showAuction(BuildContext context) async {
    final name = TextEditingController();
    final target = TextEditingController();
    final starting = TextEditingController();
    final result = await _formDialog(
      context,
      title: 'Create auction',
      fields: [
        (name, 'Item name', TextInputType.text),
        (target, 'Target price', TextInputType.number),
        (starting, 'Starting price (optional)', TextInputType.number),
      ],
    );
    if (result != true || !context.mounted) return;
    final targetValue = int.tryParse(target.text.trim());
    if (name.text.trim().isEmpty || targetValue == null || targetValue <= 0) {
      return;
    }
    context.read<LiveInteractiveBloc>().add(
      LiveInteractiveAuctionCreated(
        itemName: name.text.trim(),
        targetPrice: targetValue,
        startingPrice: int.tryParse(starting.text.trim()),
      ),
    );
  }

  Future<bool?> _formDialog(
    BuildContext context, {
    required String title,
    required List<(TextEditingController, String, TextInputType)> fields,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields
                .map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: field.$1,
                      keyboardType: field.$3,
                      decoration: InputDecoration(labelText: field.$2),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReorder(
    BuildContext context,
    List<LiveAuction> auctions,
  ) async {
    final reordered = List<LiveAuction>.from(auctions);
    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Column(
          children: [
            const SizedBox(height: 12),
            const Text('Reorder pinned auctions'),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: reordered.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                  });
                },
                itemBuilder: (_, index) => ListTile(
                  key: ValueKey(reordered[index].id),
                  title: Text(reordered[index].itemName),
                  trailing: const Icon(Icons.drag_handle),
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: const Text('Save order'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (result != true || !context.mounted) return;
    context.read<LiveInteractiveBloc>().add(
      LiveInteractiveAuctionsReordered(
        reordered.map((auction) => auction.id).toList(growable: false),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: onTap == null ? Colors.white38 : Colors.white),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.white38 : Colors.white,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
