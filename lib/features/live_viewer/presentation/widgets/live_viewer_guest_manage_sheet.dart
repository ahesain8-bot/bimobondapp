import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/guest_repository.dart';
import '../bloc/live_viewer/live_viewer_bloc.dart';
import '../bloc/live_viewer/live_viewer_event.dart';
import '../di/live_viewer_injector.dart' as di;

/// Permitted live-moderator guest actions (not same-room cohost promote).
class LiveViewerGuestManageSheet {
  const LiveViewerGuestManageSheet._();

  static Future<void> show(
    BuildContext context, {
    required String liveId,
    required bool audioOnly,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1C),
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<LiveViewerBloc>(),
        child: _Body(liveId: liveId, audioOnly: audioOnly),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.liveId, required this.audioOnly});

  final String liveId;
  final bool audioOnly;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  var _loading = true;
  var _busy = false;
  String? _error;
  List<GuestSummary> _guests = const [];
  final _inviteController = TextEditingController();

  GuestRepository get _repo => di.sl<GuestRepository>();

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
    final result = await _repo.listGuests(widget.liveId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (guests) {
        setState(() {
          _guests = guests;
          _loading = false;
        });
        context.read<LiveViewerBloc>().add(const LiveViewerGuestsRefreshed());
      },
    );
  }

  Future<void> _run(
    Future<dynamic> Function() action, {
    String? success,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => _snack(failure.message),
      (_) {
        if (success != null) _snack(success);
        _load();
      },
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'إدارة الضيوف',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent))
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inviteController,
                        enabled: !_busy,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'معرّف المستخدم للدعوة',
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              final userId = _inviteController.text.trim();
                              if (userId.isEmpty) return;
                              _run(
                                () => _repo.inviteGuest(
                                  liveId: widget.liveId,
                                  userId: userId,
                                ),
                                success: 'تم إرسال الدعوة',
                              );
                            },
                      child: const Text('دعوة'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListView(
                  shrinkWrap: true,
                  children: [
                    for (final guest in _guests) _guestTile(guest),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _guestTile(GuestSummary guest) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
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
          if (guest.isPending)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => _repo.acceptGuest(
                        liveId: widget.liveId,
                        userId: guest.userId,
                      ),
                    ),
              child: const Text('قبول'),
            ),
          if (guest.isPending)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => _repo.rejectGuest(
                        liveId: widget.liveId,
                        userId: guest.userId,
                      ),
                    ),
              child: const Text('رفض'),
            ),
          if (guest.isActive)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => guest.mutedByHost
                          ? _repo.unmuteGuest(
                              liveId: widget.liveId,
                              userId: guest.userId,
                            )
                          : _repo.muteGuest(
                              liveId: widget.liveId,
                              userId: guest.userId,
                            ),
                    ),
              child: Text(guest.mutedByHost ? 'إلغاء كتم' : 'كتم المايك'),
            ),
          if (guest.isActive && !widget.audioOnly)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => guest.cameraOffByHost
                          ? _repo.setGuestCameraOn(
                              liveId: widget.liveId,
                              userId: guest.userId,
                            )
                          : _repo.setGuestCameraOff(
                              liveId: widget.liveId,
                              userId: guest.userId,
                            ),
                    ),
              child: Text(
                guest.cameraOffByHost ? 'كاميرا' : 'إغلاق الكاميرا',
              ),
            ),
          if (guest.isActive)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => _repo.kickGuest(
                        liveId: widget.liveId,
                        userId: guest.userId,
                      ),
                      success: 'تم الطرد',
                    ),
              child: const Text('طرد'),
            ),
        ],
      ),
    );
  }
}
