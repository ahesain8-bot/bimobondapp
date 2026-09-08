# LIVE docs

> **Audience:** Mobile, admin, and backend.  
> **Status:** P0–P3 + Voice Chat (audio rooms) are **in the API**. Apply migrations before calling new fields.

Start here, then open the file for the screen you are building.

| Read first | Why |
|------------|-----|
| **[endpoints2.md](./endpoints2.md)** | Every LIVE route + why it exists (source of truth for paths) |
| **[live-p3-parity.md](./live-p3-parity.md)** | Scene, tickets, games, LIVE House, topic, clip cut, profile `isLive` |
| **[live-audio-rooms.md](./live-audio-rooms.md)** | TikTok Voice Chat — `mediaMode: AUDIO` |
| **[mobile-api.md](./mobile-api.md)** | Full mobile guide (core LIVE) |
| **[production.md](./production.md)** | Deploy: LiveKit, Ingress, Egress, webhooks, firewall |

---

## Product layers (do not skip)

| Era | File | Ships |
|-----|------|-------|
| Core | [mobile-api.md](./mobile-api.md) · [logic.md](./logic.md) | Go live, feed, join, chat, gifts, guests, PK, shop, admin |
| P0 | [live-p0-parity.md](./live-p0-parity.md) | Replay, report, shop bag, paid fan club, post-live summary |
| P1 | [live-p1-parity.md](./live-p1-parity.md) | RTMP studio, auto-record, Nearby, 18+, clips, co-host, 2v2 |
| P2 | [live-p2-parity.md](./live-p2-parity.md) | Pause, 3–4 rooms, BO3, power-ups, look |
| P3 | [live-p3-parity.md](./live-p3-parity.md) | Scene/dual, tickets, games, House, topic, profile LIVE |
| Audio | [live-audio-rooms.md](./live-audio-rooms.md) | Voice Chat tab, mic-only tokens, raise-hand |

Older sample JSON: [endpoints.md](./endpoints.md) (core only — new routes are in **endpoints2**).

---

## Other files

| File | Use |
|------|-----|
| [admin-api.md](./admin-api.md) | Staff end / ban / boost / inspect |
| [database.md](./database.md) | Schema (includes P1–P3 columns) |
| [live-database.md](./live-database.md) | Longer DB essay — same Prisma source |
| [live-camera.md](./live-camera.md) | Front/back socket **and** `PATCH /scene` |
| [live-promotions.md](./live-promotions.md) | Paid For You slots |
| [tasks.md](./tasks.md) | Mobile/admin implementation recipes (core). Newer eras → parity files |
| [changes.md](./changes.md) | Viewer-count change note (27 Aug 2026) |
| [PERFORMANCE.md](./PERFORMANCE.md) · [enhanced-live-performance.md](./enhanced-live-performance.md) | Perf |

Profile LIVE badge: [users mobile-api](../users/mobile-api.md) · after-end history: [user sort an live info](../users/user%20sort%20an%20live%20info.md).

Sockets: [events mobile-api](../events/mobile-api.md).

---

## Migrations (run on each environment)

```bash
npx prisma migrate deploy
```

Includes: promotions, P0, P1, P2, audio rooms, P3 (`20260905190000_live_p3_parity`).
