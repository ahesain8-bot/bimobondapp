# Lives — Logic & Architecture

> TikTok-style LIVE: self-hosted **LiveKit** (A/V) + Socket.IO (chat / gifts / HUD) + Nest + Postgres (authority & money).

Mobile API: [mobile-api.md](./mobile-api.md) · Endpoints Ref: [endpoints.md](./endpoints.md) · Tasks: [tasks.md](./tasks.md) · Database: [database.md](./database.md) · Admin: [admin-api.md](./admin-api.md) · Production & testing: [production.md](./production.md)

---

## Feature matrix

| TikTok-style feature | DCC |
|----------------------|-----|
| Solo host go-live | Yes |
| Viewer watch + comments + likes | Yes (TikTok-style heart taps; rate-limited) |
| Gifts / coins to host | Yes (`GiftTransaction.liveId`) + rapid socket `sendGift` (`fastAck`) + `liveGiftCombo` / `gift_combo` |
| Live shopping / auctions | Yes — `POST /lives/:id/auctions`, gifts, `liveAuction`; end/ban cancels open auctions |
| Multi-guest (up to 8 on stage) | Yes (`LiveGuest`) |
| Guest request + host/mod accept | Yes |
| Host/mod invite | Yes |
| Force mute / unmute | Yes (DB + LiveKit permissions) |
| Force camera off / on | Yes |
| Kick guest | Yes (host/mod + admin) |
| Co-host promote/demote | Yes (host only) |
| Guest request mode (everyone / followers / off) | Yes |
| Layout GRID / PANEL | Stored; client applies |
| Live moderators manage guests | Yes (`LiveModerator`) |
| PK / Battle between two lives | Yes (`LiveBattle` + gift scoring) |
| PK Battle Speed Multiplier | Yes — 1.5x–5.0x score multiplier boost window (`POST /lives/:id/battle/multiplier`) |
| PK Auto Matching | Yes — `POST /lives/:id/battle/match` |
| Gift Goals (أهداف الهدايا) | Yes — `POST /lives/:id/gift-goal` + real-time progress HUD |
| Interactive Polls (استطلاعات الرأي) | Yes — `POST /lives/:id/polls`, vote, percentage calculations |
| Live Q&A Box (صندوق الأسئلة والأجوبة) | Yes — `POST /lives/:id/qa`, pin, answer tracking |
| Treasure Boxes / Coin Drops (صناديق الكنز) | Yes — `POST /lives/:id/treasure-boxes`, countdowns, coin claim from wallet |
| Chat Rules & Throttling | Yes — `chatMode` (`EVERYONE`, `FOLLOWERS`, `SUBSCRIBERS`), slow mode, blocked keywords |
| Post-Live Summary (تقرير نهاية البث) | Yes — `GET /lives/:id/summary` (viewers, session count, duration, coins, top gifters) |
| Hourly ranking leaderboard (ترتيب كل ساعة) | Yes — `GET /lives/leaderboard/hourly` |
| Gallery tab during live (المعرض) | Yes — `GET /lives/:id/gallery`, pin/reorder |
| Fan club for hosts | Yes — `Subscription` + `/creators/:id/fan-club` |
| Host league rank (e.g. B2) | Yes — `hostLeagueTier` on `User` |
| POPULAR badge on live | Yes — `isPopular` on feed/detail/join |
| Host heart count on profile | Yes — `user.hostHeartCount` (= `totalLikes`) |
| LiveKit Cloud / Agora fees | No — self-hosted LiveKit only |

---

## Architecture

```
Host + Guests --publish--> LiveKit SFU (WebRTC)
Viewers --------subscribe--> LiveKit SFU (WebRTC)
All -----------Socket.IO--> live_{id}  (chat, gifts, HUD, battles, polls, Q&A, treasure boxes)
Money / seats ------------- Nest + Postgres (source of truth)
```

Nest mints short-lived LiveKit JWTs. Clients never hold API secrets.

```
LIVEKIT_URL=ws://localhost:7880
LIVEKIT_API_KEY=…
LIVEKIT_API_SECRET=…
```

`docker compose up livekit` — config in `deploy/livekit.yaml`. Cost = your VPS bandwidth.

---

## Status machines

### Live

```
PLANNED → LIVE → ENDED
              ↘ BANNED
```

| Transition | Who | Side effects |
|------------|-----|--------------|
| create | user | `roomName = live_{uuid}`, `PLANNED` |
| start | host | `LIVE`, `startedAt`, notify followers `LIVE_STARTED`, return host token |
| end | host / admin | finish ACTIVE battles → cancel ACTIVE auctions → delete LiveKit room → close viewer sessions → guests → `LEFT` → clear restrictions → `ENDED` → `liveEnded` |
| ban | admin | same teardown → store `banReason` → `BANNED` → `liveEnded` (+ reason) |

Rules:

- One concurrent `LIVE` per host (`ensureNoActiveLive`).
- Public read hides `BANNED` as 404.
- Update metadata only when not `ENDED` / `BANNED`.

### Guest seats

```
REQUESTED ──accept──► ACTIVE ──leave/kick/end──► LEFT | KICKED
INVITED ──accept──► ACTIVE
REQUESTED / INVITED ──reject──► REJECTED
```

Roles: `GUEST` | `CO_HOST` (same publish model; promote is host-only).

Cap: `maxGuests` (default **8**). Host does not consume a seat.

### Battle (PK)

```
ACTIVE → FINISHED (timer job, host end, gift/lazy poll, or live end/ban)
```

Winner = higher gift score; tie → no `winnerLiveId`.

A background sweep (`BATTLE_EXPIRE_JOB_INTERVAL_MS`) finishes battles past `endTime` even with no traffic. Live end/ban calls `finishActiveForLive`.

### Treasure Boxes

```
WAITING (countdown) ──unlocksAt──► OPEN (claimable) ──fully claimed / expired──► EXPIRED
```

- Creator wallet balance is deducted at creation.
- Viewers claim randomized coin portions directly into their wallet.

### Polls

```
ACTIVE ──endPoll / new poll / live end──► ENDED
```

Only one active poll per live stream at a time.

---

## LiveKit tokens

| Nest role | `canPublish` | Notes |
|-----------|--------------|-------|
| `host` | yes | camera + mic |
| `guest` / `co_host` | yes unless muted / camera-off / `allowGuestCamera: false` | |
| `viewer` | no | subscribe only |

Mute/camera-off updates LiveKit participant permissions via Room Service and emits `liveGuestUpdate`. Join re-reads DB flags when minting tokens.

Token TTL: `6h` (`LIVE_TOKEN_TTL`). Guests refresh with `POST /lives/:id/guests/token`.

On end/ban/kick: Nest deletes the room or removes the participant so stale JWTs cannot stay published.

---

## Live shopping

1. Host must be seller-verified; live must be `LIVE` and owned by host.
2. `createForLive` → `Auction` with `liveId`; emit `liveAuction` `{ action: "created" }`.
3. Gifts with `liveId` / `auctionId` use the same escrow / contribution path as post auctions.
4. Progress: `liveAuction` on live room + `auctionUpdated` on auction room.
5. `finalizeEnd` / `adminBan` call `cancelActiveForLive` → host cancel per auction (escrow refund when enabled) → `{ action: "cancelled" }`.

Gifts also increment `Live.totalEarnedCoins` and may call `LivesBattlesService.addGiftScore`.

---

## Battles & Speed Challenges

- Host of live A starts against live B (`opponentLiveId`); both must be `LIVE` and not already in an ACTIVE battle.
- Host can also use `POST /lives/:id/battle/match` for instant auto-matching based on viewer count and category.
- Default duration 300s (30–1800).
- Speed Multipliers: Host triggers 1.5x–5.0x multiplier window (`POST /lives/:id/battle/multiplier`). Gifts during this window receive multiplied battle points.
- Each gift’s contribution coins add to that live’s score (rounded, min 1).
- `getActive` auto-finishes if `endTime` passed; interval job also finishes due battles.
- Live end/ban finishes any ACTIVE battle involving that live.
- Emits `liveBattle` to **both** live rooms; emits `liveBattlePhase` for multiplier activation and victory lap.

---

## Moderation (host / live moderator)

- `DELETE /lives/:id/comments/:commentId` — remove a comment; emits `liveCommentDeleted`.
- `POST /lives/:id/comments/:commentId/pin` | `unpin` — pin/unpin a comment in chat.
- `POST /lives/:id/viewers/:userId/mute-chat` | `unmute-chat` — chat mute (watch still allowed).
- `POST /lives/:id/viewers/:userId/ban` | `unban` — ban from this live (force leave + block rejoin/comment/like); emits `liveModeration`.
- `PATCH /lives/:id/chat-rules` — configure `chatMode` (`EVERYONE`, `FOLLOWERS`, `SUBSCRIBERS`), slow mode seconds, and custom blocked keywords.
- Restrictions live in `LiveViewerRestriction` and are cleared when the live ends/bans.

---

## Interactive Engagement Tools

1. **Gift Goals (`SetGiftGoalDto`)**: Host configures a coin target and optional title. Real-time updates emitted via `liveGiftGoalUpdate`.
2. **Interactive Polls (`CreateLivePollDto`, `VoteLivePollDto`)**: Host creates 2–5 option polls. Live voting updates percentage distributions via `livePollUpdated`.
3. **Q&A Box (`CreateLiveQADto`)**: Viewers submit questions. Host can pin questions to the screen (`pinQA`) and mark them answered (`markAnswered`). Emits `liveQAUpdated`.
4. **Treasure Boxes (`CreateTreasureBoxDto`)**: Host or viewers drop coin boxes with delay timers (`delaySeconds`). After countdown, viewers claim coins via `claimTreasureBox`. Emits `liveTreasureBoxSpawned` and `liveTreasureBoxClaimed`.
5. **Post-Live Analytics Summary (`getPostLiveSummary`)**: Host views comprehensive session statistics on stream completion (duration, viewer count, total sessions, comments, likes, earned coins, and top 5 gifters).

---

## Privacy & notifications

- Blocks and private accounts gate watch / join / guest request (same privacy helpers as posts).
- Staff roles may bypass private-content checks on detail/join where implemented.
- `LIVE_STARTED` → followers (capped batch).
- `LIVE_GUEST_INVITE` → invitee (+ socket `liveGuestInvite` on `user_{id}`).

---

## Viewer counting

- Non-host `join` upserts `LiveViewerSession` and increments when newly present.
- `leave` / end / ban / socket disconnect close open sessions; count refreshed from open sessions.
- `leave` also demotes ACTIVE stage guests (`leaveStage`).
- Socket `joinLive` requires `{ liveId, userId }` and checks ban/block; tracks lives on the socket for disconnect cleanup.
- Socket `liveViewers` after join/leave.

---

## Permissions (admin)

| Key | Use |
|-----|-----|
| `lives.admin.read` | `GET /lives/admin/all` |
| `lives.admin.moderate` | end, ban, feed boost, admin kick guest |

Host/mod guest management is **not** RBAC — it uses live ownership + `LiveModerator` + `moderatorsCanManageGuests`.

---

## Module map

| Piece | Responsibility |
|-------|----------------|
| `LivesService` | lifecycle, feed, join/leave, likes, comments, post-live summary, admin list/end/ban/boost, teardown |
| `LivesGuestsService` | settings, seats, mute/camera, mods, tokens |
| `LivesBattlesService` | PK start/end/score, auto-match, speed multipliers, victory lap |
| `LivesInteractiveService` | gift goals, chat rules, polls, Q&A box, treasure boxes |
| `LivesExtrasService` | hourly ranking, host leagues, fan clubs, popular badges, top gifters |
| `LiveKitService` | JWT mint, room delete, media permissions |
| `AuctionsService` | `createForLive`, list, gallery pin/reorder, `cancelActiveForLive` |
| `GiftsService` | live gifts, earned coins, battle score hook, rapid socket `sendGift` |
| `EventsGateway` | `joinLive` / emits |

Circular Nest deps with auctions and gifts use `forwardRef`.

---

## Feed ranking (summary)

Live feed scores open streams using viewers, likes, following, freshness, **category interests** (`UserInterest`), log-scaled earnings, same country, and optional admin **`feedBoostUntil`**. Candidate pool capped at 200, then score-then-paginate. Optional `followingOnly` prefers followed hosts.

---

## LiveKit webhooks

`POST /lives/webhooks/livekit` (signed with LiveKit API key/secret):

| Event | Action |
|-------|--------|
| Host `participant_left` / `participant_connection_aborted` | End the live (`endFromWebhook`) |
| Viewer `participant_left` / aborted | `leaveOnDisconnect` for that identity |
| `room_finished` | If still `LIVE`, end the stream |

Configure `webhook.urls` in [`deploy/livekit.yaml`](../../deploy/livekit.yaml). Socket disconnect remains a fallback for viewer presence. End/ban uses an atomic `LIVE` → `ENDED` claim so concurrent host end + webhook is safe.

See [production.md](./production.md) for deploy, firewall, and smoke tests.

---

## Invariants (keep these true)

1. End and ban both finish battles, cancel auctions, **and** clear guests/sessions/restrictions/LiveKit room.
2. Guest static routes (`leave`, `token`, `accept-invite`, `request`, `invite`) are registered **before** `:userId/...` routes.
3. Only host promotes/demotes co-host **and** only host may invite as `CO_HOST`; mods can manage guests when allowed but not promote/invite as co-host.
4. Gifts to a non-`LIVE` stream are rejected (`assertLiveActiveForGift`).
5. Build/migrations: apply Prisma migrations that add Live / LiveGuest / LiveBattle / LivePoll / LiveQA / LiveTreasureBox / viewer sessions / restrictions before deploying.

---

## Related

- [mobile-api.md](./mobile-api.md) · [admin-api.md](./admin-api.md) · [production.md](./production.md)
- [../events/logic.md](../events/logic.md) · [../gifts/logic.md](../gifts/logic.md) · [../auctions/logic.md](../auctions/logic.md)
- [../rbac/logic.md](../rbac/logic.md) · [../app/database.md](../app/database.md)
