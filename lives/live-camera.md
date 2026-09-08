# Live camera

> Flip **front ↔ back** during a video LIVE. Dual / screen scene is P3.  
> Related: [mobile-api.md](./mobile-api.md) · [live-p3-parity.md](./live-p3-parity.md) · [events](../events/mobile-api.md) · [logic.md](./logic.md)

LiveKit already delivers the new frames after the publisher swaps the local track. The socket is **signaling** so viewers can mirror the tile or show a front/back badge.

**Persist (P3):** host facing is stored on `Live.cameraFacing`. Late joiners read it from `GET /lives/:id` → `scene.cameraFacing` (or `PATCH /lives/:id/scene`). The socket `switchLiveCamera` still works; when the **host** flips, the server now saves `cameraFacing`.

```http
PATCH /lives/:id/scene
{ "scene": "CAMERA|SCREEN|DUAL", "cameraFacing": "front|back", "dualCameraEnabled": true }
```

Socket `liveScene` after PATCH. `cameraFacing` also emits `liveCameraChanged`.

Voice Chat (`audioOnly`) does not use this file — there is no camera track.

---

## Who can emit

| Role | Allowed |
|------|---------|
| Host | Yes, while the live is `LIVE` |
| On-stage guest / co-host (`ACTIVE`) | Yes, unless `cameraOffByHost` or `allowGuestCamera: false` |
| Viewer | No |
| Guest who left / was kicked | No |

`userId` always comes from the authenticated socket session. Do not send it in the payload.

You must already be in the live HUD room (`joinLive`).

---

## Client → server

### `switchLiveCamera`

Emit **after** you have switched the local LiveKit camera (or in the same tick). Do not wait for the ack before swapping the track — media should stay instant.

```js
socket.emit('switchLiveCamera', {
  liveId: 'live-uuid',
  facing: 'front', // or 'back'
});
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `liveId` | string | yes | Same id as `joinLive` |
| `facing` | `"front"` \| `"back"` | yes | Case-insensitive; server normalizes to lowercase |

**Ack success**

```json
{
  "event": "liveCameraSwitched",
  "data": {
    "liveId": "live-uuid",
    "userId": "publisher-uuid",
    "facing": "front",
    "role": "host",
    "at": "2026-09-01T13:45:00.000Z"
  }
}
```

`role` is `"host"` \| `"guest"` \| `"co_host"`.

**Ack errors**

| Message | When |
|---------|------|
| `liveId is required` | Missing `liveId` |
| `facing must be "front" or "back"` | Missing or unknown facing |
| `Not authenticated` | Socket has no session user |
| `Join the live room first (joinLive)` | Did not `joinLive` this live |
| `Live not found` | Unknown or banned live |
| `Live is not currently broadcasting` | Status is not `LIVE` |
| `Only the host or an on-stage guest can switch camera` | Viewer / off-stage |
| `Camera is turned off by the host` | Guest `cameraOffByHost` |
| `Guest camera is not allowed on this live` | `allowGuestCamera: false` |

---

## Server → client

### `liveCameraChanged`

**Room:** `live_{liveId}` (everyone who called `joinLive`, including the publisher).

```json
{
  "liveId": "live-uuid",
  "userId": "publisher-uuid",
  "facing": "back",
  "role": "guest",
  "at": "2026-09-01T13:45:01.200Z"
}
```

Match `userId` to the LiveKit participant identity (it is the same user id).

You also receive this for **your own** switch. Treat it as idempotent.

---

## App flow

```
1. User taps flip camera
2. Swap the local LiveKit camera (front ↔ back)
3. socket.emit('switchLiveCamera', { liveId, facing })
4. Everyone in live_{id} gets liveCameraChanged
5. Viewers: if facing === 'front' → mirror that tile; if 'back' → no mirror
```

### Flutter (sketch)

```dart
Future<void> flipLiveCamera({
  required String liveId,
  required bool useFront,
}) async {
  await localParticipant.setCamera(facing: useFront ? CameraFacing.front : CameraFacing.back);
  socket.emit('switchLiveCamera', {
    'liveId': liveId,
    'facing': useFront ? 'front' : 'back',
  });
}

socket.on('liveCameraChanged', (data) {
  final userId = data['userId'] as String;
  final facing = data['facing'] as String; // front | back
  // Mirror the tile for this LiveKit identity when facing == 'front'
});
```

---

## What this is not

| Do not confuse with | Difference |
|---------------------|------------|
| `POST /lives/:id/guests/:userId/camera-off` / `camera-on` | Host **forces** a guest track off/on. Event is `liveGuestUpdate` (`camera_off` / `camera_on`). |
| LiveKit mute / unpublish | Media permission. Not a facing change. |
| Viewer “camera” | Viewers do not publish. This event is rejected for them. |

---

## Client checklist

1. After `joinLive`, listen for `liveCameraChanged`.
2. Only the **publishing** user emits `switchLiveCamera` (host or active guest).
3. Facing values are only `front` and `back`.
4. Use `userId` to pick the tile in a multi-guest grid.
5. Front camera: typically **mirror** the remote video. Back camera: do not mirror.
6. Host facing is stored (`scene.cameraFacing`). Guest facing is still socket-only until they emit again.

---

## Related

- Socket connect & rooms: [../events/mobile-api.md](../events/mobile-api.md)
- Guest mute / force camera: [mobile-api.md](./mobile-api.md#mute--camera-stage-av--not-chat)
- LiveKit publish: [mobile-api.md](./mobile-api.md#15-livekit-checklist)
- Scene / dual cam: [live-p3-parity.md](./live-p3-parity.md)
