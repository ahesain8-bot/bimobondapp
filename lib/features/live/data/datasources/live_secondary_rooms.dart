import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/services/live_audio_session.dart';
import '../../domain/entities/live_cohost.dart';

/// Subscribe-only LiveKit rooms this client tiles beside its own: co-host
/// partners (`lives/live-p1-parity.md` §6, `live-p2-parity.md` §2) and the
/// extra lives of a 2v2 team PK (`live-p1-parity.md` §7).
///
/// Each room is a distinct slot keyed by its live id, with its own connection
/// generation and its own serialized queue. Nothing here reuses one connection
/// to stand for several rooms, and a slot only ever closes the [Room] it owns:
/// a late failure from a replaced connection cannot disconnect the current one.
///
/// This never publishes. The primary room — camera, microphone, the host's own
/// uplink — is owned elsewhere and is not touched from here.
class LiveSecondaryRooms extends ChangeNotifier {
  LiveSecondaryRooms({int maxRooms = 3}) : _maxRooms = maxRooms;

  /// A room plus three partners is the documented ceiling.
  final int _maxRooms;

  final Map<String, _SecondarySlot> _slots = {};
  var _holdsAudioSession = false;
  var _disposed = false;

  /// Live ids currently held, in insertion order.
  List<String> get liveIds => List.unmodifiable(_slots.keys);

  int get length => _slots.length;

  /// The connected room for [liveId], or null while it is connecting or gone.
  Room? roomFor(String liveId) {
    final slot = _slots[liveId];
    if (slot == null) return null;
    return slot.room;
  }

  bool isConnecting(String liveId) => _slots[liveId]?.connecting ?? false;

  /// The first remote video track published in [liveId]'s room, if any.
  RemoteVideoTrack? videoTrackFor(String liveId) {
    final room = roomFor(liveId);
    if (room == null) return null;
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track is RemoteVideoTrack && publication.subscribed) return track;
      }
    }
    return null;
  }

  /// Brings the held rooms in line with [desired]: connects the ones that are
  /// new, drops the ones that are gone, and leaves untouched the ones that are
  /// already connected to the same room.
  ///
  /// Ordering is preserved so tiles do not jump when one partner leaves.
  Future<void> sync(List<LiveCohostRoom> desired) async {
    if (_disposed) return;
    final wanted = <String, LiveCohostRoom>{};
    for (final room in desired) {
      if (!room.isConnectable) continue;
      if (wanted.length >= _maxRooms) break;
      wanted.putIfAbsent(room.liveId, () => room);
    }

    final stale = _slots.keys
        .where((id) => !wanted.containsKey(id))
        .toList(growable: false);
    for (final id in stale) {
      await disconnect(id);
    }

    for (final entry in wanted.entries) {
      final existing = _slots[entry.key];
      // A token refresh for a room we already hold is not a reason to tear the
      // tile down; only a different room or a dead connection is.
      if (existing != null && existing.isUsable) continue;
      await connect(entry.value);
    }
  }

  /// Connects one partner room. Safe to call again for the same live id: the
  /// previous connection for that id is closed first, and only by this slot.
  Future<void> connect(LiveCohostRoom target) async {
    if (_disposed || !target.isConnectable) return;
    if (!_slots.containsKey(target.liveId) && _slots.length >= _maxRooms) {
      return;
    }
    final slot = _slots.putIfAbsent(
      target.liveId,
      () => _SecondarySlot(target.liveId),
    );
    final generation = ++slot.generation;
    await slot.serialize(() async {
      if (_disposed || generation != slot.generation) return;
      await slot.closeCurrent();
      slot.connecting = true;
      _notify();
      Room? room;
      try {
        await _acquireAudioSession();
        room = Room(
          roomOptions: const RoomOptions(
            // These tiles mount their renderer only once a track exists;
            // adaptive stream can unsubscribe before that and leave a room
            // that never shows a frame.
            adaptiveStream: false,
            dynacast: false,
          ),
        );
        final listener = room.createListener();
        listener.on<RoomDisconnectedEvent>((_) {
          // Only the slot that still owns this room reacts to its events.
          if (slot.room == room && generation == slot.generation) _notify();
        });
        listener.on<TrackSubscribedEvent>((_) {
          if (slot.room == room && generation == slot.generation) _notify();
        });
        listener.on<TrackUnsubscribedEvent>((_) {
          if (slot.room == room && generation == slot.generation) _notify();
        });
        await room.connect(target.url, target.token);
        if (_disposed || generation != slot.generation) {
          // A newer connect (or a disconnect) won while we were in flight.
          await listener.dispose();
          await room.disconnect();
          await room.dispose();
          return;
        }
        slot.adopt(room: room, listener: listener);
      } catch (error, stack) {
        debugPrint('Co-host room ${target.liveId} connect failed: $error');
        debugPrintStack(stackTrace: stack);
        if (room != null && slot.room != room) {
          try {
            await room.disconnect();
            await room.dispose();
          } catch (_) {
            /* Already gone. */
          }
        }
      } finally {
        if (generation == slot.generation) slot.connecting = false;
        _notify();
      }
    });
  }

  /// Closes one partner room and forgets its slot.
  Future<void> disconnect(String liveId) async {
    final slot = _slots[liveId];
    if (slot == null) return;
    slot.generation++;
    await slot.serialize(slot.closeCurrent);
    _slots.remove(liveId);
    await _releaseAudioSessionIfIdle();
    _notify();
  }

  /// Closes every partner room. The primary room is untouched.
  Future<void> disconnectAll() async {
    final ids = _slots.keys.toList(growable: false);
    for (final id in ids) {
      await disconnect(id);
    }
  }

  Future<void> _acquireAudioSession() async {
    if (_holdsAudioSession) return;
    await LiveAudioSession.instance.acquire();
    _holdsAudioSession = true;
  }

  Future<void> _releaseAudioSessionIfIdle() async {
    if (!_holdsAudioSession || _slots.isNotEmpty) return;
    await LiveAudioSession.instance.release();
    _holdsAudioSession = false;
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(disconnectAll());
    super.dispose();
  }
}

/// One partner room and everything that belongs to it.
class _SecondarySlot {
  _SecondarySlot(this.liveId);

  final String liveId;

  Room? room;
  EventsListener<RoomEvent>? _listener;

  /// Bumped on every connect and disconnect so an in-flight operation can tell
  /// that it has been superseded.
  int generation = 0;
  bool connecting = false;

  Future<void> _queue = Future<void>.value();

  bool get isUsable =>
      room != null && room!.connectionState != ConnectionState.disconnected;

  Future<void> serialize(Future<void> Function() operation) {
    final result = _queue.then((_) => operation());
    // A failed connect must not block a later disconnect.
    _queue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  void adopt({required Room room, required EventsListener<RoomEvent> listener}) {
    this.room = room;
    _listener = listener;
  }

  /// Closes the room this slot owns right now, and nothing else.
  Future<void> closeCurrent() async {
    final current = room;
    final listener = _listener;
    room = null;
    _listener = null;
    if (listener != null) {
      try {
        await listener.dispose();
      } catch (_) {
        /* Already disposed. */
      }
    }
    if (current == null) return;
    try {
      await current.disconnect();
      await current.dispose();
    } catch (error) {
      debugPrint('Co-host room $liveId disconnect failed: $error');
    }
  }
}
