import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../domain/entities/live_session.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

/// Host-only `PATCH /lives/:id/chat-rules`.
class LiveRoomChatRulesSheet {
  const LiveRoomChatRulesSheet._();

  static Future<void> show(BuildContext context) {
    final bloc = context.read<LiveRoomBloc>();
    final repo = context.read<LiveSessionRepository>();
    final state = bloc.state;
    if (state is! LiveRoomReady) return Future.value();

    return LiveRoomHostSheetChrome.show(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RepositoryProvider.value(
          value: repo,
          child: _ChatRulesBody(session: state.session),
        ),
      ),
    );
  }
}

class _ChatRulesBody extends StatefulWidget {
  const _ChatRulesBody({required this.session});

  final LiveSession session;

  @override
  State<_ChatRulesBody> createState() => _ChatRulesBodyState();
}

class _ChatRulesBodyState extends State<_ChatRulesBody>
    with LiveRoomHostSheetMixin {
  late String _chatMode;
  late int _slowModeSeconds;
  late List<String> _keywords;
  final _keywordController = TextEditingController();
  var _saving = false;

  @override
  LiveSessionRepository get repository => context.read<LiveSessionRepository>();

  @override
  void initState() {
    super.initState();
    _chatMode = widget.session.chatMode.toUpperCase();
    if (_chatMode != 'EVERYONE' &&
        _chatMode != 'FOLLOWERS' &&
        _chatMode != 'SUBSCRIBERS') {
      _chatMode = 'EVERYONE';
    }
    _slowModeSeconds = widget.session.slowModeSeconds.clamp(0, 60);
    _keywords = List<String>.from(widget.session.blockedKeywords);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await repository.updateChatRules(
        liveId: widget.session.id,
        chatMode: _chatMode,
        slowModeSeconds: _slowModeSeconds,
        blockedKeywords: _keywords,
      );
      if (!mounted) return;
      context.read<LiveRoomBloc>().add(LiveRoomChatRulesApplied(updated));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      snack(errorMessage(e));
    }
  }

  void _addKeyword() {
    final value = _keywordController.text.trim();
    if (value.isEmpty) return;
    if (_keywords.any((k) => k.toLowerCase() == value.toLowerCase())) {
      _keywordController.clear();
      return;
    }
    setState(() {
      _keywords = [..._keywords, value];
      _keywordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LiveRoomHostSheetChrome(
      title: 'قواعد الدردشة',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'وضع الدردشة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _modeChip('EVERYONE', 'الجميع'),
              _modeChip('FOLLOWERS', 'المتابعون'),
              _modeChip('SUBSCRIBERS', 'نادي المعجبين'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _slowModeSeconds == 0
                ? 'الوضع البطيء: متوقف'
                : 'الوضع البطيء: $_slowModeSeconds ث',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            value: _slowModeSeconds.toDouble(),
            min: 0,
            max: 60,
            divisions: 12,
            label: '$_slowModeSeconds',
            activeColor: AppColors.optionsToggleActive,
            onChanged: _saving
                ? null
                : (v) => setState(() => _slowModeSeconds = v.round()),
          ),
          const SizedBox(height: 8),
          const Text(
            'كلمات محظورة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  enabled: !_saving,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'أضف كلمة',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                  onSubmitted: (_) => _addKeyword(),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : _addKeyword,
                icon: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in _keywords)
                InputChip(
                  label: Text(word),
                  onDeleted: _saving
                      ? null
                      : () => setState(
                          () => _keywords = _keywords
                              .where((k) => k != word)
                              .toList(),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String value, String label) {
    final selected = _chatMode == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _saving
          ? null
          : (_) => setState(() => _chatMode = value),
    );
  }
}
