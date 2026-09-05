import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

class LiveRoomChatRulesSheet {
  const LiveRoomChatRulesSheet._();

  static Future<void> show(BuildContext context) {
    final bloc = context.read<LiveRoomBloc>();
    return LiveRoomHostSheetChrome.show(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _LiveRoomChatRulesSheetBody(),
      ),
    );
  }
}

class _LiveRoomChatRulesSheetBody extends StatefulWidget {
  const _LiveRoomChatRulesSheetBody();

  @override
  State<_LiveRoomChatRulesSheetBody> createState() =>
      _LiveRoomChatRulesSheetBodyState();
}

class _LiveRoomChatRulesSheetBodyState
    extends State<_LiveRoomChatRulesSheetBody> {
  static const _modes = ['EVERYONE', 'FOLLOWERS', 'SUBSCRIBERS'];
  late String _chatMode;
  late final TextEditingController _slowMode;
  late final TextEditingController _keywords;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final state = context.read<LiveRoomBloc>().state;
    final rules = state is LiveRoomReady ? state.session.chatRules : null;
    _chatMode = _modes.contains(rules?.chatMode)
        ? rules!.chatMode
        : 'EVERYONE';
    _slowMode = TextEditingController(text: '${rules?.slowModeSeconds ?? 0}');
    _keywords = TextEditingController(
      text: rules?.blockedKeywords.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _slowMode.dispose();
    _keywords.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    final seconds = int.tryParse(_slowMode.text.trim());
    if (seconds == null || seconds < 0 || seconds > 60) {
      setState(
        () => _validationError = 'Slow mode must be between 0 and 60 seconds.',
      );
      return;
    }
    final keywords = _keywords.text
        .split(',')
        .map((keyword) => keyword.trim())
        .where((keyword) => keyword.isNotEmpty)
        .toSet()
        .toList(growable: false);
    context.read<LiveRoomBloc>().add(
      LiveRoomChatRulesSubmitted(
        chatMode: _chatMode,
        slowModeSeconds: seconds,
        blockedKeywords: keywords,
      ),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      builder: (context, state) {
        final saving = state is LiveRoomReady && state.isUpdatingChatRules;
        return LiveRoomHostSheetChrome(
          title: 'Comment settings',
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              DropdownButtonFormField<String>(
                value: _chatMode,
                decoration: const InputDecoration(
                  labelText: 'Who can comment',
                ),
                items: [
                  for (final mode in _modes)
                    DropdownMenuItem(value: mode, child: Text(mode)),
                ],
                onChanged: saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _chatMode = value);
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _slowMode,
                enabled: !saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Slow mode (seconds)',
                  helperText: '0 disables slow mode; maximum 60 seconds.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keywords,
                enabled: !saving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Blocked keywords',
                  helperText: 'Separate words with commas.',
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _validationError!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: saving ? null : () => _save(context),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save comment settings'),
              ),
            ],
          ),
        );
      },
    );
  }
}
