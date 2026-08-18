import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_session.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';
import 'live_room_guests_sheet.dart';

/// People / viewers sheet.
///
/// There is no documented `GET /lives/:id/viewers` roster — shows live viewer
/// count from the session + guests from `GET /lives/:id/guests`.
class LiveRoomPeopleSheet {
  const LiveRoomPeopleSheet._();

  static Future<void> show(BuildContext context) async {
    final bloc = context.read<LiveRoomBloc>();
    final repo = context.read<LiveSessionRepository>();
    final state = bloc.state;
    if (state is! LiveRoomReady) return;

    final openGuests = await LiveRoomHostSheetChrome.show<bool>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RepositoryProvider.value(
          value: repo,
          child: _LiveRoomPeopleSheetBody(session: state.session),
        ),
      ),
    );
    if (openGuests == true && context.mounted) {
      await LiveRoomGuestsSheet.show(context);
    }
  }
}

class _LiveRoomPeopleSheetBody extends StatefulWidget {
  const _LiveRoomPeopleSheetBody({required this.session});

  final LiveSession session;

  @override
  State<_LiveRoomPeopleSheetBody> createState() =>
      _LiveRoomPeopleSheetBodyState();
}

class _LiveRoomPeopleSheetBodyState extends State<_LiveRoomPeopleSheetBody>
    with LiveRoomHostSheetMixin {
  var _loading = true;
  String? _error;
  var _activeGuests = 0;
  var _pendingGuests = 0;

  @override
  LiveSessionRepository get repository => context.read<LiveSessionRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final guests = await repository.loadGuests(widget.session.id);
      if (!mounted) return;
      setState(() {
        _activeGuests = guests.where((g) => g.isActive).length;
        _pendingGuests = guests.where((g) => g.isPending).length;
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

  @override
  Widget build(BuildContext context) {
    return LiveRoomHostSheetChrome(
      title: 'المشاهدون',
      child: _loading
          ? const LiveRoomSheetStatus.loading()
          : _error != null
              ? LiveRoomSheetStatus.error(message: _error!)
              : BlocBuilder<LiveRoomBloc, LiveRoomState>(
                  buildWhen: (previous, current) =>
                      current is LiveRoomReady &&
                      (previous is! LiveRoomReady ||
                          previous.session.viewerCount !=
                              current.session.viewerCount),
                  builder: (context, state) {
                    final viewers = state is LiveRoomReady
                        ? state.session.viewerCount
                        : widget.session.viewerCount;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _statCard(
                          title: 'عدد المشاهدين الآن',
                          value: '$viewers',
                          subtitle:
                              'يتحدث مباشرة عند دخول أو خروج مشاهد (liveViewers).',
                        ),
                        const SizedBox(height: 12),
                        _statCard(
                          title: 'ضيوف على المسرح',
                          value: '$_activeGuests',
                          subtitle: 'من GET /lives/:id/guests (ACTIVE)',
                        ),
                        const SizedBox(height: 12),
                        _statCard(
                          title: 'طلبات معلقة',
                          value: '$_pendingGuests',
                          subtitle: 'REQUESTED + INVITED',
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.groups_outlined),
                          label: const Text('إدارة الضيوف'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            context
                                .read<LiveRoomBloc>()
                                .add(const LiveRoomGuestsChanged());
                            Navigator.of(context).maybePop(false);
                          },
                          child: const Text('إغلاق'),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}
