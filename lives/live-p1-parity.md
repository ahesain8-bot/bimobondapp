# LIVE P1 parity (TikTok feel)

> What this build adds so LIVE feels closer to TikTok: **OBS / LIVE Studio RTMP**, **auto-record replay**, **Nearby**, **18+ gate**, **clips → post**, **host-to-host co-host**, and **2v2 team PK** (join / invite empty slots + scoring modes).  
> Related: [README.md](./README.md) · [live-p0-parity.md](./live-p0-parity.md) · [live-p2-parity.md](./live-p2-parity.md) · [live-p3-parity.md](./live-p3-parity.md) · [live-audio-rooms.md](./live-audio-rooms.md) · **[endpoints2.md](./endpoints2.md)**

P0 (replay publish, report, shop bag, paid fan club, post-live stats) is unchanged. Hosts can still `POST /lives/:id/replay` if Egress is not configured.

---

## 1. RTMP / LIVE Studio

On `POST /lives/:id/start` the server tries to create a LiveKit **Ingress**. Missing LiveKit Ingress does **not** fail go-live.

Host-only (never on public `GET /lives/:id`):

```http
GET /lives/:id/studio
```

```json
{
  "rtmpUrl": "rtmp://livekit.example/live",
  "streamKey": "…",
  "ingressId": "IN_…",
  "recording": { "status": "RECORDING", "egressId": "EG_…", "autoRecord": true },
  "screenShare": { "canPublish": true }
}
```

`streamKey` is also on the host **start/join** payload as `studio`. Paste `rtmpUrl` + `streamKey` into OBS / LIVE Studio. Host and co-host tokens can publish `SCREEN_SHARE`.

---

## 2. Auto-record (Egress)

If `replayEnabled` is true (default), start also tries LiveKit **Room Composite Egress**. Failures log and continue.

Statuses: `NONE` → `STARTING` → `RECORDING` → `READY` | `FAILED`.

Public live object only exposes:

```json
"recording": { "status": "RECORDING" }
```

When Egress finishes, webhook `POST /lives/webhooks/livekit` (`egress_ended`) sets `replayUrl` + `replayStatus: READY` (90-day TTL) if a public file URL is available.

Env (optional — skip S3 and the recording stays local to the Egress worker):

| Variable | Use |
|----------|-----|
| `LIVEKIT_EGRESS_S3_BUCKET` | Upload bucket |
| `LIVEKIT_EGRESS_S3_ACCESS_KEY` | Access key |
| `LIVEKIT_EGRESS_S3_SECRET` | Secret |
| `LIVEKIT_EGRESS_S3_REGION` | Region |
| `LIVEKIT_EGRESS_PUBLIC_BASE` | Prefix used when the webhook only returns a filename |

Manual `POST /lives/:id/replay` still works as a fallback.

---

## 3. Nearby

Host opts in by sending coords on create / update / settings:

```http
POST /lives
{ "title": "Night market", "latitude": 30.0444, "longitude": 31.2357 }
```

```http
GET /lives/nearby?latitude=30.05&longitude=31.24&radiusKm=50
```

Same as `GET /lives/feed?nearby=true&latitude=&longitude=`. Default radius **50 km**, max **150**. Sorted by distance. **No promote inject** (organic geo only). Each row includes `distanceKm`.

Each live includes `location: { latitude, longitude }` when set.

---

## 4. Age / sensitive LIVE

```http
POST /lives
{ "title": "Late night", "ageRestricted": true }
```

Join and `GET /lives/:id` require the viewer’s `User.dateOfBirth` to be **18+**. Missing DOB is blocked. Host can always open their own room. Public payload: `ageRestricted: true`.

---

## 5. Clips → For You post

Needs a **READY** replay (Egress or host publish). No server-side ffmpeg cut — the clip stores start/end on the replay URL (or an optional `clipUrl` the app already uploaded).

```http
POST /lives/:id/clips
{ "startSeconds": 42, "endSeconds": 58, "title": "This bit" }

GET /lives/:id/clips

POST /lives/:id/clips/:clipId/post
{ "description": "From tonight’s LIVE" }
```

Creates a `Post` (`type: VIDEO`) and marks the clip `POSTED`. Calling post again is idempotent (`alreadyPosted: true`).

---

## 6. Multi-room co-host

This is **two live hosts tiling rooms**, not promoting a guest to `CO_HOST`.

```http
GET /lives/:id/cohost/hosts
POST /lives/:id/cohost/invite
{ "guestLiveId": "…" }

POST /lives/:id/cohost/:sessionId/accept
POST /lives/:id/cohost/:sessionId/end
GET /lives/:id/cohost
```

Statuses: `INVITED` → `ACTIVE` | `DECLINED` | `ENDED`. Socket `liveCohost` on both rooms.

Join/start may include `cohost`:

```json
{
  "liveId": "partner-live-id",
  "roomName": "live_…",
  "token": "…",
  "url": "wss://…",
  "role": "viewer",
  "host": { "id": "…", "username": "…" }
}
```

Connect a **second** LiveKit room with that subscribe token (`identity` is `${viewerId}__cohost`). Tile the two videos. Ending a live ends open sessions.

---

## 7. 2v2 team PK (join + scoring)

Start a **2v2 lobby** with just the two captains. Teammate slots stay open until someone joins or a captain invites. You do **not** need all four lives at create time.

```http
POST /lives/:id/battle
```

```json
{
  "opponentLiveId": "…",
  "mode": "TEAM",
  "scoringMode": "ALL"
}
```

Optional at create: `teammateLiveId` (sits with you) and `opponentTeammateLiveId` (sits with them).

| Who | Live IDs |
|-----|----------|
| Team 1 | `live1Id` captain + `live3Id` teammate |
| Team 2 | `live2Id` captain + `live4Id` teammate |

```http
GET  /lives/:id/battle/open-teams
POST /lives/:yourLiveId/battle/:battleId/join      { "team": 1 }
POST /lives/:captainLiveId/battle/:battleId/invite { "teammateLiveId": "…" }
POST /lives/:teammateLiveId/battle/:battleId/leave
POST /lives/:id/battle/match                       { "mode": "TEAM" }
```

| Call | Who | Effect |
|------|-----|--------|
| `join` `{ "team": 1 }` | Another **LIVE** host | Fills team 1 (`live3`). `team: 2` fills `live4`. Omit `team` → first open slot |
| `invite` | Captain of live1 or live2 | Pulls that live onto **their** team |
| `leave` | Teammate only | Clears the slot. Captains `end` the battle instead |
| `open-teams` | Any LIVE host not already in a PK | Lobbies with `openSlots` |
| `match` `{ "mode": "TEAM" }` | Host | Auto-picks an opponent and opens a 2v2 lobby |

Joiner must be the host of `:yourLiveId`, that live must be `LIVE`, and they cannot already be in an ACTIVE battle. Solo (`mode` omitted) is still 1v1.

Battle object extras:

```json
{
  "mode": "TEAM",
  "live1Id": "…",
  "live2Id": "…",
  "live3Id": "…",
  "live4Id": null,
  "teams": {
    "team1": { "captainLiveId": "…", "teammateLiveId": "…" },
    "team2": { "captainLiveId": "…", "teammateLiveId": null }
  },
  "openSlots": [2],
  "live1Score": 40,
  "live2Score": 12,
  "likeScore1": 3,
  "likeScore2": 1
}
```

Socket `liveBattle` on **all** rooms in the battle:

- `type: "started"` — lobby opened
- `type: "roster"` — `{ joinedLiveId, team }` or `{ leftLiveId }`
- `type: "score"` / `type: "finished"` — same as 1v1

| `scoringMode` | What counts |
|---------------|-------------|
| `ALL` (default) | Gifts + likes |
| `GIFTS` | Gift coins only |
| `LIKES` | Heart taps only |
| `SPECIFIC_GIFT` | Only `scoringGiftId` |

Team scores still live on `live1Score` / `live2Score` (teammate gifts/likes count for their team). Likes also increment `likeScore1` / `likeScore2`.

---

## App checklist

1. After start, if `studio.streamKey` is present, show **Go live from OBS** (RTMP URL + key). Enable screen share publish for host.
2. Poll `recording.status` or wait for replay `READY` after end. Keep manual replay upload as fallback.
3. Nearby tab: send device lat/lng. Do not expect ads in that list.
4. If `ageRestricted`, collect DOB before join; show 18+ chrome.
5. After replay is ready: trim UI → `POST /clips` → `POST …/post` to land on For You.
6. Co-host: invite another **live** host, then subscribe to `cohost` as a second room — do not reuse guest-seat promote.
7. PK: start `mode: TEAM` as a 2v2 lobby, then invite/join into `openSlots`. Bind `teams.team1` / `teams.team2` on the HUD. Socket `liveBattle` type `roster` when a teammate joins or leaves.

## Settings (host)

```http
GET   /lives/:id/settings
PATCH /lives/:id/settings
PATCH /lives/:id
```

| Field | What it does |
|-------|----------------|
| `ageRestricted` | 18+ gate on join / detail. Hidden from For You / Nearby unless the viewer has DOB ≥ 18 |
| `latitude` + `longitude` | Opt into Nearby. Both required (or send `null` to clear) |
| `replayEnabled` | Auto-record on go-live. Toggling while LIVE starts/stops Egress |

Viewer DOB: `PATCH /users/me` `{ "dateOfBirth": "2005-01-01" }`. Missing DOB = cannot watch 18+ lives.

## Ops (RTMP + auto-record)

API code is in. Compose now starts Ingress + Egress (see [production.md](./production.md)):

```bash
docker compose up -d postgres redis livekit livekit-ingress livekit-egress
```

1. `livekit-ingress` (RTMP 1935) — otherwise `GET /lives/:id/studio` `streamKey` stays null
2. `livekit-egress` + Redis on the LiveKit server — otherwise `recording.status` is `FAILED` and the host must `POST /lives/:id/replay`
3. Nest env: `LIVEKIT_EGRESS_S3_*` + `LIVEKIT_EGRESS_PUBLIC_BASE` (see `.env.production.example`)
4. Webhook already handles `egress_ended` at `POST /lives/webhooks/livekit`
5. `npx prisma migrate deploy` for P1–P3 columns/tables

Apply DB:

```bash
npx prisma generate
npx prisma migrate deploy
```
