# Debug Session — live-viewer-perf [OPEN]

**Date**: 2026-08-16  
**Session ID**: live-viewer-perf  
**Scope**: TikTok-style Live viewer — 3 bugs:
1. Video stuttering / choppy playback
2. Blurry / poor video quality
3. Stream continues after leaving screen (lifecycle leak)

---

## 🔬 Step 1 — Hypotheses (Falsifiable)

### H1: Video renderer recreated on every Riverpod event
**Prediction**: Every comment/like/gift/participant Riverpod change triggers full `LiveRoomPage` rebuild → new `VideoRenderer` widget attached → remote track detached/reattached → frame drops / stutter.

**Observable**: `build()` count of `LiveVideoPlayer` >> number of remote participant events.

---

### H2: LiveKit room not disconnected on leave (lifecycle leak)
**Prediction**: `dispose()` of `LiveRoomPage` does NOT call `room.disconnect()` / `remoteTrack.stop()` / `renderer.dispose()`. Provider (`activeLiveProvider`) is long-lived and keeps the WebRTC peer connection + socket + audio open.

**Observable**: After Navigator.pop, `onDisconnected` callback never fires; audio continues; second join creates second peer connection.

---

### H3: Host is publishing with wrong bitrate/FPS + simulcast disabled
**Prediction**: `VideoParameters` are QVGA/VGA 15fps with bitrate too low; no simulcast layers; dynacast off; Android uses MediaCodec fallback.

**Observable**: `VideoPreset` resolution <= 480x360; fps <= 15; `simulcast = false`.

---

### H4: Viewer subscribes to lowest simulcast layer permanently
**Prediction**: `setVideoQuality` / `selectPreferredVideoLayer` is never called OR adaptive stream subscription always picks `LOW`.

**Observable**: Remote track dimensions always QVGA; no MID/high-layer packets in ICE stats.

---

### H5: High-frequency UI events (likes/gifts/comments) cause expensive rebuilds on main thread
**Prediction**: `setState(() {})` + `ref.watch(...)` in root of LiveRoomPage rebuilds entire tree (comments, floating gifts, floating hearts) on every socket event blocking raster thread.

**Observable**: Number of `_LiveRoomPageState.build()` calls correlates directly with number of socket comment/like events, not with video events.

---

## 🧭 Step 2 — Investigation Plan (Files to read, order)

1. `lib/features/live_viewer/presentation/widgets/live_room_page.dart` — full build method, lifecycle, dispose
2. `lib/features/live_viewer/presentation/providers/live_session_provider.dart` — activeLiveProvider lifecycle
3. `lib/features/live_viewer/presentation/widgets/live_video_player.dart` — renderer creation
4. `lib/features/live_viewer/data/services/real_livekit_service.dart` + `fake_livekit_service.dart` — LiveKit connect/disconnect/publish
5. `lib/features/live/presentation/pages/live_room_page.dart` — host publish config
6. `lib/features/live_viewer/presentation/providers/live_dependencies.dart` — provider lifecycles
7. `lib/features/live_viewer/data/services/real_socket_service.dart` + `fake_socket_service.dart` — socket cleanup
8. `lib/features/live_viewer/presentation/screens/live_feed_screen.dart` — navigation/dispose

---

## 📝 Step 3 — Evidence Table (to fill)

| Hypothesis | Status | Evidence Log |
|---|---|---|
| H1 | PENDING | |
| H2 | PENDING | |
| H3 | PENDING | |
| H4 | PENDING | |
| H5 | PENDING | |

---

## 🔧 Step 4 — Instrumentation Locations (TBD after Phase 1–4)

Will add to:
- `live_room_page.dart` — initState / dispose / build counter
- `live_video_player.dart` — renderer create/attached/firstFrame/dispose
- `live_session_provider.dart` — connect/disconnect/track events
- `real_livekit_service.dart` — room events

---

## 🛠️ Step 5 — Fixes (TBD after evidence)

**Status**: No fixes applied yet.

---

## 📋 Step 6 — Modified Files (Final)

_None yet._
