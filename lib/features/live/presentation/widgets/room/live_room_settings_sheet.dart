import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_session.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

/// Live guest-policy settings (`PATCH /lives/:id/settings`).
class LiveRoomSettingsSheet {
  const LiveRoomSettingsSheet._();

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
          child: _LiveRoomSettingsSheetBody(session: state.session),
        ),
      ),
    );
  }
}

class _LiveRoomSettingsSheetBody extends StatefulWidget {
  const _LiveRoomSettingsSheetBody({required this.session});

  final LiveSession session;

  @override
  State<_LiveRoomSettingsSheetBody> createState() =>
      _LiveRoomSettingsSheetBodyState();
}

class _LiveRoomSettingsSheetBodyState extends State<_LiveRoomSettingsSheetBody>
    with LiveRoomHostSheetMixin {
  late bool _guestsEnabled;
  late String _guestRequestMode;
  late int _maxGuests;
  late String _layout;
  late bool _allowGuestCamera;
  late bool _moderatorsCanManageGuests;
  var _saving = false;

  @override
  LiveSessionRepository get repository => context.read<LiveSessionRepository>();

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _guestsEnabled = s.guestsEnabled ?? true;
    _guestRequestMode = s.guestRequestMode ?? 'EVERYONE';
    _maxGuests = (s.maxGuests ?? 8).clamp(1, 8);
    _layout = s.layout ?? 'GRID';
    _allowGuestCamera = s.allowGuestCamera ?? true;
    _moderatorsCanManageGuests = s.moderatorsCanManageGuests ?? true;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await repository.updateSettings(
        liveId: widget.session.id,
        guestsEnabled: _guestsEnabled,
        guestRequestMode: _guestRequestMode,
        maxGuests: _maxGuests,
        layout: _layout,
        allowGuestCamera: _allowGuestCamera,
        moderatorsCanManageGuests: _moderatorsCanManageGuests,
      );
      if (!mounted) return;
      context.read<LiveRoomBloc>().add(LiveRoomSettingsApplied(updated));
      snack('تم حفظ الإعدادات');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiveRoomHostSheetChrome(
      title: 'إعدادات البث',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SwitchListTile(
            value: _guestsEnabled,
            onChanged: _saving
                ? null
                : (v) => setState(() => _guestsEnabled = v),
            title: const Text('تفعيل الضيوف', style: TextStyle(color: Colors.white)),
            activeThumbColor: const Color(0xFF26D3B4),
          ),
          const SizedBox(height: 8),
          const Text('من يمكنه الطلب', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final mode in const ['EVERYONE', 'FOLLOWERS', 'OFF'])
                ChoiceChip(
                  label: Text(_modeLabel(mode)),
                  selected: _guestRequestMode == mode,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _guestRequestMode = mode),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'الحد الأقصى للضيوف: $_maxGuests',
            style: const TextStyle(color: Colors.white70),
          ),
          Slider(
            value: _maxGuests.toDouble(),
            min: 1,
            max: 8,
            divisions: 7,
            label: '$_maxGuests',
            onChanged: _saving
                ? null
                : (v) => setState(() => _maxGuests = v.round()),
          ),
          const SizedBox(height: 8),
          const Text('تخطيط المسرح', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final layout in const ['GRID', 'PANEL'])
                ChoiceChip(
                  label: Text(layout == 'GRID' ? 'شبكة' : 'لوحة'),
                  selected: _layout == layout,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _layout = layout),
                ),
            ],
          ),
          SwitchListTile(
            value: _allowGuestCamera,
            onChanged: _saving
                ? null
                : (v) => setState(() => _allowGuestCamera = v),
            title: const Text(
              'السماح بكاميرا الضيف',
              style: TextStyle(color: Colors.white),
            ),
          ),
          SwitchListTile(
            value: _moderatorsCanManageGuests,
            onChanged: _saving
                ? null
                : (v) => setState(() => _moderatorsCanManageGuests = v),
            title: const Text(
              'المشرفون يديرون الضيوف',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
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

  String _modeLabel(String mode) {
    return switch (mode) {
      'EVERYONE' => 'الجميع',
      'FOLLOWERS' => 'المتابعون',
      'OFF' => 'إيقاف',
      _ => mode,
    };
  }
}
