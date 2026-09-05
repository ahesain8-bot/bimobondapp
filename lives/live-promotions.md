# Live promotions (TikTok LIVE promote)

> Creator-paid boost for **LIVE** streams. Same settings as TikTok LIVE promote: **goal**, **automatic / custom audience**, **budget**, **duration**.  
> Related: [lives mobile API](./mobile-api.md) · [post promotions](../promotions/mobile-api.md) · [promotions logic](../promotions/logic.md)

This is **not** the admin `POST /lives/admin/:id/boost` (`feedBoostUntil`) pin. Admin boost stays separate and free. Live promotions debit the creator’s coin wallet.

---

## TikTok settings → API

| TikTok LIVE promote | Field / value |
|---------------------|----------------|
| Goal: More viewers | `objective: "VIEWS"` |
| Goal: More followers | `objective: "FOLLOWERS"` |
| Audience: Automatic | `automaticAudience: true` (default) — we pick people likely to watch |
| Audience: Custom | `automaticAudience: false` + gender / age / geo / language / category |
| Budget: package | `packageId` (same catalog as post promotions) |
| Budget: custom | `budgetCoins` (min 5) + `durationDays` (`1` / `3` / `7` / `14`) |
| Pay | Full budget upfront (`POST /promotions/lives/:id/pay`) |
| Unused coins | Refunded on cancel **or** when the LIVE ends |

Gate the UI on `PROMOTIONS_ENABLED` (default on). Rate is `PROMOTION_COINS_PER_1000_IMPRESSIONS` (default **5**).

One open campaign per live (`PENDING_PAYMENT` / `ACTIVE` / `PAUSED`). Only the host of a **PLANNED** or **LIVE** public stream can create one. Private and banned accounts cannot promote.

---

## App flow

```
GET  /promotions/lives/options
GET  /promotions/lives/custom/preview?budgetCoins=20&durationDays=1&objective=VIEWS
POST /promotions/lives          → PENDING_PAYMENT
POST /promotions/lives/:id/pay  → debit coins, ACTIVE
     For You injects the live every 8 organic slots
POST /lives/:id/join  { "campaignId": "<promotion.id>" }  → bill one impression
     LIVE ends → campaign COMPLETED, unused coins refunded
```

### Create (automatic audience)

```json
{
  "liveId": "live-uuid",
  "budgetCoins": 20,
  "durationDays": 1,
  "objective": "VIEWS",
  "automaticAudience": true
}
```

### Create (custom audience)

```json
{
  "liveId": "live-uuid",
  "packageId": "package-uuid",
  "objective": "FOLLOWERS",
  "automaticAudience": false,
  "targetGenders": ["FEMALE"],
  "targetAgeMin": 18,
  "targetAgeMax": 34,
  "targetCountryCodes": ["EG"],
  "targetLanguages": ["ar"],
  "targetCategoryIds": ["category-uuid"],
  "targetLatitude": 30.0444,
  "targetLongitude": 31.2357,
  "targetRadiusKm": 50
}
```

Send **either** `packageId` **or** `budgetCoins`, not both. Geo fields must be all present or all omitted.

---

## Endpoints

All `/promotions/lives/*` routes require `Authorization: Bearer <Firebase ID token>`.

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/promotions/lives/options` | Goals, audience modes, duration chips, rate, categories |
| `GET` | `/promotions/lives/custom/preview` | Estimated viewers / followers for a custom budget |
| `POST` | `/promotions/lives` | Create campaign (`PENDING_PAYMENT`) |
| `GET` | `/promotions/lives/mine` | Host’s campaigns (`page`, `limit`) |
| `GET` | `/promotions/lives/by-live/:liveId` | Open or latest campaign for this live |
| `GET` | `/promotions/lives/by-live/:liveId/stats` | Progress for that campaign |
| `GET` | `/promotions/lives/:id` | Campaign detail |
| `GET` | `/promotions/lives/:id/stats` | Impressions, spend, remaining |
| `POST` | `/promotions/lives/:id/pay` | Debit coins → `ACTIVE` |
| `PATCH` | `/promotions/lives/:id` | Edit while `PENDING_PAYMENT` |
| `PATCH` | `/promotions/lives/:id/pause` | Pause delivery |
| `PATCH` | `/promotions/lives/:id/resume` | Resume |
| `PATCH` | `/promotions/lives/:id/cancel` | Cancel + refund unused |

Packages are shared with posts: `GET /promotions/packages`.

---

## For You delivery

Promoted lives are injected only on the **main** For You feed (`GET /lives/feed` without `followingOnly` or `categoryId`). One promoted card every **8** organic lives (same interval as post ads).

Pass optional `latitude` / `longitude` on the feed query so custom-audience geo targeting can match. Automatic audience ignores geo and demographic filters.

Feed item extras:

```json
{
  "isPromoted": true,
  "promotion": { "id": "campaign-uuid", "label": "Promoted" }
}
```

Show a **Promoted** label. When the viewer opens that card, send `promotion.id` as `campaignId` on join. Organic joins omit it — do not bill organic watches.

```http
POST /lives/:id/join
{ "campaignId": "campaign-uuid" }
```

Billing is once per join (daily cap **2** per viewer per campaign). Host joins never bill. Join still succeeds if billing fails.

A campaign only delivers while the live is `LIVE` and the campaign is `ACTIVE` with remaining budget / impressions.

---

## End of live

Host end, admin end/ban, webhook end, and the max-duration sweep all call the same cleanup:

- `PENDING_PAYMENT` → `CANCELLED` (nothing charged)
- `ACTIVE` / `PAUSED` → `COMPLETED` and unused prepaid coins refunded (`AD_PROMOTION_REFUND`)

---

## What not to mix up

| Feature | Who pays | What it does |
|---------|----------|--------------|
| Live promotions (this doc) | Host coins | Injects LIVE into For You |
| Post promotions | Host coins | Injects posts into home feed |
| Admin live boost | Staff, free | Temporary `feedBoostUntil` rank bump |
