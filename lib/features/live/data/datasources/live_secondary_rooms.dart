import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/services/live_audio_session.dart';
import '../../../../core/utils/livekit_participant_match.dart';
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
  LiveSecondaryRooms({
    int maxRooms = 3,
    Room Function()? roomFactory,
    Future<void> Function()? acquireAudioSession,
    Future<void> Function()? releaseAudioSession,
  }) : _maxRooms = maxRooms,
       _roomFactory = roomFactory ?? _newRoom,
       _acquireAudio = acquireAudioSession ?? LiveAudioSession.instance.acquire,
       _releaseAudio = releaseAudioSession ?? LiveAudioSession.instance.release;

  final Room Function() _roomFactory;
  final Future<void> Function() _acquireAudio;
  final Future<void> Function() _releaseAudio;

  static Room _newRoom() => Room(
    roomOptions: const RoomOptions(adaptiveStream: false, dynacast: false),
  );

  /// A room plus three partners is the documented ceiling.
  final int _maxRooms;

  final Map<String, _SecondarySlot> _slots = {};
  var _holdsAudioSession = false;
  var _disposed = false;
  var _syncGeneration = 0;
  var _roomCount = 0;
  Future<void> _audioQueue = Future<void>.value();
  Future<void> _cleanupQueue = Future<void>.value();

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

  /// Only a camera published by the partner host is eligible; a guessed first
  /// participant is never an identity source.
  ///
  /// [hostIdentity] is an exact LiveKit identity and wins when the payload
  /// carries one. The documented `cohosts[]` envelope instead carries
  /// `host: { id }` — the backend user id (`lives/live-p2-parity.md` §2) — so
  /// [hostId] is resolved with [liveKitParticipantMatches], the same matcher
  /// the primary room and the viewer stage already use for guest cameras.
  /// With neither value the tile waits rather than rendering a stranger.
  RemoteVideoTrack? videoTrackFor(
    String liveId, {
    String? hostIdentity,
    String? hostId,
  }) {
    final identity = hostIdentity?.trim() ?? '';
    final userId = hostId?.trim() ?? '';
    if (identity.isEmpty && userId.isEmpty) return null;
    final room = roomFor(liveId);
    if (room == null) return null;
    for (final participant in room.remoteParticipants.values) {
      final matches = identity.isNotEmpty
          ? participant.identity == identity
          : liveKitParticipantMatches(participant, userId);
      if (!matches) continue;
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track is RemoteVideoTrack &&
            publication.subscribed &&
            !publication.muted &&
            publication.source == TrackSource.camera) {
          return track;
        }
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
    final syncGeneration = ++_syncGeneration;
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
      if (_disposed || syncGeneration != _syncGeneration) return;
      await _disconnect(id);
    }

    for (final entry in wanted.entries) {
      if (_disposed || syncGeneration != _syncGeneration) return;
      final existing = _slots[entry.key];
      // A token refresh for a room we already hold is not a reason to tear the
      // tile down; only a different room or a dead connection is.
      if (existing != null &&
          existing.matches(entry.value) &&
          (existing.isUsable || existing.connecting)) {
        continue;
      }
      await _connect(entry.value);
    }
  }

  /// Connects one partner room. Safe to call again for the same live id: the
  /// previous connection for that id is closed first, and only by this slot.
  Future<void> connect(LiveCohostRoom target) {
    _syncGeneration++;
    return _connect(target);
  }

  Future<void> _connect(LiveCohostRoom target) async {
    if (_disposed || !target.isConnectable) return;
    if (!_slots.containsKey(target.liveId) && _slots.length >= _maxRooms) {
      return;
    }
    final slot = _slots.putIfAbsent(
      target.liveId,
      () => _SecondarySlot(target.liveId),
    );
    final generation = ++slot.generation;
    slot.target = target;
    slot.connecting = true;
    await slot.serialize(() async {
      if (_disposed || generation != slot.generation) return;
      await slot.closeCurrent();
      if (_disposed || generation != slot.generation) return;
      slot.connecting = true;
      _notify();
      Room? room;
      EventsListener<RoomEvent>? listener;
      try {
        await _acquireAudioSession();
        if (_disposed || generation != slot.generation) return;
        room = _roomFactory();
        _roomCount++;
        listener = room.createListener();
        void changed() {
          if (identical(slot.room, room) && generation == slot.generation) {
            _notify();
          }
        }

        listener
          ..on<RoomDisconnectedEvent>((_) => changed())
          ..on<RoomReconnectingEvent>((_) => changed())
          ..on<RoomReconnectedEvent>((_) => changed())
          ..on<ParticipantConnectedEvent>((_) => changed())
          ..on<ParticipantDisconnectedEvent>((_) => changed())
          ..on<TrackPublishedEvent>((_) => changed())
          ..on<TrackUnpublishedEvent>((_) => changed())
          ..on<TrackSubscribedEvent>((_) => changed())
          ..on<TrackUnsubscribedEvent>((_) => changed())
          ..on<TrackMutedEvent>((_) => changed())
          ..on<TrackUnmutedEvent>((_) => changed());
        await room.connect(target.url, target.token);
        if (_disposed || generation != slot.generation) return;
        slot.adopt(room: room, listener: listener);
      } catch (_) {
        // Connection exceptions can contain URLs or credential fragments.
        debugPrint('Secondary LiveKit connection failed');
      } finally {
        if (generation == slot.generation) {
          slot.connecting = false;
          if (slot.room == null && identical(_slots[target.liveId], slot)) {
            _slots.remove(target.liveId);
          }
        }
        if (room != null && !identical(slot.room, room)) {
          await _cleanup(
            () => _SecondarySlot.closeResources(room, listener),
            hasRoom: true,
          );
        }
        await _releaseAudioSessionIfIdle();
        _notify();
      }
    });
  }

  /// Detach ownership before awaiting cleanup so reconnect gets a new slot.
  Future<void> disconnect(String liveId) {
    _syncGeneration++;
    return _disconnect(liveId);
  }

  Future<void> _disconnect(String liveId) async {
    final slot = _slots.remove(liveId);
    if (slot == null) return;
    slot.generation++;
    _notify();
    await slot.serialize(
      () => _cleanup(slot.closeCurrent, hasRoom: slot.room != null),
    );
    _notify();
  }

  /// Closes only the slots held when this call starts, including in-flight
  /// connects. A later reconnect belongs to the subsequent caller.
  Future<void> disconnectAll() async {
    _syncGeneration++;
    final ids = _slots.keys.toList(growable: false);
    await Future.wait(ids.map(_disconnect));
  }

  // Serialize final cleanup so simultaneous closes hand the audio lease back
  // before the last Room teardown, not after every SDK room has already gone.
  Future<void> _cleanup(
    Future<void> Function() close, {
    required bool hasRoom,
  }) {
    final result = _cleanupQueue.then((_) async {
      try {
        try {
          await _releaseAudioSessionIfIdle(finalClose: hasRoom);
        } finally {
          await close();
        }
      } finally {
        if (hasRoom) _roomCount--;
        await _releaseAudioSessionIfIdle();
      }
    });
    _cleanupQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<void> _serializeAudio(Future<void> Function() operation) {
    final result = _audioQueue.then((_) => operation());
    _audioQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<void> _acquireAudioSession() => _serializeAudio(() async {
    if (_holdsAudioSession) return;
    await _acquireAudio();
    _holdsAudioSession = true;
  });

  Future<void> _releaseAudioSessionIfIdle({bool finalClose = false}) =>
      _serializeAudio(() async {
        if (!_holdsAudioSession ||
            _slots.isNotEmpty ||
            _roomCount > (finalClose ? 1 : 0)) {
          return;
        }
        await _releaseAudio();
        _holdsAudioSession = false;
      });

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
  LiveCohostRoom? target;

  bool matches(LiveCohostRoom other) =>
      target?.url == other.url && target?.roomName == other.roomName;

  Future<void> _queue = Future<void>.value();

  bool get isUsable =>
      room != null && room!.connectionState != ConnectionState.disconnected;

  Future<void> serialize(Future<void> Function() operation) {
    final result = _queue.then((_) => operation());
    // A failed connect must not block a later disconnect.
    _queue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  void adopt({
    required Room room,
    required EventsListener<RoomEvent> listener,
  }) {
    this.room = room;
    _listener = listener;
  }

  /// Closes the room this slot owns right now, and nothing else.
  Future<void> closeCurrent() async {
    final current = room;
    final listener = _listener;
    room = null;
    _listener = null;
    await closeResources(current, listener);
  }

  static Future<void> closeResources(
    Room? current,
    EventsListener<RoomEvent>? listener,
  ) async {
    try {
      await listener?.dispose();
    } catch (_) {
      debugPrint('Secondary listener cleanup failed');
    }
    if (current == null) return;
    try {
      await current.disconnect();
    } catch (_) {
      debugPrint('Secondary room disconnect failed');
    } finally {
      try {
        await current.dispose();
      } catch (_) {
        debugPrint('Secondary room disposal failed');
      }
    }
  }
}
