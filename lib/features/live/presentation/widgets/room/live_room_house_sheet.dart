import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_house.dart';
import '../../../domain/entities/live_session.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

/// Host LIVE House create / attach this live / close.
///
/// Does not switch rooms or reuse LiveKit across rooms — that contract is
/// not documented.
class LiveRoomHouseSheet {
  const LiveRoomHouseSheet._();

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
          child: _HouseBody(session: state.session),
        ),
      ),
    );
  }
}

class _HouseBody extends StatefulWidget {
  const _HouseBody({required this.session});

  final LiveSession session;

  @override
  State<_HouseBody> createState() => _HouseBodyState();
}

class _HouseBodyState extends State<_HouseBody> with LiveRoomHostSheetMixin {
  var _loading = true;
  var _busy = false;
  String? _error;
  List<LiveHouse> _houses = const [];
  final _titleController = TextEditingController();

  @override
  LiveSessionRepository get repository => context.read<LiveSessionRepository>();

  String? get _attachedHouseId {
    final ready = context.read<LiveRoomBloc>().state;
    if (ready is LiveRoomReady) return ready.session.houseId;
    return widget.session.houseId;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final houses = await repository.loadHouses();
      if (!mounted) return;
      setState(() {
        _houses = houses;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final house = await repository.createHouse(title: title);
      await repository.attachLiveToHouse(
        houseId: house.id,
        liveId: widget.session.id,
      );
      if (!mounted) return;
      context.read<LiveRoomBloc>().add(LiveRoomHouseChanged(houseId: house.id));
      _titleController.clear();
      await _load();
      snack('تم إنشاء البيت وربط هذا البث');
    } catch (e) {
      if (!mounted) return;
      snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach(String houseId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await repository.attachLiveToHouse(
        houseId: houseId,
        liveId: widget.session.id,
      );
      if (!mounted) return;
      context.read<LiveRoomBloc>().add(LiveRoomHouseChanged(houseId: houseId));
      snack('تم ربط البث بالبيت');
    } catch (e) {
      if (!mounted) return;
      snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close(String houseId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await repository.closeHouse(houseId);
      if (!mounted) return;
      if (_attachedHouseId == houseId) {
        context.read<LiveRoomBloc>().add(const LiveRoomHouseChanged());
      }
      await _load();
      snack('تم إغلاق البيت');
    } catch (e) {
      if (!mounted) return;
      snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attached = _attachedHouseId;
    return LiveRoomHostSheetChrome(
      title: 'بيت البث',
      child: _loading
          ? const LiveRoomSheetStatus.loading()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  attached == null || attached.isEmpty
                      ? 'هذا البث غير مربوط ببيت.'
                      : 'houseId: $attached',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                const Text(
                  'يجمع البيت عدة غرف من بثوثك. لا يبدّل التطبيق الغرف تلقائياً.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  enabled: !_busy,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'عنوان البيت',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  child: const Text('إنشاء وربط هذا البث'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  TextButton(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'بيوتك',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_houses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'لا توجد بيوت بعد.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  for (final house in _houses)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        house.title ?? house.id,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        [
                          house.id,
                          if (house.status != null) house.status,
                          if (house.isClosed) 'مغلق',
                        ].join(' · '),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      trailing: house.isClosed
                          ? null
                          : Wrap(
                              spacing: 4,
                              children: [
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _attach(house.id),
                                  child: const Text('ربط'),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _close(house.id),
                                  child: const Text('إغلاق'),
                                ),
                              ],
                            ),
                    ),
              ],
            ),
    );
  }
}
