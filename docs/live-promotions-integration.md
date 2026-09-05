# LIVE promotions integration contract

The supplied [LIVE promotions API notes](../lives/live-promotions.md) define
request paths and bodies, but they do not define response envelopes or the
LIVE visibility field. The mobile client therefore uses an explicit
`LivePromotionResponseContract` seam and ships with an unverified adapter.
Reads fail closed and every promotion mutation, including payment, is blocked
before a request is sent until the backend team provides fixtures or OpenAPI.

This is deliberate: post-promotion response formats, local wallet arithmetic,
and guessed status fields must never be reused for paid LIVE campaigns.

## Required transport

All promotion endpoints require `Authorization: Bearer <Firebase ID token>`.
The client expects ordinary 2xx HTTP success responses. For payment, a
timeout, network error, or 5xx leaves a locally persisted uncertainty marker;
the app reloads campaign and wallet state and never repeats the POST on its
own. A conclusive 4xx clears that marker.

`PROMOTIONS_ENABLED` is a compile-time client gate (`--dart-define`), default
`true` as requested by the API notes. If the backend owns a rollout flag, add
its endpoint and documented response to this contract.

## Required response fixtures

Please provide one success and one relevant failure fixture for each endpoint:

| Endpoint | Fields the client must verify |
| --- | --- |
| `GET /promotions/lives/options` | target gender, language, category and country `{ value, label }` lists; valid custom durations; the impression rate |
| `GET /promotions/packages` | package `id`, display name, coin cost, included duration, and any estimated impressions |
| `GET /promotions/lives/custom/preview` | estimated viewers, followers, and/or impressions, including which values may be omitted |
| `POST /promotions/lives`, `GET /promotions/lives/:id`, and `GET /promotions/lives/by-live/:liveId` | campaign `id`, `liveId`, exact status enum, paid budget, duration, objective, audience mode, and all persisted targeting fields |
| `GET /promotions/lives/mine` | campaign item envelope plus pagination cursor or `hasMore` semantics |
| `GET /promotions/lives/:id/stats` and `.../by-live/:liveId/stats` | impressions, coins spent, and remaining prepaid coins, with units and numeric types |
| `POST /promotions/lives/:id/pay` | authoritative post-payment campaign status and wallet/reconciliation meaning; errors that identify insufficient coins versus retryable faults |
| `PATCH /promotions/lives/:id`, `.../pause`, `.../resume`, `.../cancel` | authoritative returned status, conflict behavior, cancellation/refund fields, and permission failures |

The parser must accept only the reviewed envelope and exact enum values. An
unknown status remains read-only. Once fixtures arrive, replace
`UnverifiedLivePromotionContract` with the reviewed parser and enable the
repository through that adapter; do not enable requests by treating arbitrary
JSON as a campaign.

## Additional LIVE schema needed for creator eligibility

`GET /lives/:id` must expose a canonical `visibility` field with a documented
`PUBLIC` value. The client already verifies authenticated user id, host user
id, live status (`PLANNED` or `LIVE`), account privacy, and account ban state.
It intentionally refuses to create a campaign while visibility is absent or
unknown; it must never infer public visibility from another field.

The endpoint should also document whether the request is allowed for a
non-host, and return a stable authorization error for private, banned, ended,
or missing lives.

## Delivery and billing boundary

The app preserves `isPromoted` and `promotion.id` from `GET /lives/feed` and
only adds `campaignId` to `POST /lives/:id/join` when the selected card is a
verified promoted entry for a different viewer than its host. It does not
inject cards, count impressions, enforce daily limits, debit coins, decide
refunds, or retry billing. Those operations remain server responsibilities.

For a promoted feed card, confirm the exact optional shape and whether the
campaign id is safe to expose:

```json
{
  "isPromoted": true,
  "promotion": { "id": "campaign-uuid", "label": "Promoted" }
}
```

Organic cards and host opens omit `campaignId`. A billing failure must not make
the join itself fail.
