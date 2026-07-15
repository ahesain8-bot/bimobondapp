import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatPollDraft {
  const ChatPollDraft({
    required this.question,
    required this.options,
    this.allowMultiple = false,
  });

  final String question;
  final List<String> options;
  final bool allowMultiple;
}

class ChatPollSheet {
  ChatPollSheet._();

  static Future<ChatPollDraft?> show(BuildContext context) {
    return GlassBottomSheet.open<ChatPollDraft>(
      context,
      isScrollControlled: true,
      builder: (_) => const _ChatPollSheetBody(),
    );
  }
}

class _ChatPollSheetBody extends StatefulWidget {
  const _ChatPollSheetBody();

  @override
  State<_ChatPollSheetBody> createState() => _ChatPollSheetBodyState();
}

class _ChatPollSheetBodyState extends State<_ChatPollSheetBody> {
  final _questionController = TextEditingController();
  final _optionControllers = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  bool _allowMultiple = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 8) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers.removeAt(index).dispose();
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatPollQuestionRequired)),
      );
      return;
    }
    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatPollOptionsRequired)),
      );
      return;
    }

    Navigator.pop(
      context,
      ChatPollDraft(
        question: question,
        options: options,
        allowMultiple: _allowMultiple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.chatPollSheetTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.p16),
            TextField(
              controller: _questionController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.chatPollQuestionHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              l10n.chatPollOptionsLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            for (var i = 0; i < _optionControllers.length; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _optionControllers[i],
                      decoration: InputDecoration(
                        hintText: l10n.chatPollOptionHint(i + 1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  if (_optionControllers.length > 2)
                    IconButton(
                      onPressed: () => _removeOption(i),
                      icon: const Icon(LucideIcons.x),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.p8),
            ],
            if (_optionControllers.length < 8)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(LucideIcons.plus),
                label: Text(l10n.chatPollAddOption),
              ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.chatPollAllowMultiple),
              value: _allowMultiple,
              onChanged: (v) => setState(() => _allowMultiple = v),
            ),
            const SizedBox(height: AppSizes.p8),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(l10n.chatPollSend),
            ),
          ],
        ),
      ),
    );
  }
}
