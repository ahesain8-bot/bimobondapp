# Lives — Admin / Dashboard Developer Guide

> **Audience:** admin dashboard & ops frontend developers.  
> **Base path:** `/lives/admin/...` (plus shared read endpoints under `/lives/...`)  
> Architecture: [logic.md](./logic.md) · Endpoints Ref: [endpoints.md](./endpoints.md) · Tasks: [tasks.md](./tasks.md) · Database: [database.md](./database.md) · Mobile app: [mobile-api.md](./mobile-api.md) · Production: [production.md](./production.md)  
> RBAC: [../rbac/logic.md](../rbac/logic.md) · Conventions: [../_shared/conventions.md](../_shared/conventions.md)

---

## Table of contents

1. [What you use (and for what)](#1-what-you-use-and-for-what)
2. [Auth, RBAC & boot sequence](#2-auth-rbac--boot-sequence)
3. [Ops product flows (do this)](#3-ops-product-flows-do-this)
4. [Admin-only endpoints](#4-admin-only-endpoints)
5. [Shared read endpoints (staff-friendly)](#5-shared-read-endpoints-staff-friendly)
6. [Realtime monitoring](#6-realtime-monitoring)
7. [Live object (admin view)](#7-live-object-admin-view)
8. [Endpoint index](#8-endpoint-index)
9. [UI / screen checklist](#9-ui--screen-checklist)
10. [Errors](#10-errors)
11. [Related docs](#11-related-docs)

---

## 1. What you use (and for what)

| System | Admin dashboard uses it for |
|--------|-----------------------------|
| **Nest HTTP + RBAC** | List lives, force end, ban, force-kick guests, inspect comments/guests/auctions |
| **Socket.IO** (optional) | Live ops wall: comments, gifts, guest events, `liveEnded` |
| **LiveKit** | Usually **not** needed in admin UI — ending/banning deletes the room server-side |

```
Dashboard ──Bearer + permission──► Nest /lives/admin/*
     │
     └── optional Socket joinLive ──► live_{id} HUD (monitor only)
```

**Important**

- Admin routes do **not** replace host tools (invite, settings, promote). For policy issues use **end / ban / kick**.
- Ban is stronger than end: public detail becomes **404**; `banReason` is stored on the live.
- End and ban both: finish battles → cancel ACTIVE auctions → delete LiveKit room → clear sessions/guests/restrictions.

---

## 2. Auth, RBAC & boot sequence

```http
Authorization: Bearer <Firebase ID token>
Content-Type: application/json
```

### Boot the dashboard

| Step | Call | Do this |
|------|------|---------|
| 1 | Firebase sign-in | Staff user |
| 2 | `POST /auth/login` | Sync DB user |
| 3 | `GET /rbac/me` | Read `permissions[]` |
| 4 | Gate every Lives admin screen | Hide UI without the right keys |

### Permissions

| Permission | Capability | Gate these screens / buttons |
|------------|------------|------------------------------|
| `lives.admin.read` | List / inspect lives | Lives list, filters, open detail |
| `lives.admin.moderate` | Force end, ban, kick guest | End, Ban, Kick buttons |

Typical system roles with these keys: **moderator**, **admin**, **super_admin** (see permission catalog).

Missing permission → **403**:

```json
{
  "message": "Insufficient permissions",
  "missingPermissions": ["lives.admin.moderate"]
}
```

After changing role grants, staff must refresh `GET /rbac/me`.

Defined in `src/rbac/permission-catalog.ts`:

| Key | Group | Label |
|-----|-------|-------|
| `lives.admin.read` | LIVES | List / view lives (admin) |
| `lives.admin.moderate` | LIVES | End or ban live streams |

---

## 3. Ops product flows (do this)

### A. Moderate a bad stream

| Step | Action | Endpoint |
|------|--------|----------|
| 1 | Find the stream | `GET /lives/admin/all?status=LIVE&search=` |
| 2 | Inspect detail / guests / comments | `GET /lives/:id`, `…/guests`, `…/comments` |
| 3a | Soft stop (accidental / off-topic) | `POST /lives/admin/:id/end` → `ENDED` |
| 3b | Policy violation | `POST /lives/admin/:id/ban` `{ reason }` → `BANNED` |

**Prefer**

- **End** — accidental go-live, technical issues, host asked for help  
- **Ban** — policy / abuse; stream must not appear as a normal ended live in public UIs  

Both emit Socket `liveEnded` so watching clients disconnect.

### B. Remove a toxic guest (keep stream up)

| Step | Action |
|------|--------|
| 1 | `GET /lives/:id/guests` — find `userId` with `status: "ACTIVE"` |
| 2 | `POST /lives/admin/:id/guests/:userId/kick` |

Effects: guest → `KICKED`, LiveKit forced disconnect, `liveGuestUpdate` `{ type: "kicked" }`.  
Does **not** end the stream. For host abuse, use end/ban instead.

### C. Investigate live shopping / gifts

| Need | Where |
|------|--------|
| Auctions on this live | `GET /lives/:id/auctions?status=ALL` |
| Admin auction tools | [../auctions/admin-api.md](../auctions/admin-api.md) |
| Gift reports by live | [../gift-reports/admin-api.md](../gift-reports/admin-api.md) |

After end/ban, confirm ACTIVE auctions cancelled (HUD clear; auction admin if stuck).

### D. Watch a live in realtime (optional)

1. Staff Firebase user + Socket connect  
2. `joinLive({ liveId })` — identity comes from the socket session (do not spoof `userId`)  
3. Render `liveComment`, `liveGift`, `liveGuestUpdate`, `liveEnded`, etc.  

Socket checks ban/block like mobile; it is **not** RBAC-gated — protect the dashboard route itself.

### E. LiveKit webhook (ops / infra)

LiveKit calls `POST /lives/webhooks/livekit` with a signed header (not Firebase). Used so host disconnect / room finish ends the DB live even if the client never hit `/end`. See endpoint index §8 and [production.md](./production.md).

---

## 4. Admin-only endpoints

### `GET /lives/admin/all`

**Permission:** `lives.admin.read`

| Query | Type | Notes |
|-------|------|-------|
| `page` | int ≥ 1 | default 1 |
| `limit` | int | default 20, max 100 |
| `status` | string | `PLANNED` \| `LIVE` \| `ENDED` \| `BANNED` |
| `userId` | UUID | filter by host |
| `search` | string | title / host username (case-insensitive) |

**Use for:** ops queue (`status=LIVE`), history (`ENDED` / `BANNED`), host lookup.

**Response**

```json
{
  "data": [
    {
      "id": "…",
      "userId": "…",
      "title": "…",
      "roomName": "live_…",
      "streamUrl": "ws://…",
      "coverUrl": null,
      "categoryId": null,
      "status": "LIVE",
      "banReason": null,
      "viewers": 120,
      "likeCount": 40,
      "totalEarnedCoins": 9000,
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
      "category": null
    }
  ],
  "meta": {
    "total": 50,
    "page": 1,
    "limit": 20,
    "totalPages": 3
  }
}
```

Show multi-guest settings so support can see if requests are off / seat cap is low.  
Show `banReason` when `status === "BANNED"`.

---

### `POST /lives/admin/:id/end`

**Permission:** `lives.admin.moderate` · **Body:** none

Sets status **`ENDED`** — same teardown as host end:

1. Finish ACTIVE battles  
2. Cancel ACTIVE live auctions (escrow refund when enabled)  
3. Delete LiveKit room  
4. Close viewer sessions; guests → `LEFT`  
5. Clear `LiveViewerRestriction`  
6. Emit `liveEnded` `{ liveId, status: "ENDED" }`

| Case | Behavior |
|------|----------|
| Already `ENDED` / `BANNED` | Returns current shaped live (idempotent) |
| Missing id | `404` Live not found |

**UI:** disable End when already terminal; show toast; refresh list row.

---

### `POST /lives/admin/:id/ban`

**Permission:** `lives.admin.moderate`

```json
{ "reason": "policy violation" }
```

| Field | Required | Notes |
|-------|----------|-------|
| `reason` | no | max 500; **stored** as `banReason` and included in `liveEnded` |

Sets **`BANNED`**, `endedAt = now`, `viewers = 0`, full teardown (same as end + ban reason).

**Socket:** `liveEnded` `{ liveId, status: "BANNED", reason: "…" }`

Public `GET /lives/:id` treats banned as **404**.

**UI:** require confirm dialog; optional reason field; show reason in banned history table.

---

### `POST /lives/admin/:id/boost`

**Permission:** `lives.admin.moderate`

```json
{ "durationMinutes": 60 }
```

| Field | Required | Notes |
|-------|----------|-------|
| `durationMinutes` | no | default 60, max 10080 (7 days) |

Sets `feedBoostUntil` so the live ranks higher in the For You feed while `LIVE`.

**Response:** shaped live including `feedBoostUntil`.

---

### `POST /lives/admin/:id/guests/:userId/kick`

**Permission:** `lives.admin.moderate`

Force-remove a guest regardless of host/mod assignment.

| Effect | Detail |
|--------|--------|
| DB | Guest status → `KICKED` |
| LiveKit | Participant removed / publish revoked |
| Socket | `liveGuestUpdate` `{ type: "kicked", guest }` |

| Error | When |
|-------|------|
| `400` | Trying to kick the host |
| `404` | Live or guest row missing |

**UI:** only enable for guests with `ACTIVE` / on-stage rows; do not offer “kick host”.

---

## 5. Shared read endpoints (staff-friendly)

These are the same paths as mobile. Staff Bearer tokens work; some privacy checks allow staff roles to view private hosts on detail/join where implemented.

| Use case | Endpoint | Auth / permission |
|----------|----------|-------------------|
| Live detail + active auctions | `GET /lives/:id` | optional / staff |
| Guest list | `GET /lives/:id/guests` | optional |
| Comments | `GET /lives/:id/comments` | optional |
| Battle state | `GET /lives/:id/battle` | optional |
| Active polls | `GET /lives/:id/polls/active` | optional |
| Q&A box questions | `GET /lives/:id/qa` | optional |
| Treasure boxes | `GET /lives/:id/treasure-boxes` | optional |
| Hourly rank & gifters | `GET /lives/:id/leaderboard/hourly`, `…/gifters` | optional |
| Auction list for live | `GET /lives/:id/auctions?status=ALL` | optional |
| Cancel/ban individual auction | Auctions admin | auction permissions |

**Do not** use host-only mobile routes (settings, invite, promote) as admin overrides — use force end / ban / kick.

Full shapes: [mobile-api.md](./mobile-api.md).

---

## 6. Realtime monitoring

Optional Socket.IO for a live ops wall.

| Message | Payload | Notes |
|---------|---------|-------|
| `joinLive` | `{ liveId, userId }` | Both required; `userId` = staff user id |
| `leaveLive` | `{ liveId }` | Leave monitor room |

Useful events: `liveComment`, `liveGift`, `liveViewers`, `liveGuestUpdate`, `liveBattle`, `liveBattlePhase`, `livePollUpdated`, `liveQAUpdated`, `liveTreasureBoxSpawned`, `liveTreasureBoxClaimed`, `liveAuction`, `liveEnded`, `liveModeration`, `liveCommentDeleted`.

When `liveEnded` fires, mark the row offline and stop the monitor subscription.

---

## 7. Live object (admin view)

Same shape as mobile, plus pay attention to:

| Field | Admin meaning |
|-------|----------------|
| `status` | Queue filter + badge color |
| `banReason` | Shown when `BANNED` |
| `feedBoostUntil` | Active admin feed boost expiration |
| `viewers` / `likeCount` / `totalEarnedCoins` | Ops metrics |
| `guestsEnabled` / `guestRequestMode` / `maxGuests` | Support context |
| `startedAt` / `endedAt` | Duration / SLA |
| `user` | Link to user admin profile |

Status machine:

```
PLANNED → LIVE → ENDED
              ↘ BANNED
```

---

## 8. Endpoint index

### Admin-only (`PermissionsGuard`)

| Method | Path | Permission | What it does |
|--------|------|------------|--------------|
| `GET` | `/lives/admin/all` | `lives.admin.read` | Paginated list + filters |
| `POST` | `/lives/admin/:id/end` | `lives.admin.moderate` | Force end → `ENDED` |
| `POST` | `/lives/admin/:id/ban` | `lives.admin.moderate` | Ban → `BANNED` + `banReason` |
| `POST` | `/lives/admin/:id/boost` | `lives.admin.moderate` | Feed boost window (`durationMinutes`) |
| `POST` | `/lives/admin/:id/guests/:userId/kick` | `lives.admin.moderate` | Force kick guest |

### Shared (useful in dashboard)

| Method | Path | What it does |
|--------|------|--------------|
| `GET` | `/lives/:id` | Detail + `activeAuctions` |
| `GET` | `/lives/:id/guests` | Stage / requests |
| `GET` | `/lives/:id/comments` | Chat history |
| `GET` | `/lives/:id/battle` | PK state |
| `GET` | `/lives/:id/polls/active` | Active poll state & votes |
| `GET` | `/lives/:id/qa` | Q&A questions list |
| `GET` | `/lives/:id/treasure-boxes` | Active coin drops |
| `GET` | `/lives/:id/leaderboard/hourly` | Live rank in current hour |
| `GET` | `/lives/:id/leaderboard/gifters` | Live top gifters |
| `GET` | `/lives/:id/auctions` | Shopping on this live |

### Infrastructure (not dashboard UI)

| Method | Path | Auth | What it does |
|--------|------|------|--------------|
| `POST` | `/lives/webhooks/livekit` | LiveKit webhook signature (`Authorization` / `Authorize`) | Presence + zombie cleanup (host leave / room finished) |

**Not** a Firebase user endpoint. Configure LiveKit `webhook.urls` → this path. Details: [logic.md](./logic.md#livekit-webhooks) · [production.md](./production.md).

---

## 9. UI / screen checklist

Build these screens (minimum):

| Screen | Permissions | Actions |
|--------|-------------|---------|
| **Lives queue** | `read` | Table: status, title, host, viewers, earnings, startedAt; filters; search |
| **Live detail** | `read` | Metadata, guests, comments, auctions, battle; optional Socket monitor |
| **End confirm** | `moderate` | Call end; refresh row |
| **Ban confirm** | `moderate` | Reason field; call ban; show `banReason` in history |
| **Kick guest** | `moderate` | From guest list; confirm |

**Ops habits**

1. Gate every admin live screen on `lives.admin.*`.  
2. Prefer **end** for accidents; **ban** for policy.  
3. After end/ban, verify auctions cleared.  
4. Guest harassment → kick first; escalate to stream ban / user ban ([users admin](../users/admin-api.md)).  
5. If DB shows ended but clients stay connected → check LiveKit credentials / room-delete logs.

---

## 10. Errors

| HTTP | Case |
|------|------|
| `401` | Missing / invalid Firebase token |
| `403` | Missing `lives.admin.*` permission |
| `404` | Live or guest not found |
| `400` | Kick host; validation (e.g. reason too long) |

---

## 11. Related docs

- [mobile-api.md](./mobile-api.md) — full app API (shapes, sockets, gifts)  
- [logic.md](./logic.md) — teardown order, battles, restrictions  
- [production.md](./production.md) — deploy, firewall, smoke tests  
- [../rbac/admin-api.md](../rbac/admin-api.md) · [../rbac/logic.md](../rbac/logic.md)  
- [../auctions/admin-api.md](../auctions/admin-api.md) · [../gift-reports/admin-api.md](../gift-reports/admin-api.md)  
- [../events/admin-api.md](../events/admin-api.md) · [../users/admin-api.md](../users/admin-api.md)
