# Lives — viewer count changes

**When:** Thursday, 27 August 2026, 11:32 AM (UTC+3)  
**What:** Concurrent viewer count is now accurate for mobile and the admin dashboard.

Related: [mobile-api.md](./mobile-api.md) · [admin-api.md](./admin-api.md)

---

## What changed

`viewers` is the number of **open viewer sessions** (`leftAt` is null). It is recounted on join, leave, LiveKit presence, and live/admin detail.

| Before (27 Aug 2026, before 11:32) | After (27 Aug 2026, 11:32 AM UTC+3) |
|------------------------------------|-------------------------------------|
| Host not counted | Host **is** counted (start + join) |
| Only `POST /join` opened a session | LiveKit `participant_joined` also opens a session |
| Socket `leaveLive` did not decrement | `leaveLive` closes the session (same as `POST /leave`) |
| Guests who dropped stayed in the count | After the 10s grace, the session is closed |
| `GET /lives/:id` reused a stale number | Detail recounts open sessions while `LIVE` |
| Post-live `peakViewers` was `0` | `peakViewers` is stored and kept after end |

Same user on two devices still counts as **1**.

---

## Mobile

**Time:** 27 August 2026, 11:32 AM (UTC+3)

### What the app should show

- Host alone → `viewers: 1`
- Host + 3 unique joiners → `viewers: 4`
- Someone leaves (`POST /leave` or socket `leaveLive`) → count drops
- Listen to socket `liveViewers` `{ liveId, viewers }` for the HUD pill

### New / updated fields

| Field | Where | Meaning |
|-------|--------|---------|
| `viewers` | Live object, join, feed, `liveViewers` | Current unique people in the live (includes host) |
| `peakViewers` | Live object + `GET /lives/:id/summary` | Highest concurrent count during the stream (not reset on end) |

Example live object:

```json
{
  "id": "live-uuid",
  "status": "LIVE",
  "viewers": 4,
  "peakViewers": 12
}
```

### Client checklist

1. Always `POST /lives/:id/join` when opening a stream (host and viewers).
2. On exit: `POST /lives/:id/leave` **and** socket `leaveLive` **and** disconnect LiveKit.
3. Show `viewers` from the latest join/detail response or from `liveViewers`.
4. After the live ends, show **`peakViewers`** from `GET /lives/:id` or `GET /lives/:id/summary` (host only). Do **not** use `viewers` after end — it is always `0`. Older ended lives with `peakViewers: 0` are backfilled from viewer sessions on read.

No new endpoints. Existing join / leave / `joinLive` / `leaveLive` now keep the number in sync.

---

## Dashboard

**Time:** 27 August 2026, 11:32 AM (UTC+3)

### What ops should show

| Screen | Field | Notes |
|--------|--------|-------|
| Live queue / table | `viewers` | Current concurrent (includes host). Recalculated on admin detail. |
| Live detail `GET /lives/admin/:id` | `viewers` | Recounted if status is `LIVE` |
| Live detail | `peakViewers` | High-water mark for this stream |
| Post-live / `GET /lives/:id/summary` or admin summary | `peakViewers` | Real peak, not `0` |
| Moderation `uniqueViewerSessions` | all-time sessions | **Not** current viewers — people who joined at least once |

### Example admin live object

```json
{
  "id": "live-uuid",
  "status": "LIVE",
  "viewers": 4,
  "peakViewers": 12,
  "moderation": {
    "uniqueViewerSessions": 40
  }
}
```

### Dashboard checklist

1. HUD / table: bind **`viewers`** for “watching now”.
2. Recap / analytics: bind **`peakViewers`** for “peak”.
3. Do not treat `uniqueViewerSessions` as live concurrent.
4. Optional: socket `liveViewers` for a live ops wall without polling.

---

## Deploy (backend)

Required for `peakViewers` to persist:

```bash
npx prisma migrate deploy
npx prisma generate
```

Migration: `20260827120000_live_peak_viewers`  
LiveKit webhook `POST /lives/webhooks/livekit` should stay enabled so join/leave from the room updates the count.
