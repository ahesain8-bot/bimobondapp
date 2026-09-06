import 'dart:async';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_gallery_item.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

/// Live shopping gallery (`GET /lives/:id/gallery` + pin).
class LiveRoomGallerySheet {
  const LiveRoomGallerySheet._();

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
          child: LiveRoomGalleryContents(
            liveId: state.session.id,
            sessionRepository: repo,
            onChanged: () => bloc.add(const LiveRoomGalleryChanged()),
          ),
        ),
      ),
    );
  }
}

class LiveRoomGalleryContents extends StatefulWidget {
  const LiveRoomGalleryContents({
    super.key,
    required this.liveId,
    required this.sessionRepository,
    this.onChanged,
  });

  final LiveSessionRepository sessionRepository;
  final VoidCallback? onChanged;

  final String liveId;

  @override
  State<LiveRoomGalleryContents> createState() =>
      LiveRoomGalleryContentsState();
}

class LiveRoomGalleryContentsState extends State<LiveRoomGalleryContents>
    with LiveRoomHostSheetMixin {
  var _loading = true;
  int _generation = 0;
  bool _ended = false;
  StreamSubscription<LiveHudEvent>? _subscription;
  var _busy = false;
  String? _error;
  List<LiveGalleryItem> _items = const [];

  @override
  LiveSessionRepository get repository => widget.sessionRepository;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = repository.hudEvents.listen((event) {
      if (event is LiveHudEndedEvent && event.liveId == widget.liveId) {
        if (mounted) setState(() => _ended = true);
      }
      if (event is LiveHudInteractiveEvent &&
          event.payload.liveId == widget.liveId &&
          event.payload.event == 'liveAuction') {
        if (!_busy) _load();
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await repository.loadGalleryItems(widget.liveId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<void> _togglePin(LiveGalleryItem item) async {
    if (_busy || _ended) return;
    _generation++;
    setState(() => _busy = true);
    try {
      await repository.pinGalleryItem(
        liveId: widget.liveId,
        auctionId: item.id,
        pinned: !item.pinned,
      );
      if (!mounted) return;
      snack(item.pinned ? 'تم إلغاء التثبيت' : 'تم التثبيت');
      await _load();
    } catch (e) {
      if (!mounted) return;
      snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_busy || _ended || oldIndex < 0 || oldIndex >= _items.length) return;
    if (newIndex > oldIndex) newIndex--;
    if (newIndex == oldIndex) return;
    final ordered = [..._items];
    ordered.insert(newIndex, ordered.removeAt(oldIndex));
    _generation++;
    setState(() => _busy = true);
    try {
      await repository.reorderGalleryItems(
        liveId: widget.liveId,
        auctionIds: ordered.map((item) => item.id).toList(),
      );
    } catch (error) {
      if (mounted) snack(errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        // Always restore the server order, including failure and a socket
        // arriving while a reorder was in flight.
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiveRoomHostSheetChrome(
      title: 'المعرض',
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
          : _items.isEmpty
          ? const LiveRoomSheetStatus.empty(
              message: 'لا توجد عناصر في المعرض حالياً',
            )
          : ReorderableListView.builder(
              onReorder: _reorder,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  key: ValueKey(item.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: Colors.white10,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.itemImageUrl == null
                        ? Container(
                            width: 48,
                            height: 48,
                            color: Colors.white12,
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white54,
                            ),
                          )
                        : Image.network(
                            item.itemImageUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 48,
                              height: 48,
                              color: Colors.white12,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                  ),
                  title: Text(
                    item.itemName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (item.status != null) item.status!,
                      if (item.currentPrice != null)
                        'السعر: ${item.currentPrice}',
                      if (item.pinned) 'مثبّت',
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_busy && !_ended)
                        ReorderableDragStartListener(
                          index: index,
                          child: Tooltip(
                            message: AppLocalizations.of(
                              context,
                            )!.liveGalleryReorder,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                Icons.drag_handle,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: item.pinned ? 'إلغاء التثبيت' : 'تثبيت',
                        onPressed: _busy || _ended
                            ? null
                            : () => _togglePin(item),
                        icon: Icon(
                          item.pinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color: item.pinned
                              ? const Color(0xFFFFC107)
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
