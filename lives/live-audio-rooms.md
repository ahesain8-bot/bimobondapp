# LIVE Audio rooms — TikTok Voice Chat (full guide)

> **Audience:** Mobile + admin. Sound-only rooms: **no video tiles**.  
> Host + speakers publish **microphone**. Listeners subscribe and use chat / gifts / likes.  
> Related: [README.md](./README.md) · [endpoints2.md](./endpoints2.md) · [mobile-api.md](./mobile-api.md) · [P3 topic / tickets](./live-p3-parity.md) · [P1](./live-p1-parity.md) · [P2](./live-p2-parity.md)

TikTok name: **Voice Chat** / **LIVE Audio**. Same LIVE product (comments, gifts, raise-hand, end summary) without a camera.

**Migration:** `20260905180000_live_audio_rooms`

```bash
npx prisma generate
npx prisma migrate deploy
```

---

## 1. What this is

| | Video LIVE (`mediaMode: VIDEO`) | Voice Chat (`mediaMode: AUDIO`) |
|--|--|--|
| UI | Camera / grid tiles | Avatars + waveforms |
| Host publishes | Camera + mic (+ screen) | **Mic only** |
| Listener | Subscribe to video+audio | Subscribe to **audio** |
| Come on stage | Guest request (camera optional) | **Raise hand** → **speaker** (mic) |
| `allowGuestCamera` | Host setting | Forced `false` |
| `layout` | `GRID` default | Forced `PANEL` on create |
| Camera Studio | Load before go-live | `loadBeforeGoLive: false` |

Default is **VIDEO**. Mixed For You includes both, like TikTok.

---

## 2. Auth & enums

```http
Authorization: Bearer <Firebase ID token>
Content-Type: application/json
```

| Enum | Values |
|------|--------|
| `mediaMode` (stored) | `VIDEO` · `AUDIO` |
| Create / query aliases | `VOICE` · `SOUND` → stored as `AUDIO` |
| Guest `status` | `REQUESTED` · `INVITED` · `ACTIVE` · `LEFT` · `REJECTED` · `KICKED` |
| Guest `seat` (AUDIO only) | `HAND` = raised hand (`REQUESTED`) · `SPEAKER` = on mic (`ACTIVE`) · `null` otherwise |

---

## 3. Host — create / edit / start

### `POST /lives` (required)

```http
POST /lives
{
  "title": "Late night talk",
  "mediaMode": "AUDIO",
  "startNow": true,
  "coverUrl": "https://…/cover.jpg",
  "categoryId": "optional-uuid",
  "ageRestricted": false,
  "replayEnabled": true
}
```

| Field | Notes |
|-------|--------|
| `mediaMode` | `VIDEO` (default) · `AUDIO` · `VOICE` · `SOUND` |
| `startNow` | `true` → go live and return host **mic** token |
| Other fields | Same as video LIVE (title, cover, category, 18+, lat/lng, schedule) |

On AUDIO create the server also sets `allowGuestCamera: false` and `layout: PANEL`.

**Response (startNow):** same connect bundle as join (see §5) with `role: "host"`, `live.audioOnly: true`.

### `PATCH /lives/:id` (host)

`mediaMode` can change **only while `PLANNED`**. After `LIVE` → **400** `"Cannot switch VIDEO / AUDIO after the live has started"`.

Switching a planned room to AUDIO also sets `allowGuestCamera: false` and `layout: PANEL`.

### `POST /lives/:id/start` · `POST /lives/:id/end`

Same as video. Start issues an **audio-only** host token (no camera / screen grant).

### `GET /lives/:id/settings` · `PATCH /lives/:id/settings` (host)

Settings **echo** `mediaMode` + `audioOnly`. **PATCH settings cannot change `mediaMode`** — use `PATCH /lives/:id` before start.

```json
{
  "guestsEnabled": true,
  "guestRequestMode": "EVERYONE",
  "maxGuests": 8,
  "layout": "PANEL",
  "allowGuestCamera": false,
  "mediaMode": "AUDIO",
  "audioOnly": true
}
```

`maxGuests` (1–8) = max **speakers** besides the host.

### `GET /lives/:id/studio` (host)

Still exists. RTMP / Ingress is optional. In AUDIO, the **app token** is mic-only; do not publish a camera from the phone.

---

## 4. Discovery

| Method | Path | Auth | Why |
|--------|------|------|-----|
| `GET` | `/lives/audio` | optional | Voice Chat tab |
| `GET` | `/lives/feed?mediaMode=AUDIO` | optional | Same as `/audio` |
| `GET` | `/lives/feed?audioOnly=true` | optional | Same |
| `GET` | `/lives/feed?mediaMode=VIDEO` | optional | Camera LIVEs only |
| `GET` | `/lives/feed` | optional | Mixed For You (video + audio) |
| `GET` | `/lives/nearby?mediaMode=AUDIO` | optional | Nearby sound rooms (`lat`/`lng` required) |
| `GET` | `/lives/mine` | required | Host history (both modes) |
| `GET` | `/lives/:id` | optional | Card — includes `mediaMode` / `audioOnly` |

**Feed query (extra):** `mediaMode` = `VIDEO` \| `AUDIO` \| `VOICE` \| `SOUND`. `audioOnly=true` forces AUDIO. Other query fields unchanged (`page`, `limit`, `categoryId`, `followingOnly`, `latitude`, `longitude`, `nearby`, `radiusKm`).

Main mixed For You may still inject **promoted** lives (usually video). The **`/lives/audio` tab does not** — it filters `mediaMode=AUDIO` only.

### Card fields (every live)

```json
{
  "id": "…",
  "title": "Late night talk",
  "status": "LIVE",
  "mediaMode": "AUDIO",
  "audioOnly": true,
  "allowGuestCamera": false,
  "layout": "PANEL",
  "viewers": 42,
  "peakViewers": 80,
  "likeCount": 12,
  "coverUrl": "https://…",
  "user": { "id": "…", "username": "host", "avatarUrl": "…" }
}
```

**App:** if `audioOnly === true`, render a **room card** (avatar / cover / waveform). Do **not** attach a video renderer.

18+ / private / block rules are the same as video LIVE.

---

## 5. Join / listen

```http
POST /lives/:id/join
{ "trafficSource": "FOR_YOU" }
```

**Auth:** required. Live must be `LIVE`. Same 18+ / watch-access / ban checks as video.

| `role` | Who | LiveKit | App |
|--------|-----|---------|-----|
| `host` | Owner | Publish **mic** | No camera / screen |
| `viewer` | Listener | Subscribe only | Hear + chat + gift |
| `guest` / `co_host` | Accepted speaker | Publish **mic** | `guest.seat: "SPEAKER"` |

### Connect bundle (AUDIO)

```json
{
  "live": { "mediaMode": "AUDIO", "audioOnly": true, "layout": "PANEL" },
  "token": "eyJ…",
  "url": "wss://…",
  "role": "viewer",
  "guest": null,
  "mediaHints": {
    "role": "viewer",
    "canPublish": false,
    "audioOnly": true,
    "maxVideoResolution": null,
    "maxSubscribeResolution": null,
    "maxBitrateKbps": 0,
    "simulcast": false,
    "adaptiveStream": false,
    "dynacast": false
  },
  "studioHints": {
    "catalogPath": "/camera-studio/catalog",
    "loadBeforeGoLive": false
  }
}
```

If the listener is already an **ACTIVE** speaker, `role` is `guest` / `co_host`, `mediaHints.canPublish: true`, and:

```json
"guest": {
  "role": "GUEST",
  "status": "ACTIVE",
  "seat": "SPEAKER",
  "mutedByHost": false,
  "cameraOffByHost": true
}
```

`POST /lives/:id/leave` — same as video (closes watch session).

---

## 6. Raise hand → speaker

Guest routes are the same paths. In AUDIO they mean **hand / speaker**, not camera seats.

| Method | Path | Auth | Why |
|--------|------|------|-----|
| `GET` | `/lives/:id/guests` | optional | Hands + speakers. Each row has `seat` |
| `POST` | `/lives/:id/guests/request` | required | **Raise hand** (`REQUESTED` / `HAND`) |
| `POST` | `/lives/:id/guests/invite` | host/mod | Invite a user to speak `{ "userId" }` |
| `POST` | `/lives/:id/guests/accept-invite` | required | Invitee takes the mic |
| `POST` | `/lives/:id/guests/:userId/accept` | host/mod | Accept a raised hand → `SPEAKER` |
| `POST` | `/lives/:id/guests/:userId/reject` | host/mod | Decline hand |
| `POST` | `/lives/:id/guests/leave` | speaker | Leave the mic (back to listener) |
| `POST` | `/lives/:id/guests/token` | speaker | Refresh **mic** publish token |
| `POST` | `/lives/:id/guests/:userId/kick` | host/mod | Drop speaker |
| `POST` | `/lives/:id/guests/:userId/mute` | host/mod | Mute speaker mic |
| `POST` | `/lives/:id/guests/:userId/unmute` | host/mod | Unmute |
| `POST` | `/lives/:id/guests/:userId/promote` | host | Speaker → room `CO_HOST` (still mic-only) |
| `POST` | `/lives/:id/guests/:userId/demote` | host | Co-host → speaker |

### `GET /lives/:id/guests` row

```json
{
  "id": "…",
  "userId": "…",
  "role": "GUEST",
  "status": "REQUESTED",
  "seat": "HAND",
  "mutedByHost": false,
  "cameraOffByHost": false,
  "user": { "id": "…", "username": "fan", "avatarUrl": "…" }
}
```

| `status` | `seat` (AUDIO) |
|----------|----------------|
| `REQUESTED` | `HAND` |
| `ACTIVE` | `SPEAKER` |
| `INVITED` / others | `null` |

Host raising their own hand → **400** `"Host is already a speaker"`.

### Camera endpoints (do **not** call)

`POST /lives/:id/guests/:userId/camera-off` and `camera-on` → **400**  
`"Voice Chat rooms have no camera — mute the speaker instead"`

Paused host: raise-hand / start PK still blocked (same as P2).

Max speakers = `maxGuests` (default **8**). Stage full → **400**.

---

## 7. Chat, gifts, likes (unchanged)

| Method | Path | Notes |
|--------|------|--------|
| `POST` | `/lives/:id/like` | Hearts |
| `POST` | `/lives/:id/comments` | Chat |
| `GET` | `/lives/:id/comments` | History (works after end) |
| `POST` | `/gifts/send` | Body includes `liveId` |
| `GET` | `/lives/:id/leaderboard/gifters` | Top gifters |

---

## 8. What else still works

| Feature | AUDIO behavior |
|---------|----------------|
| Pause / resume | Same (`POST /lives/:id/pause`) |
| 18+ | Same (`ageRestricted` + viewer `dateOfBirth`) |
| Nearby | Filter with `mediaMode=AUDIO` |
| Replay / clips | Same routes; file is usually audio/composite. Host can `POST /replay` |
| Post-live | `GET /lives/:id/summary` — viewers, comments, gifts, watch time |
| Who listened | `GET /lives/:id/viewers?activeOnly=false` after end |
| Shop / fan club / promote | Same modules |
| PK (1v1 / 2v2) | Allowed — scores from **gifts/likes**. No video tiles |
| Host-to-host co-host | Allowed; each AUDIO room still issues **mic-only** tokens |
| Report / share / remind | Same |

`PATCH /lives/:id/look` is ignored by the audio UI (no camera track).

---

## 9. Admin

| Method | Path | Permission | Why |
|--------|------|------------|-----|
| `GET` | `/lives/admin/all?mediaMode=AUDIO` | `lives.admin.read` | List Voice Chat rooms |
| `GET` | `/lives/admin/:id` | read | Card includes `mediaMode` / `audioOnly` |
| `GET` | `/lives/admin/:id/summary` | read | Same post-live report |

Other admin end / ban / mute / kick routes work on audio rooms.

---

## 10. Errors

| Status | When |
|--------|------|
| `400` | Switch VIDEO/AUDIO after start |
| `400` | Camera on/off in an AUDIO room |
| `400` | Host raises hand |
| `400` | Speaker seats full (`maxGuests`) |
| `400` | Raise hand while host is paused |
| `403` | 18+ without DOB; private host; watch-access |
| `404` | Banned / missing live |

---

## 11. Sockets

Same rooms: `live_<liveId>`, `user_<userId>`.

| Event | Use in Voice Chat |
|-------|-------------------|
| `liveViewers` | Listener count |
| `liveComment` · `liveLike` · `liveGift` | Chat HUD |
| `liveGuest` | Hand raised / speaker accepted / muted / kicked |
| `livePaused` · `liveEnded` | Pause / leave room |
| `liveBattle` | PK scores if you run battles |

No video: ignore `liveLook` / `liveCameraChanged` / Camera Studio.

---

## 12. Screen mapping

| Screen | Endpoints |
|--------|-----------|
| Go LIVE → **Voice Chat** | `POST /lives` `{ "mediaMode": "AUDIO", "startNow": true }` |
| Voice tab | `GET /lives/audio` |
| Mixed For You | `GET /lives/feed` — branch on `audioOnly` |
| Nearby voice | `GET /lives/nearby?mediaMode=AUDIO&latitude=&longitude=` |
| Room (listen) | `GET /lives/:id` → `POST /lives/:id/join` |
| Raise hand | `POST /lives/:id/guests/request` |
| Speakers / hands | `GET /lives/:id/guests` |
| Host accept / mute / kick | guests `accept` / `mute` / `kick` |
| End screen | `POST /lives/:id/end` → `GET /lives/:id/summary` |

---

## 13. App checklist

- [ ] Go LIVE sheet: **Video** vs **Voice Chat** (`mediaMode`)
- [ ] Voice tab: `GET /lives/audio`
- [ ] Mixed feed: `audioOnly` → room card, not video player
- [ ] Join: if `mediaHints.audioOnly`, publish **microphone only** (host/speaker)
- [ ] Listeners: never publish
- [ ] Raise hand = `POST /guests/request`; speakers = `seat === "SPEAKER"`
- [ ] Host HUD: accept / mute / kick — **hide camera controls**
- [ ] Skip Camera Studio when `studioHints.loadBeforeGoLive === false`
- [ ] After end: summary + `viewers?activeOnly=false` (who listened)

---

## Related

- All LIVE routes: [endpoints2.md](./endpoints2.md)
- Video LIVE: [mobile-api.md](./mobile-api.md)
- Pause / 4-host / PK: [live-p2-parity.md](./live-p2-parity.md)
- Topic / tickets / games: [live-p3-parity.md](./live-p3-parity.md)
- Index: [README.md](./README.md)
