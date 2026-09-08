# Lives — Mobile / App Developer Guide

> **Audience:** mobile & web app developers integrating TikTok-style LIVE.  
> **Base path:** `/lives`  
> Architecture: [logic.md](./logic.md) · Endpoints Ref: [endpoints.md](./endpoints.md) · **All routes + why:** [endpoints2.md](./endpoints2.md) · **Voice Chat / audio rooms:** [live-audio-rooms.md](./live-audio-rooms.md) · Tasks: [tasks.md](./tasks.md) · Database: [database.md](./database.md) · Admin ops: [admin-api.md](./admin-api.md) · Production & testing: [production.md](./production.md) · **Enhanced performance:** [enhanced-live-performance.md](./enhanced-live-performance.md) · **Viewer count changes (27 Aug 2026):** [changes.md](./changes.md) · **Live camera (front/back):** [live-camera.md](./live-camera.md) · **Live promotions (TikTok promote):** [live-promotions.md](./live-promotions.md) · **P1 (RTMP / Nearby / clips / co-host / team PK):** [live-p1-parity.md](./live-p1-parity.md) · **P2 (pause / 4-host / BO3):** [live-p2-parity.md](./live-p2-parity.md) · **P3 (tickets / games / house / scene / profile LIVE):** [live-p3-parity.md](./live-p3-parity.md) · Conventions: [../_shared/conventions.md](../_shared/conventions.md)

---

## Table of contents

1. [What you use (and for what)](#1-what-you-use-and-for-what)
2. [Auth & headers](#2-auth--headers)
3. [Core concepts](#3-core-concepts)
4. [End-to-end flows (do this)](#4-end-to-end-flows-do-this)
5. [Live object reference](#5-live-object-reference)
6. [Host APIs](#6-host-apis)
7. [Discovery APIs](#7-discovery-apis)
8. [Watch & engagement APIs](#8-watch--engagement-apis)
9. [Host/mod moderation APIs](#9-hostmod-moderation-apis)
10. [Multi-guest APIs](#10-multi-guest-apis)
11. [Live moderators APIs](#11-live-moderators-apis)
12. [Battles (PK) APIs](#12-battles-pk-apis)
13. [Interactive Tools & Engagement APIs](#13-interactive-tools--engagement-apis)
14. [Live shopping (auctions)](#14-live-shopping-auctions)
15. [Gifts during a live](#15-gifts-during-a-live)
16. [LiveKit checklist](#16-livekit-checklist)
17. [Socket.IO checklist](#17-socketio-checklist)
18. [Endpoint index](#18-endpoint-index)
19. [Hourly Ranking, Gallery, Fan Clubs & Leagues](#19-hourly-ranking-gallery-fan-clubs--leagues)
20. [Errors](#20-errors)
21. [Gifter Level Badges (`Lv. X`)](#21-gifter-level-badges-lv-x)
22. [Related docs](#22-related-docs)

---



## 1. What you use (and for what)

Lives are **three systems**. Use the right one for each job:


| System                                | What it is      | Your app uses it for                                                                         |
| ------------------------------------- | --------------- | -------------------------------------------------------------------------------------------- |
| **Nest HTTP** (`/lives`, `/gifts`, …) | Source of truth | Create/start/end, join/leave, comments, likes, guests, battles, auctions, gifts, moderation  |
| **LiveKit**                           | A/V media (SFU) | Camera/mic publish (host/guest) and subscribe (viewers)                                      |
| **Socket.IO**                         | Realtime HUD    | Comments, gifts, viewer count, guest updates, battle score, auctions, moderation, live ended |


```
┌─────────────┐     JWT token      ┌──────────┐
│  Your app   │ ─────────────────► │ LiveKit  │  ← video / audio only
└──────┬──────┘                    └──────────┘
       │
       │ REST (authority + money)
       ▼
┌─────────────┐     emit events    ┌──────────┐
│ Nest + DB   │ ─────────────────► │ Socket.IO│  ← chat / gifts / HUD
└─────────────┘                    └──────────┘
```

**Rules of thumb**


| Want to…                 | Do this                                                                |
| ------------------------ | ---------------------------------------------------------------------- |
| Start broadcasting       | `POST /lives` → LiveKit **publish** with returned `token`/`url`/`mediaHints` |
| Watch a stream           | `POST /lives/:id/join` → LiveKit **subscribe** using `mediaHints`            |
| Show comments/gifts live | Socket `joinLive({ liveId })` after Firebase socket auth               |
| Send a gift              | `POST /gifts/send` with `liveId` (not a custom live endpoint)          |
| Leave cleanly            | `POST /lives/:id/leave` **and** disconnect LiveKit **and** `leaveLive` |
| End stream               | Host: `POST /lives/:id/end` (do **not** only disconnect)               |


Never mint LiveKit JWTs on device. Never treat Socket as authority for money or seats.

---



## 2. Auth & headers

```http
Authorization: Bearer <Firebase ID token>
Content-Type: application/json
```


| Auth mode    | When                                                                                        |
| ------------ | ------------------------------------------------------------------------------------------- |
| **Required** | create, start, end, join, leave, like, comment, gifts, guests, battle start, moderation     |
| **Optional** | feed, detail, list guests/comments/auctions/battle (privacy/personalization when logged in) |


- No global API prefix.
- Unknown body fields → **400**.
- Banned account on any Bearer route → **403** `{ code: "USER_BANNED", … }`.

Error envelope:

```json
{
  "statusCode": 400,
  "timestamp": "2026-07-18T12:00:00.000Z",
  "path": "/lives/…",
  "method": "POST",
  "message": "Live is not currently broadcasting",
  "error": "Bad Request"
}
```

---



## 3. Core concepts



### Live status

```
PLANNED → LIVE → ENDED
              ↘ BANNED
```


| Status    | Meaning for the app                                          |
| --------- | ------------------------------------------------------------ |
| `PLANNED` | Created; host has not started (or not yet broadcasting)      |
| `LIVE`    | On air — join / comment / gift / guest / battle allowed      |
| `ENDED`   | Normal teardown — show replay/history if you want            |
| `BANNED`  | Staff banned — public detail is **404**; do not show in feed |


**Product rules**

1. One concurrent `LIVE` per user.
2. Host `leave` does **not** end the stream — call `end`.
3. Ending (or admin ban) finishes battles, cancels `ACTIVE` live auctions, deletes the LiveKit room, clears guests/sessions/restrictions.



### Roles on stage / in media


| Role                | LiveKit publish?                | How you get it             |
| ------------------- | ------------------------------- | -------------------------- |
| `host`              | yes                             | Own the live + start/join  |
| `guest` / `co_host` | yes (unless muted / camera-off) | Accepted invite or request |
| `viewer`            | no                              | Everyone else after join   |


### Live connect bundle + `mediaHints`

Returned by **`POST /lives/:id/start`**, **`POST /lives`** (with `startNow: true`), **`POST /lives/:id/join`**, and guest publish endpoints (accept / invite-accept / token refresh).

```json
{
  "live": { "...LiveShape..." },
  "token": "<livekit-jwt>",
  "url": "wss://live.example.com",
  "role": "host",
  "mediaHints": {
    "role": "host",
    "canPublish": true,
    "maxVideoResolution": "720p",
    "maxSubscribeResolution": "720p",
    "maxBitrateKbps": 3000,
    "simulcast": true,
    "adaptiveStream": true,
    "dynacast": true,
    "codecPreference": ["h264", "vp8"]
  }
}
```

| Field | Meaning |
|-------|---------|
| `role` | Token role: `host` · `guest` · `co_host` · `viewer` |
| `canPublish` | Whether to publish camera/mic |
| `maxVideoResolution` | Suggested **publish** resolution (`null` for viewers) |
| `maxSubscribeResolution` | Suggested max quality when **subscribing** |
| `maxBitrateKbps` | Suggested publish bitrate; `0` for viewers |
| `simulcast` / `adaptiveStream` / `dynacast` | LiveKit client options |
| `codecPreference` | Prefer H.264 first on iOS |

**Presets by role:** host **1080p @ 4500 kbps** when solo on stage and &lt;200 viewers; otherwise 720p @ 3000 kbps · guest/co_host 480p @ 1200–1500 kbps (360p if &gt;4 on stage) · viewer subscribe-only up to 720p (480p if &gt;500 viewers).

**Source:** `src/livekit/live-media-hints.ts` — read from each start/join/guest response; do not hard-code in the app.

**Full mobile integration guide:** [enhanced-live-performance.md](./enhanced-live-performance.md)


| Action                                     | Host   | Live moderator*                  | Viewer |
| ------------------------------------------ | ------ | -------------------------------- | ------ |
| End live / settings / add mods             | ✓      |                                  |        |
| Invite / accept / kick / mute mic / camera | ✓      | ✓ if `moderatorsCanManageGuests` |        |
| Invite as `CO_HOST` / promote / demote     | ✓ only |                                  |        |
| Delete comment / mute chat / ban viewer    | ✓      | ✓ (always for these)             |        |
| Request seat / comment / like / gift       |        |                                  | ✓      |


Assigned with `POST /lives/:id/moderators`.

---



## 4. End-to-end flows (do this)



### A. Host go-live (solo)


| Step | Call / action                                                     | Why                                                        |
| ---- | ----------------------------------------------------------------- | ---------------------------------------------------------- |
| 1    | `POST /lives` `{ title, coverUrl?, categoryId?, startNow: true }` | Create + start in one shot (or create then `POST …/start`) |
| 2    | Connect LiveKit with `token` + `url` → **publish** camera/mic     | Media                                                      |
| 3    | Socket: connect with Firebase token, then `joinLive({ liveId })`  | HUD events                                                 |
| 4    | Optional `PATCH /lives/:id/settings`                              | Multi-guest policy                                         |
| 5    | Optional `POST /lives/:id/auctions`                               | Live shopping (seller-verified)                            |
| 6    | `POST /lives/:id/end` when done                                   | Proper teardown                                            |


Also join Socket room `user_{userId}` for invites/notifications (see events docs).

### B. Viewer watch


| Step | Call / action                                              | Why                                |
| ---- | ---------------------------------------------------------- | ---------------------------------- |
| 1    | `GET /lives/feed`                                          | Discover                           |
| 2    | Optional `GET /lives/:id`                                  | Preview + `activeAuctions`         |
| 3    | `POST /lives/:id/join`                                     | LiveKit subscribe token + presence |
| 4    | LiveKit connect (subscribe only)                           | Video                              |
| 5    | `joinLive({ liveId })`                                     | Comments / gifts / HUD             |
| 6    | Like / comment / gift as needed                            | Engagement                         |
| 7    | On exit: `POST …/leave` + LiveKit disconnect + `leaveLive` | Clean presence                     |


If the socket disconnects without `leave`, the server cleans presence automatically — still call HTTP `leave` when the user intentionally exits.

### C. Multi-guest

**Viewer requests a seat**

1. `POST /lives/:id/guests/request`
2. Host/mod: `POST /lives/:id/guests/:userId/accept` → guest receives publish `token`
3. Guest LiveKit **publish**; listen for `liveGuestUpdate` mute/camera/kick

**Host invites**

1. Host (or mod for `GUEST` only): `POST /lives/:id/guests/invite` `{ userId, role? }`
2. Invitee gets push `LIVE_GUEST_INVITE` + socket `liveGuestInvite` on `user_{id}`
3. Invitee: `POST /lives/:id/guests/accept-invite` → publish token

**Only the host** may invite with `role: "CO_HOST"` or use promote/demote.

### D. Live shopping

1. Host must be seller-verified → `POST /lives/:id/auctions`
2. HUD: `activeAuctions` on detail/join, or `GET /lives/:id/auctions/active`
3. Viewers: `POST /gifts/send` `{ giftId, receiverId, liveId, auctionId? }`
4. Listen `liveAuction` (and optionally `joinAuction` for the auction room)



### E. Battle (PK)

1. Both hosts must be `LIVE`
2. Optional: `GET /lives/:id/battle/opponents` to pick a rival, **or** `POST /lives/:id/battle/match` for one-tap auto match
3. Or start manually: `POST /lives/:id/battle` `{ opponentLiveId, durationSeconds? }`
4. Gifts on a live bump that side’s score → `liveBattle` `{ type: "score" }`
5. Timer auto-finishes (server job) or host: `POST /lives/:id/battle/:battleId/end`
6. Ending either live also finishes the battle



### F. Moderate chat / toxic viewer (host or live mod)


| Goal                        | Endpoint                                      |
| --------------------------- | --------------------------------------------- |
| Delete a comment            | `DELETE /lives/:id/comments/:commentId`       |
| Mute chat (can still watch) | `POST /lives/:id/viewers/:userId/mute-chat`   |
| Unmute chat                 | `POST /lives/:id/viewers/:userId/unmute-chat` |
| Ban from this live          | `POST /lives/:id/viewers/:userId/ban`         |
| Unban                       | `POST /lives/:id/viewers/:userId/unban`       |


Listen for `liveCommentDeleted` and `liveModeration` to update UI for everyone.

---



## 5. Live object reference

Returned by create / update / end / feed / detail (and nested as `live` on start/join):

```json
{
  "id": "uuid",
  "userId": "uuid",
  "title": "Friday drop",
  "roomName": "live_<uuid>",
  "streamUrl": "ws://…",
  "coverUrl": "https://…",
  "categoryId": "uuid|null",
  "status": "LIVE",
  "banReason": null,
  "viewers": 42,
  "likeCount": 120,
  "totalEarnedCoins": 5000,
  "guestsEnabled": true,
  "guestRequestMode": "EVERYONE",
  "maxGuests": 8,
  "layout": "GRID",
  "allowGuestCamera": true,
  "moderatorsCanManageGuests": true,
  "createdAt": "…",
  "startedAt": "…",
  "endedAt": null,
  "user": {
    "id": "…",
    "username": "…",
    "fullName": "…",
    "avatarUrl": "…",
    "isVerified": true,
    "isPrivate": false
  },
  "category": { "id": "…", "name": "…", "slug": "…", "iconUrl": "…" },
  "mediaMode": "VIDEO",
  "audioOnly": false,
  "paused": false,
  "topic": null,
  "ticketEnabled": false,
  "ticketPriceCoins": 0,
  "houseId": null,
  "scene": { "scene": "CAMERA", "cameraFacing": "front", "dualCameraEnabled": false },
  "look": { "beautyEnabled": false, "filterSlug": null, "effectSlug": null },
  "replay": { "enabled": true, "status": "NONE", "available": false }
}
```

Voice Chat: `mediaMode: "AUDIO"`, `audioOnly: true` — [live-audio-rooms.md](./live-audio-rooms.md). Tickets / games / House / scene: [live-p3-parity.md](./live-p3-parity.md). Full path list: [endpoints2.md](./endpoints2.md).

`GET /lives/:id` and join also include:

```json
"activeAuctions": [ /* enriched auction objects */ ]
```

`banReason` is set when status is `BANNED` (admin); public clients usually never see banned lives (404).

---



## 6. Host APIs



### `POST /lives`

**Auth:** required · **Who:** any user (becomes host)


| Field        | Required | Notes                                              |
| ------------ | -------- | -------------------------------------------------- |
| `title`      | yes      | 1–120 chars                                        |
| `coverUrl`   | no       | max 500                                            |
| `categoryId` | no       | must be an active category                         |
| `startNow`   | no       | if `true`, create then start → host token response |
| `mediaMode`  | no       | `VIDEO` (default) or `AUDIO` (Voice Chat). Aliases `VOICE` / `SOUND` |
| `topic`      | no       | Radio / room topic (max 80)                        |
| `ticketEnabled` / `ticketPriceCoins` | no | Paid entry (P3)                          |
| `ageRestricted` | no    | 18+                                                |


**Success (planned):** live object  
**Success (**`startNow`**):** `{ live, token, url, role: "host", mediaHints }`


| Error | When                                                 |
| ----- | ---------------------------------------------------- |
| `400` | Invalid category; already have another `LIVE` stream |


---



### `PATCH /lives/:id`

**Auth:** host · Partial: `title`, `coverUrl`, `categoryId` (null clears category).


| Error | When            |
| ----- | --------------- |
| `403` | Not owner       |
| `400` | Ended or banned |
| `404` | Missing         |


---



### `GET /lives/:id/settings` · `PATCH /lives/:id/settings`

**Auth:** host

```json
{
  "guestsEnabled": true,
  "guestRequestMode": "EVERYONE",
  "maxGuests": 8,
  "layout": "GRID",
  "allowGuestCamera": true,
  "moderatorsCanManageGuests": true,
  "replayEnabled": true,
  "ageRestricted": false,
  "latitude": 30.0444,
  "longitude": 31.2357
}
```


| Field              | Values / meaning                                      |
| ------------------ | ----------------------------------------------------- |
| `guestRequestMode` | `EVERYONE` | `FOLLOWERS` | `OFF`                      |
| `layout`           | `GRID` | `PANEL` — **UI hint**; client applies layout |
| `maxGuests`        | 1–8 (host does **not** consume a seat)                |
| `replayEnabled`    | Auto-record on start; toggling while LIVE starts/stops Egress |
| `ageRestricted`    | 18+ join/detail gate; hidden from feed unless viewer DOB ≥ 18 |
| `latitude` / `longitude` | Both required for Nearby; send `null` to clear |


Emits `liveGuestUpdate` `{ type: "settings", … }`. See [live-p1-parity.md](./live-p1-parity.md).

---



### `POST /lives/:id/start`

**Auth:** host · Usually from `PLANNED`. If already `LIVE`, re-issues host token (idempotent reconnect).

**Response**

```json
{
  "live": { },
  "token": "<livekit-jwt>",
  "url": "wss://livekit.example",
  "role": "host",
  "mediaHints": {
    "role": "host",
    "canPublish": true,
    "maxVideoResolution": "720p",
    "maxSubscribeResolution": "720p",
    "maxBitrateKbps": 3000,
    "simulcast": true,
    "adaptiveStream": true,
    "dynacast": true,
    "codecPreference": ["h264", "vp8"]
  }
}
```

Notifies followers (`LIVE_STARTED`, capped). Client must **publish** A/V with this token and apply **`mediaHints`** in the LiveKit SDK.

---



### `POST /lives/:id/end`

**Auth:** host

Teardown order (server):

1. Finish ACTIVE battles involving this live
2. Cancel ACTIVE live auctions (escrow refund when enabled)
3. Delete LiveKit room
4. Close viewer sessions + guests → `LEFT`
5. Clear viewer restrictions
6. Status `ENDED` → emit `liveEnded`

Idempotent if already ended/banned. **Response:** shaped live.

---



## 7. Discovery APIs



### `GET /lives/feed`

**Auth:** optional


| Query           | Default | Notes                                     |
| --------------- | ------- | ----------------------------------------- |
| `page`          | 1       |                                           |
| `limit`         | 20      | max 50                                    |
| `categoryId`    | —       |                                           |
| `followingOnly` | false   | prefers followed hosts when authenticated |
| `latitude` / `longitude` | — | optional; used for custom-audience live ads and Nearby |
| `nearby` | false | Nearby tab. Requires lat/lng. No promote inject |
| `radiusKm` | 50 | Nearby only, max 150 |


Returns `{ data: Live[], meta }` for `LIVE` only (blocks/private applied when authed).

Main For You (no `followingOnly` / `categoryId` / `nearby`) may insert promoted lives every 8 organic slots with `isPromoted` + `promotion.id`. See [live-promotions.md](./live-promotions.md).

`GET /lives/nearby` is the same as `feed?nearby=true`. See [live-p1-parity.md](./live-p1-parity.md).

---



### `GET /lives/mine`

**Auth:** required · Same pagination as feed · Caller’s lives (all statuses).

---



### `GET /lives/:id`

**Auth:** optional · Live + `activeAuctions`.  
`BANNED` → **404**. Private host without access → **403**.

---



## 8. Watch & engagement APIs



### `POST /lives/:id/join`

**Auth:** required · Live must be `LIVE` · Rejects viewers banned from this live.

Optional body `{ "campaignId": "<promotion.id>", "trafficSource": "FOR_YOU" }`. `campaignId` bills a promoted slot. `trafficSource` is stored on the viewer session for post-live stats. See [live-promotions.md](./live-promotions.md) and [live-p0-parity.md](./live-p0-parity.md).

Issues LiveKit token:


| Condition    | `role`              | Publish?                    |
| ------------ | ------------------- | --------------------------- |
| Host         | `host`              | yes                         |
| Active guest | `guest` / `co_host` | yes unless muted/camera-off |
| Else         | `viewer`            | no                          |


**Response**

```json
{
  "live": { "activeAuctions": [] },
  "token": "…",
  "url": "…",
  "role": "viewer",
  "guest": null,
  "mediaHints": {
    "role": "viewer",
    "canPublish": false,
    "maxVideoResolution": null,
    "maxSubscribeResolution": "720p",
    "maxBitrateKbps": 0,
    "simulcast": false,
    "adaptiveStream": true,
    "dynacast": false,
    "codecPreference": ["h264", "vp8"]
  }
}
```

If on stage, `guest` includes `{ role, mutedByHost, cameraOffByHost, status }`.

Host and viewers: upsert a viewer session, recount open sessions, emit `liveViewers`. The host is included in `viewers`.

---



### `POST /lives/:id/leave`

**Auth:** required

- Closes viewer session, refreshes count, emits `liveViewers`
- If user was an **ACTIVE** guest, also leaves the stage
- Host leave is a **no-op** on count (host stays counted until `end`)
- Socket `leaveLive` also closes the viewer session (same as this endpoint)

```json
{ "success": true, "viewers": 41 }
```

---

### `GET /lives/:id/viewers`

**Auth:** optional

Lists viewers watching the live stream (paginated).

- **Query params:** `page` (default 1), `limit` (default 20, max 100), `activeOnly` (default true)

```json
{
  "data": [
    {
      "id": "sess-9a4f-45b1",
      "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
      "userId": "u-123",
      "joinedAt": "2026-08-15T12:00:00.000Z",
      "leftAt": null,
      "user": {
        "id": "u-123",
        "username": "music_fan",
        "fullName": "Music Fan",
        "avatarUrl": "https://cdn.example.com/avatars/fan.jpg",
        "isVerified": false,
        "gifterLevel": 14
      }
    }
  ],
  "meta": {
    "total": 41,
    "page": 1,
    "limit": 20,
    "totalPages": 3
  }
}
```

---



### `POST /lives/:id/like`

**Auth:** required · `LIVE`

TikTok-style heart taps: **every successful call increments** `likeCount`. A `LiveLike` row is created on the first tap (unique liker analytics); later taps still bump the counter.

```json
{ "likeCount": 121, "liked": true, "alreadyLiked": false }
```

`alreadyLiked: true` means this user had already liked at least once before this tap (count still increased).

Soft rate limit: max **15** attempts / second / user / live → `400` if exceeded.

Emits `liveLike` `{ liveId, likeCount, userId }` on every successful tap (client plays heart animation).

---



### `POST /lives/:id/comments`

**Auth:** required · `LIVE` · Blocked if muted/banned on this live

```json
{ "content": "Fire 🔥" }
```

`content`: 1–500 chars. Returns comment + user card; emits `liveComment`.

---



### `GET /lives/:id/comments`

**Auth:** optional


| Query      | Default      |
| ---------- | ------------ |
| `page`     | 1            |
| `limit`    | 50 (max 100) |
| `mineOnly` | false        |


Newest first, **pinned first**. Response includes `pinnedComment` (or `null`) plus `{ data, meta }`.

Detail / join also include `pinnedComment`.

---



## 9. Host/mod moderation APIs

All require **host or live moderator**. Body for mute/ban may include optional `reason` (max 500).

### `DELETE /lives/:id/comments/:commentId`

Deletes the comment · Emits `liveCommentDeleted` `{ liveId, commentId, deletedBy }`.

```json
{ "success": true, "commentId": "…" }
```

---



### `POST /lives/:id/comments/:commentId/pin`

**Auth:** host or live moderator · At most **one** pinned comment per live (pins replace previous).

Emits `liveCommentPinned` `{ liveId, comment }`.

### `POST /lives/:id/comments/:commentId/unpin`

Emits `liveCommentUnpinned` `{ liveId, commentId }`.

---



### `POST /lives/:id/viewers/:userId/mute-chat`

```json
{ "reason": "spam" }
```

Viewer can still watch; cannot comment. Emits `liveModeration` `{ type: "chat_muted", … }`.

### `POST /lives/:id/viewers/:userId/unmute-chat`

Emits `{ type: "chat_unmuted" }`.

---



### `POST /lives/:id/viewers/:userId/ban`

Force-leaves the viewer, removes LiveKit participant, blocks rejoin / comment / like until live ends or unban.

Emits `{ type: "viewer_banned" }`.

### `POST /lives/:id/viewers/:userId/unban`

Emits `{ type: "viewer_unbanned" }`.

Restrictions are stored per live and cleared when the live ends/bans.

---



## 10. Multi-guest APIs



### Guest card

```json
{
  "id": "…",
  "liveId": "…",
  "userId": "…",
  "role": "GUEST",
  "status": "ACTIVE",
  "mutedByHost": false,
  "cameraOffByHost": false,
  "invitedById": null,
  "joinedStageAt": "…",
  "leftStageAt": null,
  "user": { "id": "…", "username": "…", "fullName": "…", "avatarUrl": "…", "isVerified": false }
}
```


| Guest `status`                 | Meaning                           |
| ------------------------------ | --------------------------------- |
| `REQUESTED`                    | Waiting for host/mod              |
| `INVITED`                      | Host invited; invitee must accept |
| `ACTIVE`                       | On stage (publish)                |
| `LEFT` / `REJECTED` / `KICKED` | Off stage                         |


---



### `GET /lives/:id/guests`

**Auth:** optional · Lists `REQUESTED`  `INVITED`  `ACTIVE` → `{ data: Guest[] }`.

---



### `POST /lives/:id/guests/request`

**Auth:** viewer · Respects `guestsEnabled`, `guestRequestMode`, seat cap, blocks.

- Already `ACTIVE` → returns publish token payload  
- `INVITED` → accepts invite  
- Else → `REQUESTED` + emit `{ type: "requested" }`

---



### `POST /lives/:id/guests/invite`

**Auth:** host/mod

```json
{ "userId": "uuid", "role": "GUEST" }
```


| `role`            | Who may set it                     |
| ----------------- | ---------------------------------- |
| `GUEST` (default) | Host or mod                        |
| `CO_HOST`         | **Host only** → `403` if mod tries |


Push + `liveGuestInvite` + room `liveGuestUpdate` `{ type: "invited" }`.

---



### `POST /lives/:id/guests/accept-invite`

**Auth:** invitee → `{ guest, token, url, role }`.

### `POST /lives/:id/guests/:userId/accept`

**Auth:** host/mod · Pending `REQUESTED` → same token payload.

### `POST /lives/:id/guests/:userId/reject`

**Auth:** host/mod · `REQUESTED` or `INVITED` → `REJECTED`.

### `POST /lives/:id/guests/leave`

**Auth:** active guest · Stage → `LEFT` + LiveKit unpublish.

### `POST /lives/:id/guests/:userId/kick`

**Auth:** host/mod → `KICKED` + LiveKit force remove · `{ type: "kicked" }`.

---



### Mute / camera (stage A/V — not chat)


| Method | Path                                   | Effect                 |
| ------ | -------------------------------------- | ---------------------- |
| `POST` | `/lives/:id/guests/:userId/mute`       | Mic off (DB + LiveKit) |
| `POST` | `/lives/:id/guests/:userId/unmute`     | Mic on                 |
| `POST` | `/lives/:id/guests/:userId/camera-off` | Camera forced off      |
| `POST` | `/lives/:id/guests/:userId/camera-on`  | Allow camera           |


On `liveGuestUpdate`, stop local tracks as instructed; refresh token if reconnect fails.

---



### Co-host


| Method | Path                                | Auth                      |
| ------ | ----------------------------------- | ------------------------- |
| `POST` | `/lives/:id/guests/:userId/promote` | **Host only** → `CO_HOST` |
| `POST` | `/lives/:id/guests/:userId/demote`  | **Host only** → `GUEST`   |


Publish model matches guests; role is for UI / trust.

---



### `POST /lives/:id/guests/token`

**Auth:** active guest · Refresh publish JWT.

### Publish-token response (accept / invite-accept / token)

```json
{
  "guest": {
    "status": "ACTIVE",
    "role": "GUEST",
    "mutedByHost": false,
    "cameraOffByHost": false,
    "user": {}
  },
  "token": "<livekit-jwt>",
  "url": "wss://…",
  "role": "guest",
  "mediaHints": {
    "role": "guest",
    "canPublish": true,
    "maxVideoResolution": "480p",
    "maxSubscribeResolution": "720p",
    "maxBitrateKbps": 1200,
    "simulcast": true,
    "adaptiveStream": true,
    "dynacast": true,
    "codecPreference": ["h264", "vp8"]
  }
}
```

---



## 11. Live moderators APIs


| Method   | Path                            | Auth     | Body           |
| -------- | ------------------------------- | -------- | -------------- |
| `GET`    | `/lives/:id/moderators`         | required | —              |
| `POST`   | `/lives/:id/moderators`         | **host** | `{ "userId" }` |
| `DELETE` | `/lives/:id/moderators/:userId` | **host** | —              |


```json
{
  "data": [
    {
      "userId": "…",
      "assignedAt": "…",
      "user": { "id": "…", "username": "…", "avatarUrl": "…" }
    }
  ]
}
```

Mods can manage guests when `moderatorsCanManageGuests` is true, and can always moderate chat (delete / mute / ban viewer).

---



## 12. Battles (PK) APIs



### `GET /lives/:id/battle/opponents`

**Auth:** host of `:id` · Live must be `LIVE`


| Query   | Default     |
| ------- | ----------- |
| `limit` | 20 (max 50) |


Returns other `LIVE` streams not in an ACTIVE battle (excludes self/blocked), ranked by viewers + same-category boost:

```json
{ "data": [ { "id", "title", "viewers", "user", "category", … } ] }
```



### `POST /lives/:id/battle/match`

**Auth:** host · One-tap auto match

```json
{ "durationSeconds": 300, "mode": "TEAM" }
```

Picks best eligible opponent (similar viewers, same category preferred). `mode: TEAM` opens a 2v2 lobby (teammates join after).  
No opponent → **404** `No opponents available` (UI can retry / show searching).

### `GET /lives/:id/battle`

**Auth:** optional → `{ battle: Battle | null }`  
If `endTime` passed, server finishes the battle before returning.

### `POST /lives/:id/battle`

**Auth:** host of `:id`

```json
{ "opponentLiveId": "uuid", "durationSeconds": 300, "mode": "TEAM" }
```

`durationSeconds`: 30–1800 (default **300**). Both lives `LIVE`, neither already in an ACTIVE battle.

`mode: TEAM` starts a **2v2** (captains = live1 vs live2). Teammate slots (`live3` / `live4`) can stay empty.

```http
GET  /lives/:id/battle/open-teams
POST /lives/:yourLiveId/battle/:battleId/join      { "team": 1 }
POST /lives/:captainLiveId/battle/:battleId/invite { "teammateLiveId": "…" }
POST /lives/:teammateLiveId/battle/:battleId/leave
```

`team` 1 sits with live1, `team` 2 with live2. Omit `team` to take the first open slot. Captains invite; teammates leave. Socket `liveBattle` `{ "type": "roster", "team": 1, "joinedLiveId": "…" }`.

Battle payload extras: `teams.team1.captainLiveId` / `teammateLiveId`, `openSlots: [1, 2]`. See [live-p1-parity.md](./live-p1-parity.md).

### `POST /lives/:id/battle/multiplier`

**Auth:** host of one of the competing lives in the active battle

Triggers a speed boost window where all gifts sent to that stream generate multiplied points for the battle score.

```json
{
  "multiplier": 2.0,
  "durationSeconds": 30
}
```

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `multiplier` | number | yes | 1.5 to 5.0 (e.g. 2.0 = 2x points) |
| `durationSeconds` | integer | yes | 10 to 120 seconds |

**Response** (Updated battle object with `multiplier` and `multiplierEndsAt`):

```json
{
  "id": "…",
  "live1Id": "…",
  "live2Id": "…",
  "live1Score": 1200,
  "live2Score": 800,
  "status": "ACTIVE",
  "phase": "BATTLE",
  "multiplier": 2,
  "multiplierEndsAt": "2026-08-15T12:05:30.000Z",
  "startTime": "…",
  "endTime": "…"
}
```

Emits `liveBattlePhase` to **both** live rooms:
```json
{
  "type": "multiplier_started",
  "multiplier": 2,
  "multiplierEndsAt": "2026-08-15T12:05:30.000Z",
  "battle": { /* shaped battle */ }
}
```

---

## 13. Interactive Tools & Engagement APIs

### A. Gift Goals (أهداف الهدايا)

Hosts can set custom coin goals displayed on the viewer HUD to motivate community gifting.

#### `POST /lives/:id/gift-goal`

**Auth:** host · Live must be `LIVE` or `PLANNED`

```json
{
  "title": "Unlock Cosplay Stream 🎉",
  "target": 5000
}
```

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `title` | string | no | Max 100 chars (defaults to "Live Gift Goal") |
| `target` | integer | yes | Min 1 coin |

**Response:**
```json
{
  "id": "live-uuid",
  "giftGoalTitle": "Unlock Cosplay Stream 🎉",
  "giftGoalTarget": 5000,
  "giftGoalCurrent": 0
}
```

Emits `liveGiftGoalUpdate` to `live_{id}` room whenever set or updated by gifts.

---

### B. Chat Rules & Moderation Settings

Control who can participate in chat, enable slow mode, and define filtered keywords.

#### `PATCH /lives/:id/chat-rules`

**Auth:** host

```json
{
  "chatMode": "FOLLOWERS",
  "slowModeSeconds": 5,
  "blockedKeywords": ["badword", "spamlink", "scam"]
}
```

| Field | Values / Type | Required | Notes |
|-------|---------------|----------|-------|
| `chatMode` | `EVERYONE` \| `FOLLOWERS` \| `SUBSCRIBERS` | no | `SUBSCRIBERS` requires active Fan Club subscription |
| `slowModeSeconds` | integer | no | 0 to 60 seconds interval between comments |
| `blockedKeywords` | string[] | no | Host-defined blacklist (matched case-insensitively) |

**Response:**
```json
{
  "id": "live-uuid",
  "chatMode": "FOLLOWERS",
  "slowModeSeconds": 5,
  "blockedKeywords": ["badword", "spamlink", "scam"]
}
```

Emits `liveModeration` `{ type: "chat_rules_updated", chatRules: { ... } }`.

> **Note:** The stream host is immune to slow mode, chatMode restrictions, and blocked keyword filters.

---

### C. Live Polls (استطلاعات الرأي)

Create and vote on live interactive polls with real-time percentage results.

#### `POST /lives/:id/polls`

**Auth:** host · Ends any existing active poll on this live.

```json
{
  "question": "What should we do next?",
  "options": ["Play Guitar 🎸", "Q&A Session 💬", "Open PK Battle ⚔️"]
}
```

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `question` | string | yes | Max 200 chars |
| `options` | string[] | yes | 2 to 5 options |

**Response:**
```json
{
  "id": "poll-uuid",
  "liveId": "live-uuid",
  "question": "What should we do next?",
  "options": [
    { "text": "Play Guitar 🎸", "votes": 0, "percentage": 0 },
    { "text": "Q&A Session 💬", "votes": 0, "percentage": 0 },
    { "text": "Open PK Battle ⚔️", "votes": 0, "percentage": 0 }
  ],
  "totalVotes": 0,
  "status": "ACTIVE",
  "createdAt": "2026-08-15T12:00:00.000Z",
  "endedAt": null
}
```

Emits `livePollUpdated` to `live_{id}` room.

#### `POST /lives/:id/polls/:pollId/vote`

**Auth:** viewer (required) · One vote per user per poll.

```json
{
  "optionIndex": 1
}
```

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `optionIndex` | integer | yes | 0-indexed option |

**Response:** Formatted poll object with updated vote counts and percentages. Emits `livePollUpdated`.

#### `POST /lives/:id/polls/:pollId/end`

**Auth:** host · Manually closes voting. Emits `livePollUpdated` with `status: "ENDED"`.

#### `GET /lives/:id/polls/active`

**Auth:** optional · Returns current active poll or `null`.

---

### D. Live Q&A Box (صندوق الأسئلة والأجوبة)

Audience members submit questions for the host to answer on stream.

#### `POST /lives/:id/qa`

**Auth:** viewer (required) · Live must be `LIVE`.

```json
{
  "question": "How long have you been playing music?"
}
```

**Response:**
```json
{
  "id": "qa-uuid",
  "liveId": "live-uuid",
  "userId": "user-uuid",
  "question": "How long have you been playing music?",
  "isAnswered": false,
  "isPinned": false,
  "createdAt": "2026-08-15T12:00:00.000Z",
  "user": {
    "id": "user-uuid",
    "username": "fan123",
    "fullName": "Fan One",
    "avatarUrl": "https://…"
  }
}
```

Emits `liveQAUpdated` `{ type: "created", qa }`.

#### `GET /lives/:id/qa`

**Auth:** optional · Returns all Q&A questions for this stream (pinned first, newest first).

#### `POST /lives/:id/qa/:qaId/pin`

**Auth:** host · Pins question to the viewer HUD (unpins any previously pinned Q&A). Emits `liveQAUpdated` `{ type: "pinned", qa }`.

#### `POST /lives/:id/qa/:qaId/answer`

**Auth:** host · Marks question as answered. Emits `liveQAUpdated` `{ type: "answered", qa }`.

---

### E. Treasure Boxes / Coin Drops (صناديق الكنز)

Hosts or generous viewers drop coin boxes with countdown timers. Once opened, active viewers claim randomized portions into their wallet!

#### `POST /lives/:id/treasure-boxes`

**Auth:** required (creator) · Deducts `totalCoins` from creator wallet balance immediately.

```json
{
  "totalCoins": 1000,
  "maxClaims": 20,
  "delaySeconds": 180
}
```

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `totalCoins` | integer | yes | Min 10 coins (must have sufficient wallet balance) |
| `maxClaims` | integer | yes | 1 to 100 viewers can claim |
| `delaySeconds` | integer | no | 10 to 600 seconds (default 180s = 3 minutes) |

**Response:**
```json
{
  "id": "box-uuid",
  "liveId": "live-uuid",
  "creatorId": "creator-uuid",
  "totalCoins": 1000,
  "remainingCoins": 1000,
  "maxClaims": 20,
  "claimedCount": 0,
  "unlocksAt": "2026-08-15T12:03:00.000Z",
  "status": "WAITING",
  "creator": {
    "id": "creator-uuid",
    "username": "generous_user",
    "fullName": "Rich Guy",
    "avatarUrl": "https://…"
  }
}
```

Emits `liveTreasureBoxSpawned` to `live_{id}` room.

#### `POST /lives/:id/treasure-boxes/:boxId/claim`

**Auth:** viewer (required) · Claim a share after countdown ends (`unlocksAt <= now`).

- Each viewer can claim at most once per box.
- Distributes a randomized coin amount (between 50% and 150% of the remaining average) directly to the user's wallet.
- When `claimedCount >= maxClaims` or `remainingCoins <= 0`, box status transitions to `EXPIRED`.

**Response:**
```json
{
  "id": "claim-uuid",
  "boxId": "box-uuid",
  "userId": "user-uuid",
  "coinsWon": 58,
  "createdAt": "2026-08-15T12:03:05.000Z",
  "box": {
    "id": "box-uuid",
    "claimedCount": 1,
    "remainingCoins": 942,
    "status": "OPEN"
  }
}
```

Emits `liveTreasureBoxClaimed` to `live_{id}` room:
```json
{
  "boxId": "box-uuid",
  "userId": "user-uuid",
  "coinsWon": 58,
  "claimedCount": 1,
  "maxClaims": 20
}
```

#### `GET /lives/:id/treasure-boxes`

**Auth:** optional · Returns active/waiting treasure boxes on this live.

---

### F. Post-Live Summary Analytics

#### `GET /lives/:id/summary`

**Auth:** host (owner only)

Returns a detailed performance recap of the broadcast after completion.

**Response:**
```json
{
  "liveId": "live-uuid",
  "title": "Weekend Music Jam",
  "coverUrl": "https://…",
  "startedAt": "2026-08-15T10:00:00.000Z",
  "endedAt": "2026-08-15T11:30:00.000Z",
  "durationSeconds": 5400,
  "peakViewers": 350,
  "totalViewerSessions": 1240,
  "totalLikes": 15420,
  "totalComments": 842,
  "totalEarnedCoins": 28500,
  "topGifters": [
    {
      "user": {
        "id": "user-uuid-1",
        "username": "superfan",
        "fullName": "Super Fan",
        "avatarUrl": "https://…",
        "isVerified": true,
        "gifterLevel": 25
      },
      "totalCoins": 12000
    }
  ]
}
```

---

## 14. Live shopping (auctions)

Host must be **seller-verified**. Live must be `LIVE` and owned by host.


| Method | Path                         | Auth     | Use for                                             |
| ------ | ---------------------------- | -------- | --------------------------------------------------- |
| `POST` | `/lives/:id/auctions`        | host     | Create auction bound to this live                   |
| `GET`  | `/lives/:id/auctions/active` | optional | HUD list of ACTIVE                                  |
| `GET`  | `/lives/:id/auctions`        | optional | Paginated; `?status=ACTIVE|COMPLETED|CANCELLED|ALL` |




### Create body

```json
{
  "itemName": "Vintage jacket",
  "itemImageUrl": "https://…",
  "targetPrice": 100,
  "startingPrice": 0,
  "startedAt": "2026-07-18T12:00:00.000Z",
  "endedAt": "2026-07-18T13:00:00.000Z"
}
```


| Field                       | Required | Notes                         |
| --------------------------- | -------- | ----------------------------- |
| `targetPrice`               | **yes**  | fiat ≥ 0.01 → coins on server |
| `itemName` / `itemImageUrl` | no       |                               |
| `startingPrice`             | no       | fiat ≥ 0                      |
| `startedAt` / `endedAt`     | no       | ISO strings                   |


Full auction rules: [../auctions/mobile-api.md](../auctions/mobile-api.md).

Emits `liveAuction` `{ liveId, auction, action: "created" }` (progress on gifts; `cancelled` on live end/ban).

---



## 14. Gifts during a live

```http
POST /gifts/send
Authorization: Bearer …
```

```json
{
  "giftId": "uuid",
  "receiverId": "uuid",
  "liveId": "uuid",
  "auctionId": "uuid",
  "message": "optional"
}
```


| Field        | Required | Notes                                                         |
| ------------ | -------- | ------------------------------------------------------------- |
| `giftId`     | yes      | From inventory                                                |
| `receiverId` | yes      | Required by DTO; server may override to the live/auction host |
| `liveId`     | yes*     | Live must be `LIVE`                                           |
| `auctionId`  | no       | Progress a live (or post) auction                             |
| `message`    | no       |                                                               |


Or derive live from auction when the auction has `liveId`.

**What happens**

1. Inventory −1 · host earns coins (or auction escrow path)
2. `Live.totalEarnedCoins` increments
3. Emits `liveGift` (+ often a synthetic live comment)
4. If `auctionId` → `liveAuction` progress
5. If battle ACTIVE → score bump

Catalog / purchase / inventory: [../gifts/mobile-api.md](../gifts/mobile-api.md).

---



## 15. LiveKit checklist

1. Use `url` + `token` + **`mediaHints`** from start / join / guest endpoints only.
2. **Host / guest / co_host:** publish camera + mic using `mediaHints.maxVideoResolution` and `maxBitrateKbps` (respect mute / camera-off).
3. **Viewer:** subscribe only; enable `mediaHints.adaptiveStream` for network-aware quality.
4. On mute/camera-off `liveGuestUpdate`: stop local tracks; refresh via `POST …/guests/token` or re-join if needed.
5. After flipping front ↔ back: emit socket `switchLiveCamera` so viewers can mirror the tile — [live-camera.md](./live-camera.md).
6. On `liveEnded` or kick: disconnect LiveKit + leave Socket room.
7. Token TTL ≈ **6h**; treat reconnect as re-join / refresh token.
8. Production: `LIVEKIT_URL` must be **`wss://`**; enable **TURN** for cellular viewers ([production.md](./production.md), `deploy/livekit.yaml`).

Ops env (backend): `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` — see [logic.md](./logic.md).

### Apply `mediaHints` (Flutter example)

```dart
Future<void> connectLive(Map<String, dynamic> res) async {
  final hints = res['mediaHints'] as Map<String, dynamic>;
  await room.connect(
    res['url'] as String,
    res['token'] as String,
    roomOptions: RoomOptions(
      adaptiveStream: hints['adaptiveStream'] == true,
      dynacast: hints['dynacast'] == true,
    ),
  );
  if (hints['canPublish'] == true) {
    await room.localParticipant?.setCameraEnabled(true);
    // Map hints['maxVideoResolution'] + hints['maxBitrateKbps'] to VideoPublishOptions
  }
}
```

---



## 16. Socket.IO checklist

Connect with Firebase auth (required on handshake):

```js
const socket = io(API_BASE_URL, {
  auth: { token: firebaseIdToken },
  // or Authorization: Bearer <token> on handshake
});
```

Also: `joinUser({})` or `joinUser({ userId: me.id })` → room `user_{userId}` (must be your own id).

### Client → server


| Message     | Payload      | What to do                                                            |
| ----------- | ------------ | --------------------------------------------------------------------- |
| `joinLive`  | `{ liveId }` | After HTTP join (or as host). `userId` comes from the socket session. |
| `leaveLive` | `{ liveId }` | Leave HUD room. Still call HTTP `POST …/leave` when exiting the live. |
| `switchLiveCamera` | `{ liveId, facing: "front" \| "back" }` | Host / on-stage guest after flipping the device camera. Full guide: [live-camera.md](./live-camera.md). |




### Server → client (`live_{id}`)


| Event                 | Payload (typical)                      | UI action                                                     |
| --------------------- | -------------------------------------- | ------------------------------------------------------------- |
| `liveComment`         | comment + user                         | Append chat                                                   |
| `liveCommentDeleted`  | `{ liveId, commentId, deletedBy }`     | Remove bubble                                                 |
| `liveCommentPinned`   | `{ liveId, comment }`                  | Show pinned bar                                               |
| `liveCommentUnpinned` | `{ liveId, commentId }`                | Clear pin                                                     |
| `liveModeration`      | `{ type, liveId, userId, reason? }`    | Show mute/ban state                                           |
| `liveGift`            | gift summary + coins                   | Play animation; update earnings                               |
| `liveViewers`         | `{ liveId, viewers }`                  | Update counter                                                |
| `liveLike`            | `{ liveId, likeCount, userId }`        | Update likes                                                  |
| `liveEnded`           | `{ liveId, status, reason? }`          | Exit room; stop media                                         |
| `liveAuction`         | `{ liveId, auction, action }`          | Update shopping HUD                                           |
| `liveGuestUpdate`     | `{ type, liveId, guest? | settings? }` | Stage / settings UI — apply `layout` (GRID/PANEL) client-side |
| `liveCameraChanged`   | `{ liveId, userId, facing, role, at }` | Mirror / badge the publisher tile (`front` \| `back`). See [live-camera.md](./live-camera.md). |
| `liveBattle`          | `{ type, battle }`                     | PK scores / timer / winner                                    |


`liveModeration.type`: `chat_muted`  `chat_unmuted`  `viewer_banned`  `viewer_unbanned`.

`liveGuestUpdate.type`: `settings`, `requested`, `invited`, `joined`, `left`, `rejected`, `kicked`, `muted`, `unmuted`, `camera_off`, `camera_on`, `role`.

### Personal room `user_*`


| Event             | When                      |
| ----------------- | ------------------------- |
| `liveGuestInvite` | You were invited on stage |


**Disconnect:** server cleans viewer presence for lives tracked on that socket. Still prefer explicit HTTP `leave`.

---



## 17. Endpoint index


| Method   | Path                                      | Auth              | Who / notes                                                           |
| -------- | ----------------------------------------- | ----------------- | --------------------------------------------------------------------- |
| `POST`   | `/lives`                                  | required          | Create (+ optional start)                                             |
| `PATCH`  | `/lives/:id`                              | host              | Metadata                                                              |
| `GET`    | `/lives/:id/settings`                     | host              | Guest + P1 flags (18+, Nearby, replay)                                |
| `PATCH`  | `/lives/:id/settings`                     | host              | Guest + P1 flags (18+, Nearby, replay)                                |
| `POST`   | `/lives/:id/start`                        | host              | Go live + token                                                       |
| `POST`   | `/lives/:id/end`                          | host              | End stream                                                            |
| `GET`    | `/lives/feed`                             | optional          | Discover                                                              |
| `GET`    | `/lives/nearby`                           | optional          | Nearby (`lat`/`lng` required)                                         |
| `GET`    | `/lives/:id/studio`                       | host              | RTMP URL + stream key + recording                                     |
| `GET`    | `/lives/:id/clips`                        | optional          | Highlight clips                                                       |
| `POST`   | `/lives/:id/clips`                        | host              | Cut a clip from READY replay                                          |
| `POST`   | `/lives/:id/clips/:clipId/post`           | host              | Publish clip as a video post                                          |
| `GET`    | `/lives/:id/cohost/hosts`                 | host              | Other LIVE hosts to invite                                            |
| `GET`    | `/lives/:id/cohost`                       | host              | Co-host sessions                                                      |
| `POST`   | `/lives/:id/cohost/invite`                | host              | Invite `{ guestLiveId }`                                              |
| `POST`   | `/lives/:id/cohost/:sessionId/accept`     | invited host      | Accept multi-room co-host                                             |
| `POST`   | `/lives/:id/cohost/:sessionId/end`        | either host       | End / decline                                                         |
| `GET`    | `/lives/mine`                             | required          | My lives                                                              |
| `GET`    | `/lives/:id`                              | optional          | Detail                                                                |
| `POST`   | `/lives/:id/join`                         | required          | Watch token                                                           |
| `POST`   | `/lives/:id/leave`                        | required          | Leave presence                                                        |
| `POST`   | `/lives/:id/like`                         | required          | Like                                                                  |
| `POST`   | `/lives/:id/comments`                     | required          | Comment                                                               |
| `GET`    | `/lives/:id/comments`                     | optional          | List comments                                                         |
| `DELETE` | `/lives/:id/comments/:commentId`          | host/mod          | Delete comment                                                        |
| `POST`   | `/lives/:id/viewers/:userId/mute-chat`    | host/mod          | Mute chat                                                             |
| `POST`   | `/lives/:id/viewers/:userId/unmute-chat`  | host/mod          | Unmute                                                                |
| `POST`   | `/lives/:id/viewers/:userId/ban`          | host/mod          | Ban from live                                                         |
| `POST`   | `/lives/:id/viewers/:userId/unban`        | host/mod          | Unban                                                                 |
| `GET`    | `/lives/:id/guests`                       | optional          | Stage list                                                            |
| `POST`   | `/lives/:id/guests/request`               | required          | Request seat                                                          |
| `POST`   | `/lives/:id/guests/invite`                | host/mod          | Invite                                                                |
| `POST`   | `/lives/:id/guests/accept-invite`         | invitee           | Accept invite                                                         |
| `POST`   | `/lives/:id/guests/leave`                 | guest             | Leave stage                                                           |
| `POST`   | `/lives/:id/guests/token`                 | guest             | Refresh token                                                         |
| `POST`   | `/lives/:id/guests/:userId/accept`        | host/mod          | Accept request                                                        |
| `POST`   | `/lives/:id/guests/:userId/reject`        | host/mod          | Reject                                                                |
| `POST`   | `/lives/:id/guests/:userId/kick`          | host/mod          | Kick                                                                  |
| `POST`   | `/lives/:id/guests/:userId/mute`          | host/mod          | Mic off                                                               |
| `POST`   | `/lives/:id/guests/:userId/unmute`        | host/mod          | Mic on                                                                |
| `POST`   | `/lives/:id/guests/:userId/camera-off`    | host/mod          | Cam off                                                               |
| `POST`   | `/lives/:id/guests/:userId/camera-on`     | host/mod          | Cam on                                                                |
| `POST`   | `/lives/:id/guests/:userId/promote`       | host              | Co-host                                                               |
| `POST`   | `/lives/:id/guests/:userId/demote`        | host              | Guest                                                                 |
| `GET`    | `/lives/:id/moderators`                   | required          | List mods                                                             |
| `POST`   | `/lives/:id/moderators`                   | host              | Add mod                                                               |
| `DELETE` | `/lives/:id/moderators/:userId`           | host              | Remove mod                                                            |
| `POST`   | `/lives/:id/comments/:commentId/pin`      | host/mod          | Pin comment                                                           |
| `POST`   | `/lives/:id/comments/:commentId/unpin`    | host/mod          | Unpin                                                                 |
| `GET`    | `/lives/:id/battle/opponents`             | host              | PK suggest list                                                       |
| `POST`   | `/lives/:id/battle/match`                 | host              | Auto match PK                                                         |
| `GET`    | `/lives/:id/battle`                       | optional          | Current PK state                                                      |
| `POST`   | `/lives/:id/battle`                       | host              | Start PK `{ opponentLiveId, durationSeconds?, mode? }`                |
| `GET`    | `/lives/:id/battle/open-teams`            | host              | 2v2 lobbies with an empty teammate slot                               |
| `POST`   | `/lives/:id/battle/:battleId/join`        | joining host      | Join a TEAM slot `{ team?: 1 \| 2 }`                                  |
| `POST`   | `/lives/:id/battle/:battleId/invite`      | captain           | Pull a LIVE host onto your team                                       |
| `POST`   | `/lives/:id/battle/:battleId/leave`       | teammate          | Leave a 2v2 slot                                                      |
| `POST`   | `/lives/:id/battle/:battleId/end`         | host              | End PK                                                                |
| `POST`   | `/lives/:id/gift-goal`                    | host              | Set gift target `{ title?, target }`                                  |
| `PATCH`  | `/lives/:id/chat-rules`                   | host              | Update chat mode, slow mode & keywords                                |
| `POST`   | `/lives/:id/polls`                        | host              | Create poll `{ question, options }`                                   |
| `POST`   | `/lives/:id/polls/:pollId/vote`           | required          | Vote in poll `{ optionIndex }`                                        |
| `POST`   | `/lives/:id/polls/:pollId/end`            | host              | End poll                                                              |
| `GET`    | `/lives/:id/polls/active`                 | optional          | Fetch active poll                                                     |
| `POST`   | `/lives/:id/qa`                           | required          | Submit Q&A question                                                   |
| `GET`    | `/lives/:id/qa`                           | optional          | List stream Q&A questions                                             |
| `POST`   | `/lives/:id/qa/:qaId/answer`              | host              | Mark Q&A as answered                                                  |
| `POST`   | `/lives/:id/qa/:qaId/pin`                 | host              | Pin Q&A question on screen                                            |
| `POST`   | `/lives/:id/treasure-boxes`               | required          | Drop Treasure Box `{ totalCoins, maxClaims, delaySeconds? }`          |
| `POST`   | `/lives/:id/treasure-boxes/:boxId/claim`  | required          | Claim coins from Treasure Box                                         |
| `GET`    | `/lives/:id/treasure-boxes`               | optional          | List active Treasure Boxes                                            |
| `POST`   | `/lives/:id/battle/multiplier`            | host              | Trigger PK Battle speed multiplier `{ multiplier, durationSeconds }`  |
| `GET`    | `/lives/:id/summary`                      | host              | Post-live summary analytics report                                    |
| `POST`   | `/lives/:id/auctions`                     | host              | Create shop item                                                      |
| `GET`    | `/lives/:id/auctions/active`              | optional          | Active shops                                                          |
| `GET`    | `/lives/:id/auctions`                     | optional          | List shops                                                            |
| `GET`    | `/lives/:id/gallery`                      | optional          | Gallery tab (pinned + active)                                         |
| `PATCH`  | `/lives/:id/auctions/:auctionId/pin`      | host              | Pin gallery item                                                      |
| `PATCH`  | `/lives/:id/auctions/reorder`             | host              | Reorder gallery                                                       |
| `GET`    | `/lives/leaderboard/hourly`               | optional          | Hourly host rank                                                      |
| `GET`    | `/lives/:id/leaderboard/hourly`           | optional          | Live hourly rank                                                      |
| `GET`    | `/lives/:id/leaderboard/gifters`          | optional          | Top gifters                                                           |
| `GET`    | `/lives/leagues`                          | none              | League tier table                                                     |
| `GET`    | `/lives/host-league/:userId`              | optional          | Host league progress                                                  |
| `GET`    | `/creators/:creatorId/fan-club`           | optional          | Fan club info                                                         |
| `POST`   | `/creators/:creatorId/fan-club/subscribe` | required          | Join fan club                                                         |
| `DELETE` | `/creators/:creatorId/fan-club/subscribe` | required          | Leave fan club                                                        |
| `GET`    | `/users/me/fan-clubs`                     | required          | My fan clubs                                                          |
| `POST`   | `/gifts/send`                             | required          | Gift on live                                                          |
| `POST`   | `/lives/webhooks/livekit`                 | LiveKit signature | **Server-only** — not called by the mobile app (see admin/production) |


---

## 19. Hourly Ranking, Gallery, Fan Clubs & Leagues



### Interactive Tools

- **Gift Goals**: Set stream coin goal; updates emitted via `liveGiftGoalUpdate`.
- **Chat Rules**: Configure `chatMode` (`EVERYONE`, `FOLLOWERS`, `SUBSCRIBERS`), `slowModeSeconds` throttling, and `blockedKeywords` word filtering.
- **Polls**: Create interactive polls, vote with live percentage calculations via `livePollUpdated`.
- **Q&A Box**: Viewers ask questions; host marks answered/pinned via `liveQAUpdated`.
- **Treasure Boxes**: Coin drops with countdown timers; active viewers claim wallet coins via `liveTreasureBoxClaimed`.
- **PK Battle Speed Multipliers**: Host triggers 2x/3x points boost window emitted via `liveBattlePhase`.
- **Post-Live Summary**: Detailed report returning peak viewers, total watch duration, coins earned, and top 5 gifters.



### Hourly Ranking (ترتيب كل ساعة)


| Method | Path                                                 | Auth     | Description                                  |
| ------ | ---------------------------------------------------- | -------- | -------------------------------------------- |
| `GET`  | `/lives/leaderboard/hourly?limit=20`                 | optional | Global hourly host rank for current UTC hour |
| `GET`  | `/lives/:id/leaderboard/hourly`                      | optional | This live’s rank + score in the current hour |
| `GET`  | `/lives/:id/leaderboard/gifters?window=hour|session` | optional | Top gifters for this live                    |


**Scoring:** `hourlyCoins × 1 + viewers × 0.5 + likeCount × 0.05` (gifts in the current hour).

**Socket:** `liveHourlyRankUpdated`, `liveTopGiftersUpdated`

### Gallery Tab (المعرض)


| Method  | Path                                 | Auth     | Description                                       |
| ------- | ------------------------------------ | -------- | ------------------------------------------------- |
| `GET`   | `/lives/:id/gallery`                 | optional | Active shop items — pinned first, then `pinOrder` |
| `PATCH` | `/lives/:id/auctions/:auctionId/pin` | host     | Pin/unpin `{ "pinned": true }`                    |
| `PATCH` | `/lives/:id/auctions/reorder`        | host     | `{ "auctionIds": ["uuid", …] }` display order     |


**Socket:** `liveAuction` with `action: "pinned" | "unpinned" | "reordered"`

### Fan Club


| Method   | Path                                      | Auth     | Description                                    |
| -------- | ----------------------------------------- | -------- | ---------------------------------------------- |
| `GET`    | `/creators/:creatorId/fan-club`           | optional | Club info + `isMember` when authed             |
| `PATCH`  | `/creators/:creatorId/fan-club`           | host     | Enable/name `{ "enabled": true, "name": "…" }` |
| `POST`   | `/creators/:creatorId/fan-club/subscribe` | required | Join fan club (30-day subscription)            |
| `DELETE` | `/creators/:creatorId/fan-club/subscribe` | required | Leave fan club                                 |
| `GET`    | `/creators/:creatorId/fan-club/members`   | host     | Paginated member list                          |
| `GET`    | `/users/me/fan-clubs`                     | required | Clubs the viewer has joined                    |


Wire `chatMode: SUBSCRIBERS` to require an active `Subscription`.

**Socket:** `fanClubJoined` on `user_{creatorId}`

### Host League (e.g. رقم 17 في دوري B2)


| Method | Path                         | Auth     | Description               |
| ------ | ---------------------------- | -------- | ------------------------- |
| `GET`  | `/lives/leagues`             | none     | Tier definitions (D5 → S) |
| `GET`  | `/lives/host-league/:userId` | optional | Host tier + progress      |


**Live object / host card fields:**

- `user.hostLeagueTier` — e.g. `"B2"`
- `user.hostHeartCount` — profile total likes (TikTok-style heart count)
- `user.fanClub` — `{ enabled, name, memberCount }`

**Socket:** `hostLeagueUpdated` on `live_{liveId}` + `user_{hostId}` when tier changes after gifts.

### POPULAR Badge

Included on `GET /lives/feed`, `GET /lives/:id`, and join payload:

```json
{
  "isPopular": true,
  "popularReason": "hourly_rank",
  "hourlyRank": 5,
  "hourlyScore": 1250,
  "hourlyCoins": 800
}
```

**Reasons:** `admin_boost` | `hourly_rank` | `engagement` | `viewers`

**Socket:** `livePopularStatus` `{ liveId, isPopular, reason, hourlyRank }`

---



## 20. Errors


| HTTP  | Typical cases                                                                                                   |
| ----- | --------------------------------------------------------------------------------------------------------------- |
| `400` | Not broadcasting; guests disabled; requests off; seat full; already live; cannot battle self                    |
| `403` | Not host/mod; private account; followers-only requests; blocked; muted/banned from live; mod invited as CO_HOST |
| `404` | Live not found / banned publicly; comment/guest missing                                                         |


---



## 21. Gifter Level Badges (`Lv. X`)

Every viewer in a live stream has a **Gifter Level badge** (`Lv. 1` to `Lv. 50+`).


| Trigger           | Server action                                                           |
| ----------------- | ----------------------------------------------------------------------- |
| User sends a gift | `totalSpentCoins` incremented → level recalculated                      |
| Level increased   | `gifterLevel` updated on `User` + `userLevelUp` WebSocket event emitted |




### Socket event — `userLevelUp`

Room: `live_<liveId>` **and** `user_<userId>`

```json
{
  "userId": "abc123",
  "newLevel": 8,
  "currentXp": 10000,
  "nextLevelXp": 15000,
  "progressPercentage": 0,
  "liveId": "live456"
}
```



### Live comment user cards

All comment / chat payloads include the sender's `gifterLevel`:

```json
{
  "id": "…",
  "content": "🎁 Sent Rose",
  "user": {
    "id": "abc123",
    "username": "johndoe",
    "avatarUrl": "…",
    "isVerified": false,
    "gifterLevel": 7
  }
}
```

**Frontend:** Display a colored badge `[Lv. 7]` next to the username in live chat. Color tiers suggested:

- `Lv. 1–4`: Gray
- `Lv. 5–9`: Blue
- `Lv. 10–19`: Purple
- `Lv. 20–29`: Gold
- `Lv. 30+`: Diamond / animated

---



## 22. Related docs

- [enhanced-live-performance.md](./enhanced-live-performance.md) — **quality hints, share/remind, watch gates (mobile must-read)**  
- [logic.md](./logic.md) — architecture & state machines  
- [admin-api.md](./admin-api.md) — staff force end / ban / kick  
- [live-camera.md](./live-camera.md) — flip camera front ↔ back (`switchLiveCamera` / `liveCameraChanged`)  
- [live-promotions.md](./live-promotions.md) — TikTok-style LIVE promote (goal, audience, budget, duration)  
- [live-p0-parity.md](./live-p0-parity.md) — replay, report LIVE, shop bag, paid fan club, post-live stats  
- [live-p1-parity.md](./live-p1-parity.md) — RTMP studio, auto-record, Nearby, 18+, clips, host co-host, team PK  
- [live-p2-parity.md](./live-p2-parity.md) — pause, 3–4 host rooms, BO3 / power-ups, live look  
- [live-p3-parity.md](./live-p3-parity.md) — scene/dual cam, tickets, games, LIVE House, topic, profile `isLive`  
- [../events/mobile-api.md](../events/mobile-api.md) — Socket connect  
- [../gifts/mobile-api.md](../gifts/mobile-api.md) · [../auctions/mobile-api.md](../auctions/mobile-api.md)  
- [../seller-verification/mobile-api.md](../seller-verification/mobile-api.md) · [../notifications/mobile-api.md](../notifications/mobile-api.md)

