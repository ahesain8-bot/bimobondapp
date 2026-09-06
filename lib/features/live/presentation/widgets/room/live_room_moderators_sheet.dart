import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_moderator.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

/// Host-only `GET/POST/DELETE /lives/:id/moderators`.
class LiveRoomModeratorsSheet {
  const LiveRoomModeratorsSheet._();

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
          child: _ModeratorsBody(liveId: state.session.id),
        ),
      ),
    );
  }
}

class _ModeratorsBody extends StatefulWidget {
  const _ModeratorsBody({required this.liveId});

  final String liveId;

  @override
  State<_ModeratorsBody> createState() => _ModeratorsBodyState();
}

class _ModeratorsBodyState extends State<_ModeratorsBody>
    with LiveRoomHostSheetMixin {
  var _loading = true;
  var _busy = false;
  String? _error;
  List<LiveModerator> _mods = const [];
  final _userIdController = TextEditingController();

  @override
  LiveSessionRepository get repository => context.read<LiveSessionRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mods = await repository.loadModerators(widget.liveId);
      if (!mounted) return;
      setState(() {
        _mods = mods;
        _loading = false;
      });
      context.read<LiveRoomBloc>().add(
        LiveRoomModeratorsChanged(
          mods.map((m) => m.userId).toList(growable: false),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<void> _add() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await repository.addModerator(liveId: widget.liveId, userId: userId);
      _userIdController.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String userId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await repository.removeModerator(liveId: widget.liveId, userId: userId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiveRoomHostSheetChrome(
      title: 'مشرفو الغرفة',
      child: _loading
          ? const LiveRoomSheetStatus.loading()
          : _error != null
          ? LiveRoomSheetStatus.error(message: _error!)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Text(
                  'يُعيَّنون لهذا البث فقط عبر POST /lives/:id/moderators.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userIdController,
                        enabled: !_busy,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'معرّف المستخدم',
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _busy ? null : _add,
                      child: const Text('تعيين'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_mods.isEmpty)
                  const Text(
                    'لا يوجد مشرفون معيَّنون.',
                    style: TextStyle(color: Colors.white54),
                  )
                else
                  for (final mod in _mods)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage:
                            mod.avatarUrl != null && mod.avatarUrl!.isNotEmpty
                            ? NetworkImage(mod.avatarUrl!)
                            : null,
                        child: mod.avatarUrl == null || mod.avatarUrl!.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        mod.username ?? mod.userId,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        mod.userId,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: _busy ? null : () => _remove(mod.userId),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ),
              ],
            ),
    );
  }
}
