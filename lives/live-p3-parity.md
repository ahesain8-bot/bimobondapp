# LIVE P3 parity (not-in-API extras + profile LIVE)

> Dual camera / scene, **ticketed entry**, **official games**, **LIVE House**, **audio topic**, server-side clip cut, and **“host is LIVE”** on the profile.  
> Related: [README.md](./README.md) · [live-p2-parity.md](./live-p2-parity.md) · [live-audio-rooms.md](./live-audio-rooms.md) · **[endpoints2.md](./endpoints2.md)** · [production.md](./production.md)

P0–P2 stay as they are. Camera facing used to be socket-only; it is now persisted (and `PATCH /scene` exists).

---

## 1. Scene / dual camera

```http
PATCH /lives/:id/scene
{ "scene": "CAMERA|SCREEN|DUAL", "cameraFacing": "front|back", "dualCameraEnabled": true }
```

Host only. Persists on the live. Socket `liveScene`. Changing `cameraFacing` also emits the existing `liveCameraChanged`.

The socket `switchLiveCamera` event still works; the host facing is now **saved** on `Live.cameraFacing`.

Live card includes:

```json
{
  "scene": { "scene": "DUAL", "cameraFacing": "front", "dualCameraEnabled": true }
}
```

---

## 2. Ticketed / paid entry

Create or settings:

```json
{ "ticketEnabled": true, "ticketPriceCoins": 100 }
```

```http
GET  /lives/:id/ticket
POST /lives/:id/ticket
```

`POST` charges coins **80% host / 20% platform** (`LIVE_TICKET` / `LIVE_TICKET_REVENUE`). Host does not need a ticket.

**Join is 403** if `ticketEnabled` and the viewer has not paid. Buy first, then `POST /lives/:id/join`.

---

## 3. Official LIVE games

```http
GET  /lives/games/catalog
POST /lives/:id/games          { "type": "QUIZ|WHEEL|LUCKY_DRAW", … }
GET  /lives/:id/games/active
POST /lives/:id/games/:gameId/play
POST /lives/:id/games/:gameId/end
```

One `ACTIVE` game per live. Quiz hides `correctIndex` until the host ends. Socket `liveGame`.

| Type | Start body | Play body |
|------|------------|-----------|
| `QUIZ` | `question`, `options[]`, `correctIndex` | `optionIndex` |
| `WHEEL` | `prizes[]` (≥ 2) | — (server picks) |
| `LUCKY_DRAW` | — | — (random score; highest wins on end) |

---

## 4. LIVE House (multi-room venue)

```http
POST   /lives/houses                 { "title": "Friday campus" }
GET    /lives/houses
GET    /lives/houses/:houseId
POST   /lives/houses/:houseId/rooms  { "liveId": "…" }
PATCH  /lives/houses/:houseId        (close)
```

Host attaches **their own** lives as rooms. Feed cards expose `houseId`. Socket `liveHouse`.

---

## 5. Audio topic / scheduled radio

`topic` on `POST /lives`, `PATCH /lives/:id`, and `PATCH /lives/:id/settings` (max 80 chars).

Filter: `GET /lives/feed?topic=late%20night` or `GET /lives/audio?topic=…`.

---

## 6. Server-side clip cut

`POST /lives/:id/clips` still needs a READY replay. Outside tests the API runs **ffmpeg** (`FFMPEG_PATH` or `ffmpeg` on PATH) and writes `/uploads/clips/{id}.mp4`. If ffmpeg is missing, `clipUrl` falls back to the full replay URL.

---

## 7. “Host is LIVE” on profile (highest value)

`GET /users/:id` and `GET /auth/me` now include:

```json
{
  "isLive": true,
  "currentLive": {
    "id": "…",
    "title": "Late night",
    "coverUrl": null,
    "viewers": 42,
    "mediaMode": "VIDEO",
    "audioOnly": false
  }
}
```

Also on a **locked** private profile (so the LIVE badge can show). `currentLive` is `null` when the user is not `LIVE`.

---

## 8. Ingress + Egress workers

The API already creates Ingress (RTMP) and Egress (record) via LiveKit. Compose now runs the workers:

```bash
docker compose up -d postgres redis livekit livekit-ingress livekit-egress
```

RTMP is `1935`. LiveKit yaml includes Redis so Ingress/Egress can subscribe. See [production.md](./production.md).

---

## Sockets

| Event | When |
|-------|------|
| `liveScene` | Host PATCH scene |
| `liveCameraChanged` | Facing change (API or socket) |
| `liveTicket` | Viewer bought a ticket |
| `liveGame` | Game started / play / ended |
| `liveHouse` | Room attached or house closed |
