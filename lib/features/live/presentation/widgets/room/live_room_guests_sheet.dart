import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_guest.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

/// Host multi-guest / collaboration sheet (lives/mobile-api.md §10).
class LiveRoomGuestsSheet {
  const LiveRoomGuestsSheet._();

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
          child: _LiveRoomGuestsSheetBody(liveId: state.session.id),
        ),
      ),
    );
  }
}

class _LiveRoomGuestsSheetBody extends StatefulWidget {
  const _LiveRoomGuestsSheetBody({required this.liveId});

  final String liveId;

  @override
  State<_LiveRoomGuestsSheetBody> createState() =>
      _LiveRoomGuestsSheetBodyState();
}

class _LiveRoomGuestsSheetBodyState extends State<_LiveRoomGuestsSheetBody>
    with LiveRoomHostSheetMixin {
  var _loading = true;
  var _busy = false;
  String? _error;
  List<LiveGuest> _guests = const [];
  final _inviteController = TextEditingController();

  @override
  LiveSessionRepository get repository => context.read<LiveSessionRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final guests = await repository.loadGuests(widget.liveId);
      if (!mounted) return;
      setState(() {
        _guests = guests;
        _loading = false;
      });
      context.read<LiveRoomBloc>().add(const LiveRoomGuestsChanged());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (success != null) snack(success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final userId = _inviteController.text.trim();
    if (userId.isEmpty) {
      snack('أدخل معرف المستخدم للدعوة');
      return;
    }
    await _run(
      () => repository.inviteGuest(liveId: widget.liveId, userId: userId),
      success: 'تم إرسال الدعوة',
    );
    _inviteController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _guests.where((g) => g.isPending).toList();
    final active = _guests.where((g) => g.isActive).toList();

    return LiveRoomHostSheetChrome(
      title: 'الضيوف والتعاون',
      actions: [
        IconButton(
          onPressed: _loading || _busy ? null : _load,
          icon: const Icon(Icons.refresh, color: Colors.white70),
        ),
      ],
      child: _loading
          ? const LiveRoomSheetStatus.loading()
          : _error != null
              ? LiveRoomSheetStatus.error(message: _error!)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    const Text(
                      'دعوة ضيف',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inviteController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'userId',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _busy ? null : _invite,
                          child: const Text('دعوة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('طلبات معلقة (${pending.length})'),
                    if (pending.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'لا توجد طلبات حالياً',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      ...pending.map(_pendingTile),
                    const SizedBox(height: 14),
                    _sectionTitle('على المسرح (${active.length})'),
                    if (active.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'لا يوجد ضيوف نشطون',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      ...active.map(_activeTile),
                  ],
                ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }

  Widget _pendingTile(LiveGuest guest) {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        title: Text(
          guest.displayName,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${guest.status} · ${guest.role}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (guest.status == 'REQUESTED')
              IconButton(
                tooltip: 'قبول',
                onPressed: _busy
                    ? null
                    : () => _run(
                          () => repository.acceptGuest(
                            liveId: widget.liveId,
                            userId: guest.userId,
                          ),
                          success: 'تم القبول',
                        ),
                icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
              ),
            IconButton(
              tooltip: 'رفض',
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => repository.rejectGuest(
                          liveId: widget.liveId,
                          userId: guest.userId,
                        ),
                        success: 'تم الرفض',
                      ),
              icon: const Icon(Icons.cancel, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeTile(LiveGuest guest) {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        collapsedIconColor: Colors.white70,
        iconColor: Colors.white70,
        title: Text(
          guest.displayName,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${guest.role}${guest.mutedByHost ? ' · مكتوم' : ''}'
          '${guest.cameraOffByHost ? ' · كاميرا مغلقة' : ''}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _actionChip(
                guest.mutedByHost ? 'إلغاء كتم' : 'كتم المايك',
                () => _run(
                  () => guest.mutedByHost
                      ? repository.unmuteGuest(
                          liveId: widget.liveId,
                          userId: guest.userId,
                        )
                      : repository.muteGuest(
                          liveId: widget.liveId,
                          userId: guest.userId,
                        ),
                ),
              ),
              _actionChip(
                guest.cameraOffByHost ? 'تفعيل الكاميرا' : 'إغلاق الكاميرا',
                () => _run(
                  () => guest.cameraOffByHost
                      ? repository.setGuestCameraOn(
                          liveId: widget.liveId,
                          userId: guest.userId,
                        )
                      : repository.setGuestCameraOff(
                          liveId: widget.liveId,
                          userId: guest.userId,
                        ),
                ),
              ),
              if (guest.role == 'GUEST')
                _actionChip(
                  'ترقية لمضيف مشارك',
                  () => _run(
                    () => repository.promoteGuest(
                      liveId: widget.liveId,
                      userId: guest.userId,
                    ),
                    success: 'تمت الترقية',
                  ),
                ),
              if (guest.role == 'CO_HOST')
                _actionChip(
                  'إرجاع لضيف',
                  () => _run(
                    () => repository.demoteGuest(
                      liveId: widget.liveId,
                      userId: guest.userId,
                    ),
                  ),
                ),
              _actionChip(
                'طرد',
                () => _run(
                  () => repository.kickGuest(
                    liveId: widget.liveId,
                    userId: guest.userId,
                  ),
                  success: 'تم الطرد',
                ),
                danger: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _actionChip(String label, VoidCallback onTap, {bool danger = false}) {
    return ActionChip(
      onPressed: _busy ? null : onTap,
      label: Text(label),
      backgroundColor: danger ? Colors.red.shade900 : Colors.white12,
      labelStyle: TextStyle(
        color: danger ? Colors.red.shade100 : Colors.white,
        fontSize: 12,
      ),
    );
  }
}
