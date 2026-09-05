import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/widgets/app_action_sheet.dart';
import '../../../../../core/widgets/app_form_dialog.dart';
import '../../bloc/live_interactive/live_interactive_bloc.dart';
import '../../bloc/live_interactive/live_interactive_event.dart';

/// Everything the host can start mid-stream, behind one entry point.
///
/// The room bars only carry [icon]; the actions themselves live here so the
/// host bar and the viewer bar cannot drift apart, and so the create dialogs
/// keep the shape [AppFormDialog] gave them.
abstract final class LiveInteractiveTools {
  LiveInteractiveTools._();

  /// One glyph for the entry point wherever it appears.
  static const IconData icon = Icons.widgets_rounded;

  static const String label = 'Interactions';

  /// Opens the host action panel. Reads the bloc up front so each action can
  /// dispatch after the sheet — and its context — is gone.
  static Future<void> showHostSheet(BuildContext context) {
    final bloc = context.read<LiveInteractiveBloc>();
    final busy = bloc.state.isLoading;

    return AppActionSheet.show<void>(
      context,
      title: label,
      subtitle: 'Start something your viewers can join',
      brightness: Brightness.dark,
      children: [
        AppActionTile(
          icon: Icons.flag_rounded,
          title: 'Gift goal',
          subtitle: 'Set a coin target for this stream',
          featured: true,
          enabled: !busy,
          onTap: () => _createGiftGoal(context, bloc),
        ),
        AppActionTile(
          icon: Icons.bar_chart_rounded,
          title: 'Poll',
          subtitle: 'Let viewers vote on up to five options',
          enabled: !busy,
          onTap: () => _createPoll(context, bloc),
        ),
        AppActionTile(
          icon: Icons.help_outline_rounded,
          title: 'Q&A',
          subtitle: 'Post a question and pin the best answers',
          enabled: !busy,
          onTap: () => _askQuestion(context, bloc),
        ),
        AppActionTile(
          icon: Icons.gavel_rounded,
          title: 'Auction',
          subtitle: 'Showcase an item and collect bids',
          enabled: !busy,
          onTap: () => _createAuction(context, bloc),
        ),
        AppActionTile(
          icon: Icons.inventory_2_rounded,
          title: 'Treasure box',
          subtitle: 'Drop coins for viewers to claim',
          enabled: !busy,
          onTap: () => _spawnTreasureBox(context, bloc),
        ),
      ],
    );
  }
}

Future<void> _createGiftGoal(
  BuildContext context,
  LiveInteractiveBloc bloc,
) async {
  final fields = await _promptFields(
    context,
    title: 'Create gift goal',
    fields: const [
      _FieldSpec('Title (optional)', hint: 'Help me reach my goal'),
      _FieldSpec(
        'Target coins',
        numeric: true,
        coin: true,
        hint: 'Amount to reach',
      ),
    ],
  );
  if (fields == null) return;
  bloc.add(
    LiveInteractiveGiftGoalCreated(
      title: fields[0].isEmpty ? null : fields[0],
      target: int.tryParse(fields[1]) ?? 0,
    ),
  );
}

Future<void> _createAuction(
  BuildContext context,
  LiveInteractiveBloc bloc,
) async {
  final fields = await _promptFields(
    context,
    title: 'Create auction',
    fields: const [
      _FieldSpec('Item name', hint: 'What are you showcasing?'),
      _FieldSpec(
        'Target price',
        numeric: true,
        coin: true,
        hint: 'Amount to reach',
      ),
      _FieldSpec(
        'Starting price (optional)',
        numeric: true,
        coin: true,
        hint: 'Opening bid',
      ),
    ],
  );
  if (fields == null) return;
  bloc.add(
    LiveInteractiveAuctionCreated(
      itemName: fields[0],
      targetPrice: int.tryParse(fields[1]) ?? 0,
      startingPrice: int.tryParse(fields[2]),
    ),
  );
}

Future<void> _spawnTreasureBox(
  BuildContext context,
  LiveInteractiveBloc bloc,
) async {
  final fields = await _promptFields(
    context,
    title: 'Spawn treasure box',
    fields: const [
      _FieldSpec(
        'Total coins',
        numeric: true,
        coin: true,
        hint: 'Amount to give away',
      ),
      _FieldSpec(
        'Maximum claims',
        numeric: true,
        hint: 'How many viewers can win',
      ),
      _FieldSpec(
        'Unlock delay',
        numeric: true,
        initialValue: '180',
        helper: 'Seconds before viewers can claim (10–600)',
      ),
    ],
  );
  if (fields == null) return;
  bloc.add(
    LiveInteractiveTreasureBoxCreated(
      totalCoins: int.tryParse(fields[0]) ?? 0,
      maxClaims: int.tryParse(fields[1]) ?? 0,
      delaySeconds: int.tryParse(fields[2]) ?? 0,
    ),
  );
}

Future<void> _askQuestion(
  BuildContext context,
  LiveInteractiveBloc bloc,
) async {
  final fields = await _promptFields(
    context,
    title: 'Ask a question',
    fields: const [
      _FieldSpec(
        'Question',
        maxLength: 500,
        multiline: true,
        hint: 'Ask your viewers something',
      ),
    ],
  );
  if (fields == null || fields[0].isEmpty) return;
  bloc.add(LiveInteractiveQuestionCreated(fields[0]));
}

Future<void> _createPoll(BuildContext context, LiveInteractiveBloc bloc) async {
  final result = await showDialog<_PollDraft>(
    context: context,
    builder: (_) => const _CreatePollDialog(),
  );
  if (result == null) return;
  bloc.add(
    LiveInteractivePollCreated(
      question: result.question,
      options: result.options,
    ),
  );
}

/// Shows a simple text-field dialog and returns the trimmed values, or null
/// when the host cancels.
Future<List<String>?> _promptFields(
  BuildContext context, {
  required String title,
  required List<_FieldSpec> fields,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _FieldsDialog(title: title, fields: fields),
  );
}

class _FieldSpec {
  const _FieldSpec(
    this.label, {
    this.numeric = false,
    this.maxLength,
    this.initialValue,
    this.hint,
    this.helper,
    this.coin = false,
    this.multiline = false,
  });

  final String label;
  final bool numeric;
  final int? maxLength;
  final String? initialValue;

  /// Presentation only — placeholder, helper line, coin affordance and whether
  /// the input grows to a few lines.
  final String? hint;
  final String? helper;
  final bool coin;
  final bool multiline;
}

class _FieldsDialog extends StatefulWidget {
  const _FieldsDialog({required this.title, required this.fields});

  final String title;
  final List<_FieldSpec> fields;

  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  late final List<TextEditingController> _controllers = widget.fields
      .map((field) => TextEditingController(text: field.initialValue))
      .toList(growable: false);

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.fields.length - 1;
    return AppFormDialog(
      title: widget.title,
      // Opened over the camera, so it stays dark whatever the app theme is.
      brightness: Brightness.dark,
      primaryLabel: 'Save',
      onPrimary: () => Navigator.pop(
        context,
        _controllers
            .map((controller) => controller.text.trim())
            .toList(growable: false),
      ),
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.pop(context),
      children: [
        for (var index = 0; index < widget.fields.length; index++)
          AppFormField(
            controller: _controllers[index],
            label: widget.fields[index].label,
            hintText: widget.fields[index].hint,
            helperText: widget.fields[index].helper,
            autofocus: index == 0,
            keyboardType: widget.fields[index].numeric
                ? TextInputType.number
                : TextInputType.text,
            maxLength: widget.fields[index].maxLength,
            maxLines: widget.fields[index].multiline ? 3 : 1,
            showCoinPrefix: widget.fields[index].coin,
            bottomGap: index == last ? 0 : AppModalTokens.fieldGap,
          ),
      ],
    );
  }
}

class _PollDraft {
  const _PollDraft({required this.question, required this.options});

  final String question;
  final List<String> options;
}

class _CreatePollDialog extends StatefulWidget {
  const _CreatePollDialog();

  @override
  State<_CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends State<_CreatePollDialog> {
  static const _maxOptions = 5;

  final _question = TextEditingController();
  final _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _question.dispose();
    for (final controller in _options) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppModalPalette.of(context);
    final canAddOption = _options.length < _maxOptions;
    final lastOption = _options.length - 1;

    return AppFormDialog(
      title: 'Create poll',
      brightness: Brightness.dark,
      primaryLabel: 'Create',
      onPrimary: () => Navigator.pop(
        context,
        _PollDraft(
          question: _question.text.trim(),
          options: _options
              .map((controller) => controller.text.trim())
              .toList(growable: false),
        ),
      ),
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.pop(context),
      children: [
        AppFormField(
          controller: _question,
          label: 'Question',
          hintText: 'What do you want to ask?',
          autofocus: true,
          maxLength: 200,
        ),
        for (var index = 0; index < _options.length; index++)
          AppFormField(
            controller: _options[index],
            label: 'Option ${index + 1}',
            maxLength: 100,
            bottomGap: index == lastOption && !canAddOption
                ? 0
                : AppModalTokens.fieldGap,
          ),
        if (canAddOption)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _options.add(TextEditingController())),
              icon: const Icon(Icons.add_rounded, size: 18),
              style: TextButton.styleFrom(
                foregroundColor: palette.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              label: const Text('Add option'),
            ),
          ),
      ],
    );
  }
}
