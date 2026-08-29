# Enhanced Live Performance — Mobile Integration Guide

> **Audience:** iOS / Android / Flutter engineers building TikTok-style LIVE.  
> **Backend status:** Phase 1 & 3 quality hints, share/remind, watch gates, scheduled lives — implemented.  
> **Last updated:** 2026-08-24

This document tells the mobile team **what the backend now returns** and **what you must do on device** to get fast connect, good video quality, and TikTok-like discovery/engagement flows.

Related: [mobile-api.md](./mobile-api.md) · [logic.md](./logic.md) · [production.md](./production.md) · [PERFORMANCE.md](./PERFORMANCE.md)

---

## Table of contents

1. [Quick checklist](#1-quick-checklist)
2. [Live connect bundle](#2-live-connect-bundle)
3. [Apply `mediaHints` in LiveKit](#3-apply-mediahints-in-livekit)
4. [Apply `studioHints` (Camera Studio)](#4-apply-studiohints-camera-studio)
5. [Role-based quality presets](#5-role-based-quality-presets)
6. [Share flow](#6-share-flow)
7. [Remind me (scheduled lives)](#7-remind-me-scheduled-lives)
8. [Watch access gates](#8-watch-access-gates)
9. [Scheduled lives (host)](#9-scheduled-lives-host)
10. [Vertical swipe feed UX](#10-vertical-swipe-feed-ux)
11. [Socket HUD (gifts, hearts, viewer count)](#11-socket-hud-gifts-hearts-viewer-count)
12. [Production networking (TURN / WSS)](#12-production-networking-turn--wss)
13. [Error handling](#13-error-handling)
14. [What is NOT in scope yet](#14-what-is-not-in-scope-yet)

---

## 1. Quick checklist

Do these on every live screen:

| Step | Action |
|------|--------|
| 1 | Get connect bundle from HTTP only — never mint LiveKit JWTs on device |
| 2 | Read `mediaHints` from start / join / guest token responses |
| 3 | Connect LiveKit with `url` + `token`; apply hints (bitrate, resolution, adaptive stream) |
| 4 | Preload Camera Studio catalog when `studioHints.loadBeforeGoLive` is true (host/guest) |
| 5 | After HTTP join, call Socket `joinLive({ liveId })` for chat/gifts/HUD |
| 6 | On exit: HTTP `leave` + disconnect LiveKit + Socket `leaveLive` |
| 7 | Use `POST /lives/:id/share` for share sheet (do not invent share URLs) |
| 8 | Handle `403` on join when `watchAccessMode` blocks the viewer |
| 9 | Production: connect to `wss://` LiveKit URL with TURN enabled |

---

## 2. Live connect bundle

These endpoints return the same shape (live metadata + LiveKit credentials + hints):

| Endpoint | Role |
|----------|------|
| `POST /lives` with `startNow: true` | `host` |
| `POST /lives/:id/start` | `host` |
| `POST /lives/:id/join` | `viewer` (or `host` reconnect) |
| Guest accept / invite-accept / `POST …/guests/token` | `guest` / `co_host` |

```json
{
  "live": { "id": "…", "status": "LIVE", "watchAccessMode": "EVERYONE", "scheduledAt": null, "shareCount": 12, "…": "…" },
  "token": "<livekit-jwt>",
  "url": "wss://live.example.com",
  "role": "host",
  "mediaHints": { "…": "see section 5" },
  "studioHints": {
    "catalogPath": "/camera-studio/catalog",
    "colorFiltersPath": "/camera-studio/color-filters",
    "arEffectsPath": "/camera-studio/ar-effects",
    "filterSettingsSchemaPath": "/camera-studio/filter-settings/schema",
    "loadBeforeGoLive": true
  }
}
```

**Important:** `mediaHints` and `studioHints` are computed server-side from current room state (viewer count, guests on stage). Re-fetch on reconnect or role change — do not cache across sessions.

---

## 3. Apply `mediaHints` in LiveKit

The backend sends **recommendations only**. Encoding still happens in your LiveKit SDK.

### Host / guest / co_host (publish)

1. Connect room with `adaptiveStream` and `dynacast` from hints.
2. Enable camera + mic when `canPublish === true`.
3. Map `maxVideoResolution` → capture/publish resolution:

| Hint value | Suggested capture |
|------------|-------------------|
| `1080p` | 1920×1080 |
| `720p` | 1280×720 |
| `480p` | 854×480 |
| `360p` | 640×360 |

4. Set video publish bitrate to `maxBitrateKbps` (kbps).
5. Enable simulcast when `simulcast === true`.
6. Prefer first codec in `codecPreference` (usually `h264` on iOS).

### Viewer (subscribe only)

1. Do **not** publish camera/mic (`canPublish === false`).
2. Enable `adaptiveStream: true` on the room.
3. Cap subscribe quality using `maxSubscribeResolution` (720p default; 480p when room is very large — see section 5).

### Flutter example

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
    await room.localParticipant?.setMicrophoneEnabled(true);
    // Apply VideoPublishOptions from maxVideoResolution + maxBitrateKbps
  }
}
```

### When hints change

Refresh token (re-join HTTP or guest token refresh) when:

- Viewer count crosses thresholds (solo host may drop from 1080p → 720p).
- Guest joins/leaves stage (host bitrate/resolution may change).
- User is promoted/demoted on stage.

---

## 4. Apply `studioHints` (Camera Studio)

For host and on-stage guests, load beauty/AR assets **before** going live when `loadBeforeGoLive` is true.

| Path | Use |
|------|-----|
| `GET {API}{catalogPath}` | Full filter/effect catalog |
| `GET {API}{colorFiltersPath}` | Color filters |
| `GET {API}{arEffectsPath}` | AR effects |
| `GET {API}{filterSettingsSchemaPath}` | Settings schema for UI sliders |

Apply filters **client-side on the camera track** before publishing to LiveKit. The SFU receives already-processed video.

---

## 5. Role-based quality presets

Source: `src/livekit/live-media-hints.ts`

| Role | Publish resolution | Bitrate | Subscribe cap | Notes |
|------|-------------------|---------|---------------|-------|
| **host** (solo, &lt;200 viewers) | **1080p** | **4500 kbps** | 720p | Best quality when alone on stage |
| **host** (with guests or ≥200 viewers) | 720p | 3000 kbps | 720p | Saves uplink when crowded |
| **co_host** | 480p (360p if &gt;4 on stage) | 1500 / 800 kbps | 720p | |
| **guest** | 480p (360p if &gt;4 on stage) | 1200 / 800 kbps | 720p | |
| **viewer** | none | 0 | 720p (480p if &gt;500 viewers) | Subscribe-only, adaptive |

All publishers: `simulcast: true`, `adaptiveStream: true`, `dynacast: true`, `codecPreference: ["h264", "vp8"]`.

---

## 6. Share flow

**Endpoint:** `POST /lives/:id/share`  
**Auth:** required  
**Body (optional):**

```json
{ "channel": "COPY_LINK" }
```

`channel` values: `COPY_LINK` · `EXTERNAL` · `MESSAGES` · `STORY` (analytics only; backend accepts any string).

**Response:**

```json
{
  "success": true,
  "liveId": "…",
  "shareUrl": "https://app.example.com/lives/…",
  "deepLink": "dcc://lives/…",
  "shareCount": 42,
  "title": "My Live",
  "host": { "id": "…", "username": "…", "fullName": "…" },
  "coverUrl": "…",
  "status": "LIVE",
  "watchAccessMode": "EVERYONE"
}
```

### What mobile should do

1. Call this API when the user taps Share (before or after opening the native share sheet).
2. Use `shareUrl` for link copy / external apps; use `deepLink` for in-app routing (`dcc://lives/{id}`).
3. Show updated `shareCount` if you display share stats (optional).
4. Works for `LIVE`, `PLANNED`, and ended lives (not `BANNED` — returns 404).

---

## 7. Remind me (scheduled lives)

**Endpoint:** `POST /lives/:id/remind`  
**Auth:** required · **Body:** none

Registers the current user for push when:

- A **scheduled** live is about to start (`LIVE_SCHEDULED_SOON` ~5 min before).
- The live **starts** (existing `LIVE_STARTED` flow for reminders).

**Response:**

```json
{
  "success": true,
  "liveId": "…",
  "reminded": true,
  "scheduledAt": "2026-08-25T12:00:00.000Z",
  "message": "You will be notified when this live starts"
}
```

### UI guidance

- Show **Remind me** on `PLANNED` live detail / host profile when `scheduledAt` is set.
- Hide or disable for the host (API returns 400).
- On tap → POST remind → toggle button to “Reminder set”.
- Handle push `LIVE_SCHEDULED_SOON` with deep link to live detail (countdown screen).

---

## 8. Watch access gates

Live objects include `watchAccessMode`:

| Value | Who can join |
|-------|----------------|
| `EVERYONE` | Any authenticated user |
| `FOLLOWERS` | Users who follow the host |
| `SUBSCRIBERS` | Active fan-club subscribers |

Set by host on create/update (`watchAccessMode` in `POST /lives` or settings).

### Join behavior

`POST /lives/:id/join` runs the gate **before** issuing a token.

| HTTP | Meaning | Mobile action |
|------|---------|---------------|
| **403** | `"Follow the host to watch this live"` | Show follow CTA, then retry join |
| **403** | `"Join the fan club to watch this live"` | Show subscribe / fan club CTA |
| **200** | Token issued | Proceed to LiveKit + Socket |

Show lock icon / teaser on feed cards when the viewer fails the gate (use feed detail + local follow state to preview UI before join).

---

## 9. Scheduled lives (host)

Create with a future start time:

```json
POST /lives
{
  "title": "Q&A tonight",
  "scheduledAt": "2026-08-25T20:00:00.000Z",
  "watchAccessMode": "FOLLOWERS"
}
```

Rules:

- `scheduledAt` must be in the **future**.
- Do not combine `scheduledAt` with `startNow: true`.
- Live starts in `PLANNED` until host calls `POST /lives/:id/start`.
- Backend schedules reminder jobs (5 min before + at start).

Host flow: create → show countdown → `start` at go-time → receive connect bundle with `mediaHints`.

---

## 10. Vertical swipe feed UX

Recommended TikTok-style behavior (client-side; backend supports via fast join + hints):

1. **Prefetch** next live metadata from feed API while user watches current room.
2. **Pre-warm** Socket: stay connected; swap `joinLive` / `leaveLive` on swipe.
3. **Defer** full LiveKit connect until the card is visible (&gt;50% viewport) to save battery.
4. On swipe away: HTTP `leave` previous live, disconnect LiveKit, then join next.
5. Show placeholder (cover + host avatar) until first video frame.
6. Respect `watchAccessMode` on card — show blur/teaser instead of attempting join.

Latency target: &lt;500 ms from swipe settle to first frame on good Wi‑Fi (depends on TURN path and hint-appropriate subscribe tier).

---

## 11. Socket HUD (gifts, hearts, viewer count)

HTTP is authority; Socket is realtime UI.

After successful `POST /lives/:id/join`:

```js
socket.emit('joinLive', { liveId });
```

Listen on room `live_{liveId}`:

| Event | UI |
|-------|-----|
| `liveComment` | Chat bubble |
| `liveGift` | Gift animation + coin HUD |
| `liveViewers` | Viewer count |
| `liveLike` / heart burst | Floating hearts (likes also via HTTP `POST …/like`) |
| `liveGuestUpdate` | Stage layout / mute overlays |
| `liveEnded` | Tear down LiveKit + navigate away |

Like spam: backend rate-limits likes (Redis when available). Debounce rapid tap bursts on client anyway.

---

## 12. Production networking (TURN / WSS)

| Requirement | Detail |
|-------------|--------|
| LiveKit URL | Must be **`wss://`** in production |
| TURN | Required for cellular / strict NAT; see `deploy/livekit.yaml` |
| Token TTL | ~6 hours — reconnect via HTTP join on expiry |
| Room cleanup | Backend deletes LiveKit room on end/ban — handle disconnect gracefully |

See [production.md](./production.md) for env vars and smoke tests.

---

## 13. Error handling

| Scenario | HTTP | Action |
|----------|------|--------|
| Live banned / missing | 404 | Remove from feed |
| Not broadcasting | 400 | Show “Live ended” |
| Watch gate | 403 | Follow / subscribe CTA |
| Remind on ended live | 400 | Hide remind button |
| Host self-remind | 400 | Hide remind for host |
| Rate-limited like | 429 | Back off UI |

Always call `POST /lives/:id/leave` when exiting, even on errors, to keep viewer counts accurate.

---

## 14. What is NOT in scope yet

Backend / infra items planned for later (mobile does not need to block on these):

- LiveKit egress → HLS for passive CDN viewers
- Live recording / replay pipeline
- LiveKit multi-node clustering
- Auto thumbnail generation from stream

---

## Summary for mobile leads

1. **Quality** — Implement `mediaHints` on every connect; expect 1080p solo host, adaptive viewer subscribe.
2. **Beauty** — Preload `studioHints` paths before go-live.
3. **Growth** — Wire share (`POST …/share`) and remind (`POST …/remind`) into profile and live UI.
4. **Access** — Handle `watchAccessMode` before join; show CTAs on 403.
5. **Realtime** — HTTP join + Socket HUD + LiveKit media; never skip HTTP leave on swipe.

Questions → backend team or [mobile-api.md](./mobile-api.md) endpoint reference.
