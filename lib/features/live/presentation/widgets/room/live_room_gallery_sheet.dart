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
          child: _LiveRoomGallerySheetBody(liveId: state.session.id),
        ),
      ),
    );
  }
}

class _LiveRoomGallerySheetBody extends StatefulWidget {
  const _LiveRoomGallerySheetBody({required this.liveId});

  final String liveId;

  @override
  State<_LiveRoomGallerySheetBody> createState() =>
      _LiveRoomGallerySheetBodyState();
}

class _LiveRoomGallerySheetBodyState extends State<_LiveRoomGallerySheetBody>
    with LiveRoomHostSheetMixin {
  var _loading = true;
  var _busy = false;
  String? _error;
  List<LiveGalleryItem> _items = const [];

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
      final items = await repository.loadGalleryItems(widget.liveId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      context.read<LiveRoomBloc>().add(const LiveRoomGalleryChanged());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<void> _togglePin(LiveGalleryItem item) async {
    if (_busy) return;
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
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
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
                          trailing: IconButton(
                            tooltip: item.pinned ? 'إلغاء التثبيت' : 'تثبيت',
                            onPressed: _busy ? null : () => _togglePin(item),
                            icon: Icon(
                              item.pinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              color: item.pinned
                                  ? const Color(0xFFFFC107)
                                  : Colors.white70,
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
