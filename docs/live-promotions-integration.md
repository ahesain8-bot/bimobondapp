# LIVE promotions integration contract

The supplied [LIVE promotions API notes](../lives/live-promotions.md) define
request paths and bodies but no response envelopes. The mobile client keeps an
explicit `LivePromotionResponseContract` seam so LIVE campaigns are never read
through post-promotion defaults, and now ships `LiveApiPromotionContract`, an
adapter written against captured responses from the deployed service.
`UnverifiedLivePromotionContract` remains available and still fails closed.

`test/live_promotion_api_contract_test.dart` holds the captured envelopes.
When the API changes, update those fixtures — not the parser — first.

Parsing is permissive for display and strict for money. A missing or renamed
economic field leaves `LivePromotionCampaign.hasPaymentSummary` false, which
disables Pay rather than guessing a price; `create` still refuses any campaign
whose `id`, `liveId` or `PENDING_PAYMENT` status does not match the request;
an unrecognised status stays `UNKNOWN` and read-only; and the wallet balance
is always server-supplied, never computed locally.

## Required transport

All promotion endpoints require `Authorization: Bearer <Firebase ID token>`.
The client expects ordinary 2xx HTTP success responses. For payment, a
timeout, network error, or 5xx leaves a locally persisted uncertainty marker;
the app reloads campaign and wallet state and never repeats the POST on its
own. A conclusive 4xx clears that marker.

`PROMOTIONS_ENABLED` is a compile-time client gate (`--dart-define`), default
`true` as requested by the API notes. If the backend owns a rollout flag, add
its endpoint and documented response to this contract.

## Verified envelopes

`GET /promotions/lives/options` returns `objectives`, `audienceModes`,
`genders`, `ageRange`, `languages`, `categories` (`{id,name,slug,iconUrl}`),
`customBudget` (`durationPresetsDays`, `coinsPer1000Impressions`,
`estimateVariance`, …) and `targetingNotes`. It carries **no country list**,
so the client reads country chips from the shared `GET /promotions/options`
envelope; that second request is best-effort and its failure only removes
country targeting.

`GET /promotions/packages` returns a flat array of `{id, name, durationHours,
priceCoins, impressionCount, isActive, isDeleted}`. The catalog is priced in
hours and the LIVE form quotes days, so `durationHours` is converted.
Inactive and deleted rows are dropped.

`GET /promotions/lives/mine` returns `{data, meta:{total,page,limit,
totalPages}}`; `hasMore` is `page < totalPages`.

## Fixtures still wanted

Campaign, stats and preview envelopes are parsed from the same service's post
promotion shape. Please confirm them, with one success and one relevant
failure fixture for each endpoint:

| Endpoint | Fields the client must verify |
| --- | --- |
| `GET /promotions/lives/custom/preview` | estimated viewers, followers, and/or impressions, including which values may be omitted |
| `POST /promotions/lives`, `GET /promotions/lives/:id`, and `GET /promotions/lives/by-live/:liveId` | campaign `id`, `liveId`, exact status enum, paid budget, duration, objective, audience mode, and all persisted targeting fields |
| `GET /promotions/lives/:id/stats` and `.../by-live/:liveId/stats` | impressions, coins spent, and remaining prepaid coins, with units and numeric types |
| `POST /promotions/lives/:id/pay` | authoritative post-payment campaign status and wallet/reconciliation meaning; errors that identify insufficient coins versus retryable faults |
| `PATCH /promotions/lives/:id`, `.../pause`, `.../resume`, `.../cancel` | authoritative returned status, conflict behavior, cancellation/refund fields, and permission failures |

For the campaign envelope specifically, state whether a campaign created from a
`packageId` also returns `durationDays`. A create request may carry only one of
the two, so the client keeps a separate non-validating representation for stored
campaign data; confirm that this is the real shape rather than an assumption.

The parser accepts only exact enum values, and an unknown status remains
read-only. Extend `LiveApiPromotionContract` against a captured fixture; do
not widen it to treat arbitrary JSON as a campaign.

## Additional LIVE schema needed for creator eligibility

Checked against the canonical **Live object reference** in
`lives/mobile-api.md` (§5, "Returned by create / update / end / feed /
detail") and the examples in `lives/endpoints.md`:

- `userId` **is** present at the top level of the live object and carries the
  host's internal user id — the same uuid the nested `user.id` repeats. The
  client's `live['userId']` read is therefore correct; `user.id` is a duplicate,
  not an alternative, and neither is a Firebase UID.
- `user.isPrivate` **is** present, describing the host account.
- `visibility` is **absent** from that reference and from every other lives
  document in this repository, and no lives document describes a per-stream
  visibility concept at all.

The client verifies authenticated user id, host user id, live status
(`PLANNED` or `LIVE`), account privacy and account ban state. Because
`visibility` does not exist on the live object and no lives document defines a
per-stream visibility concept, its **absence** no longer blocks promotion:
what makes a stream non-public in this system is a private account, which is
checked directly. If `GET /lives/:id` ever returns a `visibility` field, the
client reads it and refuses any value other than `PUBLIC`. The server stays
authoritative and is expected to reject an ineligible host regardless.

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

## Open conflict: coordinates on the LIVE feed

`lives/live-promotions.md` says to pass optional `latitude` / `longitude` on
`GET /lives/feed` so custom-audience geo targeting can match. The deployed API
rejects them: the request returns HTTP 400 with
`["property latitude should not exist", "property longitude should not exist"]`,
which empties the Discover screen for any account that has granted location.

The client therefore sends only the documented feed query
(`page`, `limit`, `categoryId`, `followingOnly`), and
`test/live_promotion_attribution_test.dart` asserts that no coordinates are
sent. Backend must decide which side is authoritative before any geo-targeted
delivery can be relied on: either the feed DTO accepts the two properties, or
the promotions document should drop them. The client will not add coordinates,
a location permission, or a geo fallback on assumption.
