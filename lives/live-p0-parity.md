# LIVE P0 parity (TikTok gaps)

> What we just shipped so LIVE matches TikTok’s must-have product: **replay**, **report this LIVE**, **shop bag deals**, **paid subscription tiers + emotes**, and **post-live traffic / new followers / watch time**.  
> Related: [mobile-api.md](./mobile-api.md) · **[endpoints2.md](./endpoints2.md)** · [live-promotions.md](./live-promotions.md) · [P1 parity](./live-p1-parity.md) · [products shop](../products/shop-readme.md) · [fan club in lives logic](./logic.md)

Admin `feedBoostUntil` and creator-paid [live promotions](./live-promotions.md) are unchanged.

---

## 1. Replay (90 days)

TikTok keeps a replay after the stream. **P1** can auto-record via LiveKit Egress when `replayEnabled` is true and the egress worker + S3 are configured ([live-p1-parity.md](./live-p1-parity.md) · [production.md](./production.md)). If Egress is down, the host (or the app) still **publishes a video URL** with `POST /lives/:id/replay`.

| | |
|--|--|
| Default | `replayEnabled: true` on create |
| Toggle | `PATCH /lives/:id` or `PATCH /lives/:id/settings` `{ "replayEnabled": false }` |
| Publish | `POST /lives/:id/replay` `{ "replayUrl": "https://…/replay.mp4" }` |
| Watch | `GET /lives/:id/replay` — increments `viewCount` |
| Remove | `DELETE /lives/:id/replay` |
| TTL | 90 days (`LIVE_REPLAY_TTL_DAYS`) |

Statuses: `NONE` → `READY` → `EXPIRED` or `REMOVED`.

Banned lives have no public replay. Viewers can only watch after `ENDED` (host can preview earlier). `GET /lives/:id` includes:

```json
"replay": {
  "enabled": true,
  "status": "READY",
  "available": true,
  "expiresAt": "2026-12-04T10:00:00.000Z",
  "viewCount": 12,
  "url": "https://…/replay.mp4"
}
```

`url` is only filled on `ENDED` + `READY`. Use `GET /lives/:id/replay` to count a view.

---

## 2. Report this LIVE

```http
POST /lives/:id/report
{ "reason": "Spam / scam" }
```

Same as:

```http
POST /reports
{ "liveId": "…", "reason": "Spam / scam" }
```

Sets `reportedUserId` to the host. Host cannot report themselves. Admin queue: `GET /reports?type=live` or `?liveId=`.

---

## 3. Shop bag (flash + coupon)

Existing shelf: `GET /products/lives/:liveId/items`.

Host sets a **live-only** deal:

```http
PATCH /products/lives/:liveId/items/:productId/deal
{
  "flashPriceCoins": 70,
  "flashEndsAt": "2026-09-05T18:00:00.000Z",
  "couponCode": "LIVE10",
  "couponOffCoins": 10
}
```

Bag item extra:

```json
"bag": {
  "basePriceCoins": 100,
  "livePriceCoins": 70,
  "flashActive": true,
  "hasCoupon": true,
  "dealApplied": "flash",
  "soldCount": 3
}
```

Checkout from the bag:

```http
POST /products/checkout
{
  "liveId": "…",
  "couponCode": "LIVE10",
  "items": [{ "productId": "…", "quantity": 1 }],
  "paymentMethod": "COINS"
}
```

Preview accepts the same `liveId` + `couponCode`. Flash applies first, then coupon. `soldCount` increments on paid orders. Socket `liveProduct` action `deal` when the host changes the deal.

---

## 4. LIVE subscriptions (tiers + emotes)

Fan club is **paid in coins** (no longer free). Default BASIC price is `User.fanClubPriceCoins` (50). PLUS = 3×, PREMIUM = 6× unless the host inserts `FanClubTier` rows.

```http
PATCH /creators/:id/fan-club
{ "enabled": true, "name": "Inner Circle", "priceCoins": 50 }

POST /creators/:id/fan-club/subscribe
{ "tierSlug": "PLUS" }

POST /creators/:id/fan-club/emotes
{ "code": "fire", "imageUrl": "/uploads/emotes/fire.png", "minTier": "PLUS" }
```

`GET /creators/:id/fan-club` now returns `tiers`, `emotes`, and `membership` (`tierSlug`, `loyalty` badge: new / 3 / 6 / 12 months).

Money: 80% to the creator wallet, 20% platform (`FAN_CLUB_SUBSCRIBE` / `FAN_CLUB_REVENUE`). Same-or-higher active tier is a no-op (`alreadyMember`). Higher tier is an upgrade (new charge, keep original `startDate` for loyalty).

Chat still uses `chatMode` / `watchAccessMode` = `SUBSCRIBERS`. App should only send emotes whose `minTier` ≤ the viewer’s `tierSlug`.

---

## 5. Post-live stats

`POST /lives/:id/join` body:

```json
{ "campaignId": "optional-promo-id", "trafficSource": "FOR_YOU" }
```

Buckets: `FOR_YOU` · `FOLLOWING` · `PROFILE` · `SEARCH` · `SHARES` · `NOTIFICATION` · `CHAT` · `PROMOTE` · `OTHER`.  
If `campaignId` is sent and `trafficSource` is omitted → `PROMOTE`. First join wins (rejoin does not overwrite).

`leave` (and live end) add elapsed seconds onto `LiveViewerSession.watchSeconds`.

`GET /lives/:id/summary` (host) extra fields:

| Field | Meaning |
|-------|---------|
| `uniqueViewers` | Session rows |
| `totalWatchSeconds` | Accumulated watch + still-open sessions |
| `avgWatchSeconds` | Mean stored watch |
| `newFollowers` | Follows of the host created while the live was up |
| `shareCount` | `Live.shareCount` |
| `trafficSourceBreakdown` | `{ "FOR_YOU": 12, "SHARES": 3, … }` |
| `shop.orders` / `shop.revenueCoins` | Product orders with this `liveId` |

Existing peak / likes / comments / coins / top gifters stay.

---

## App checklist

1. After go-live, record locally (or later Egress) and `POST /lives/:id/replay` when you have a URL.
2. Show a **Report** sheet → `POST /lives/:id/report`.
3. Shop HUD: list bag → flash timer / coupon field → checkout with `liveId`.
4. Fan club paywall: show three tiers, debit coins, render emotes by `minTier`.
5. On join, send `trafficSource` from the screen you came from.
6. Host end screen: bind the new summary fields (watch time, new fans, traffic, shop).

Apply DB:

```bash
npx prisma generate
npx prisma migrate deploy
```
