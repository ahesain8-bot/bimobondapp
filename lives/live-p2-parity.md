# LIVE P2 parity (TikTok feel)

> Pause without ending, **3–4 host rooms**, **BO3 + PK power-ups**, and a **look** (beauty / filter / effect) bound to the live.  
> Related: [README.md](./README.md) · [live-p1-parity.md](./live-p1-parity.md) · [live-p3-parity.md](./live-p3-parity.md) · [mobile-api.md](./mobile-api.md) · **[endpoints2.md](./endpoints2.md)**

P0/P1 stay as they are. Status is still `LIVE` while paused — the room is not torn down.

---

## 1. Pause / resume

```http
POST /lives/:id/pause
POST /lives/:id/resume
```

Host only. Status stays `LIVE`. Feed still shows the card with `paused: true`.

| Still works | Blocked |
|-------------|---------|
| Join, watch, gifts, likes, comments | Guest **requests**, starting a PK |
| Host reconnect token | Host-disconnect auto-end (paused on purpose) |

```json
{ "paused": true, "pausedAt": "2026-09-05T12:00:00.000Z" }
```

Socket `livePaused` `{ paused, pausedAt }`.

---

## 2. Co-host up to 4 rooms

P1 was a pair. A live can now have **3 partners** (4 tiles including self).

Invite again while you have a free slot. `GET /lives/:id/cohost/hosts` hides only hosts already at capacity.

Join/start payload:

```json
{
  "cohost": { "liveId": "…", "token": "…", "url": "…" },
  "cohosts": [
    { "liveId": "…", "token": "…", "url": "wss://…", "role": "viewer", "host": {} },
    { "liveId": "…", "token": "…", "url": "wss://…", "role": "viewer", "host": {} }
  ]
}
```

`cohost` is the first partner (old clients). Tile every `cohosts[]` room as a subscribe-only LiveKit connection.

---

## 3. BO3 + power-ups

```http
POST /lives/:id/battle
{ "opponentLiveId": "…", "bestOf": 3 }
```

`bestOf` `1` (default) or `3`. When a round clock hits, scores reset and `roundNumber` increments until a side has 2 wins. Host `end` finishes the **series**.

```json
{
  "bestOf": 3,
  "roundNumber": 2,
  "wins1": 1,
  "wins2": 0,
  "powerUps": {
    "stunTeam": 2,
    "stunEndsAt": "…",
    "gloveTeam": 1,
    "gloveCharges": 1
  }
}
```

Socket `liveBattle` `type: "round"` between games.

```http
POST /lives/:id/battle/:battleId/power-up
{ "type": "GLOVE" }
```

| Type | Effect |
|------|--------|
| `STUN` | Opponent team cannot score for 8s |
| `TIME` | Adds 30s to `endTime` |
| `GLOVE` | Next opponent gift scores for **your** team |
| (existing) multiplier | `POST /lives/:id/battle/multiplier` |

Socket `liveBattlePhase` `{ type: "power_up", powerUp, team, battle }`.

---

## 4. Look (beauty / filter / effect)

Bound to the **live**, not only the phone. Catalog is still `GET /camera-studio/catalog` — the app applies it on the track.

```http
PATCH /lives/:id/look
{
  "beautyEnabled": true,
  "filterSlug": "soft-glow",
  "effectSlug": "sparkle",
  "filterSettings": { "smooth": 0.4 }
}
```

Also on `PATCH /lives/:id/settings` (`beautyEnabled`, `filterSlug`, `effectSlug`).

Live object:

```json
"look": {
  "beautyEnabled": true,
  "filterSlug": "soft-glow",
  "effectSlug": "sparkle",
  "filterSettings": { "smooth": 0.4 }
}
```

Socket `liveLook` with the same shape. Other devices on the room should apply the new look.

---

## App checklist

1. Pause button → `POST /pause`. Freeze the player; keep the socket. Resume → `POST /resume`.
2. Co-host HUD: connect **every** `cohosts[]` room (up to 3 extra).
3. PK: offer BO3. Bind `wins1`/`wins2`/`roundNumber`. Power-up buttons: GLOVE / TIME / STUN.
4. After catalog load, persist the host look with `PATCH /look` so guests match.

Apply DB:

```bash
npx prisma generate
npx prisma migrate deploy
```
