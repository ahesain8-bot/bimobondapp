# Lives Module — Performance Issues & Optimization Roadmap

> **Scope:** Backend NestJS / Prisma / PostgreSQL  
> **Files involved:** `src/lives/lives.service.ts` · `src/lives/lives-extras.service.ts` · `src/lives/lives-battles.service.ts`  
> **Status:** Identified, not yet fixed  
> **Last updated:** 2026-08-16

---

## Table of Contents

- [Priority Summary](#priority-summary)
- [🔴 Critical Issues](#-critical-issues)
  - [1. Double DB Hit on Every Viewer Join](#1-double-db-hit-on-every-viewer-join)
  - [2. Full Rank Scan on Every Gift](#2-full-rank-scan-on-every-gift)
  - [3. Full Rank Scan on Every Viewer Join/Leave](#3-full-rank-scan-on-every-viewer-joinleave)
  - [4. Feed Scored In-Memory from a Large Candidate Pool](#4-feed-scored-in-memory-from-a-large-candidate-pool)
  - [5. Follower Notifications Block Live Start](#5-follower-notifications-block-live-start)
- [🟡 Medium Issues](#-medium-issues)
  - [6. In-Memory likeAttempts Map Grows Forever](#6-in-memory-likeattempts-map-grows-forever)
  - [7. O(n²) Lookup in Hourly Leaderboard](#7-on-lookup-in-hourly-leaderboard)
  - [8. Sequential DB Queries Inside join()](#8-sequential-db-queries-inside-join)
  - [9. No Caching on Moderator Permission Checks](#9-no-caching-on-moderator-permission-checks)
- [🟢 Infrastructure / Database](#-infrastructure--database)
  - [10. Missing Database Indexes](#10-missing-database-indexes)
  - [11. No Redis Caching Layer](#11-no-redis-caching-layer)
  - [12. Battle Expire Sweep is Sequential](#12-battle-expire-sweep-is-sequential)
- [Fix Execution Order](#fix-execution-order)

---

## Priority Summary

| # | Severity | Issue | Primary File | Est. Impact |
|---|---|---|---|---|
| 1 | 🔴 Critical | Double DB hit inside `join()` | `lives.service.ts:L333` | Halves join latency |
| 2 | 🔴 Critical | Full rank scan on every gift | `lives-extras.service.ts:L466` | −90% DB load per gift |
| 3 | 🔴 Critical | Full rank scan on every viewer join/leave | `lives-extras.service.ts:L483` | −80% read load |
| 4 | 🔴 Critical | Feed scored in-memory from huge pool | `lives.service.ts:L827` | −70% DB reads |
| 5 | 🔴 Critical | Follower notifications block live start | `lives.service.ts:L1366` | Unblocks start response |
| 6 | 🟡 Medium | `likeAttempts` Map grows forever (memory leak) | `lives.service.ts:L47` | Prevents OOM |
| 7 | 🟡 Medium | O(n²) lookup in leaderboard | `lives-extras.service.ts:L264` | Minor CPU |
| 8 | 🟡 Medium | Sequential DB queries in `join()` | `lives.service.ts:L259` | −30% join time |
| 9 | 🟡 Medium | No caching on moderator checks | `lives.service.ts:L1471` | −2 DB reads per action |
| 10 | 🟢 Infra | Missing DB indexes | `schema.prisma` | −30–50% query time |
| 11 | 🟢 Infra | No Redis caching at all | — | −70% DB reads overall |
| 12 | 🟢 Infra | Sequential battle expire sweep | `lives-battles.service.ts:L425` | Minor |

---

## 🔴 Critical Issues

---

### 1. Double DB Hit on Every Viewer Join

**File:** `src/lives/lives.service.ts` — `join()` method (L333)

#### What happens

When a viewer joins a stream, `join()` fetches the live row, validates permissions, checks ban status, upserts presence, and refreshes the viewer count. Then, at the very end, it calls `this.findOne()` again which:

- Re-fetches the full live row from Postgres
- Checks privacy rules again (extra queries)
- Fetches all **active auctions** for the live
- Fetches the **pinned comment**

This means every single viewer join triggers **9–11 DB queries** in sequence, and the last batch is completely redundant — the live data was already fetched at the top of `join()`.

```
join() call flow (current):
  1. prisma.live.findUnique()              ← live data
  2. assertNotBannedFromLive()             ← restriction check
  3. privacy.assertNotBlocked()            ← block check
  4. privacy.assertCanViewPrivateContent() ← follow check
  5. prisma.user.findUnique()              ← viewer profile
  6. prisma.liveGuest.findUnique()         ← guest stage check
  7. liveViewerSession.upsert()            ← presence insert
  8. refreshViewerCount()                  ← count + update
  ── then calls findOne() which runs: ─────────────────────
  9. prisma.live.findUnique()              ← DUPLICATE of step 1
  10. auctions.listActiveByLive()          ← unnecessary at join time
  11. getPinnedComment()                   ← unnecessary at join time
  12. extras.enrichOneLive()               ← full hourly rank scan
```

#### How to fix

- Remove the `this.findOne()` call at the bottom of `join()`
- Shape and return the live data already available from step 1
- Let the mobile/web client call `GET /lives/:id` separately once connected — the viewer doesn't need auction and pinned comment data to establish the WebSocket stream

---

### 2. Full Rank Scan on Every Gift

**File:** `src/lives/lives-extras.service.ts` — `onLiveGiftReceived()` (L466)

#### What happens

Every time any viewer sends any gift to any live, `onLiveGiftReceived()` is called synchronously and does:

1. Fetches **all currently LIVE streams** from Postgres (up to hundreds of rows)
2. Runs a `giftTransaction.groupBy()` aggregate for **all of those live IDs** since the start of the current hour
3. Sorts and ranks all lives in Node.js memory
4. Emits `live:hourly_rank_updated` and `live:popular_status` WebSocket events

In a scenario with 100 concurrent lives and moderate gift activity (say 5 gifts/second across all lives), this query runs **300 times per minute**, each time pulling hundreds of rows and running a large aggregate. This will saturate the DB connection pool and cause cascading latency.

#### How to fix

**Step 1 — Debounce per live:**
Add a per-`liveId` debounce map. Only allow one rank recompute per live per 10 seconds. Subsequent calls within that window are dropped.

**Step 2 — Move rank computation to a background job:**
Use BullMQ (or a simple `setInterval`) to recompute ranks for all active lives every 30–60 seconds in a single batched query. Store results in Redis.

**Step 3 — Cache rank results:**
Store each live's computed rank in Redis with key `live:rank:{liveId}` and TTL of 60 seconds. On a gift event, only update the individual live's coin total and emit a gift animation event — skip the rank recompute.

**Step 4 — Emit rank from background job:**
The background job broadcasts rank updates after each cycle, not on each gift.

---

### 3. Full Rank Scan on Every Viewer Join/Leave

**File:** `src/lives/lives-extras.service.ts` — `onViewersChanged()` (L483)  
**Triggered from:** `lives.service.ts` — `refreshViewerCount()` (L1362)

#### What happens

Every join and leave event calls `refreshViewerCount()` which calls `this.extras.onViewersChanged(liveId)`. That method calls `getLiveHourlyRank()` which — identical to issue #2 — fetches all live streams and recomputes all ranks.

In a stream with 1,000 viewers all joining in the first minute, this triggers 1,000 full rank scans.

#### How to fix

- Remove `void this.extras.onViewersChanged(liveId)` from `refreshViewerCount()`
- Only emit `emitLiveViewers` (the raw viewer count) immediately — it's cheap and already computed
- Rely on the background rank job (see fix #2) to pick up the viewer change in the next cycle

---

### 4. Feed Scored In-Memory from a Large Candidate Pool

**File:** `src/lives/lives.service.ts` — `feed()` method (L827)

#### What happens

The discovery feed query:
1. Fetches up to `LIVE_FEED_CANDIDATE_CAP` live rows from Postgres with full user/category joins
2. Loads all of them into Node.js memory
3. Scores each one using viewer count, likes, following status, category interest, country match, and age freshness — all computed in JavaScript
4. Sorts in memory
5. Paginates with `slice()`

Additionally, for every authenticated feed request, **4 parallel queries** run upfront to fetch the viewer's blocks, follows, interests, and country — even for users with no blocks or follows.

If `LIVE_FEED_CANDIDATE_CAP` is 200–500, this means pulling 200–500 full rows on every swipe of the discovery feed.

#### How to fix

**Step 1 — Check the cap value:**
Open `lives.constants.ts` and verify `LIVE_FEED_CANDIDATE_CAP`. If it exceeds 100, reduce it.

**Step 2 — Cache the feed:**
Cache the scored feed result (keyed by `categoryId + followingOnly`) in Redis for 5–10 seconds. At most 200 viewers per second see a cached result — only one DB hit per 5 seconds per unique query.

**Step 3 — Pre-compute scores in Redis:**
The background rank job can maintain a Redis sorted set `live:feed` where each member is a `liveId` and the score is the feed ranking score. Feed queries then become a Redis `ZRANGE` call + a small DB fetch for user-specific overrides (following, blocks).

**Step 4 — Skip expensive viewer-specific queries when possible:**
For unauthenticated requests or first-time users, skip the blocks/follows/interests queries entirely and return a pre-cached default feed.

---

### 5. Follower Notifications Block Live Start

**File:** `src/lives/lives.service.ts` — `notifyFollowersLiveStarted()` (L1366)

#### What happens

When a host starts a live, `notifyFollowersLiveStarted()` is called with `void` (fire-and-forget), but the function itself:

1. Queries `follow` table for up to **5,000 follower IDs**
2. Passes all 5,000 IDs to `notifyMany()` which likely inserts 5,000 notification rows in a single call

This can take several seconds for popular hosts and will occupy a DB connection for the duration. Under load, this blocks other queries from running.

#### How to fix

**Step 1 — Push to BullMQ job queue:**
Instead of calling `notifyFollowersLiveStarted()` directly, push a job:
```ts
await this.notificationQueue.add('live-started', { liveId, hostId });
```

**Step 2 — Process in the worker in batches:**
The worker fetches followers in pages of 200, inserts notifications in batches, and sleeps briefly between batches.

**Step 3 — Add index on `follow.followingId`:**
The follower lookup `WHERE followingId = ?` must be indexed. Confirm in `schema.prisma`.

---

## 🟡 Medium Issues

---

### 6. In-Memory `likeAttempts` Map Grows Forever

**File:** `src/lives/lives.service.ts` — `likeAttempts` Map (L47)

#### What happens

```ts
private readonly likeAttempts = new Map<string, number[]>();
```

This Map stores like attempt timestamps keyed by `liveId:userId`. When a viewer likes a live, their timestamp is added to the array. Old entries (from ended lives, inactive users) are **never removed**. Over time, this Map grows indefinitely — in a production server running for days with thousands of streams, this becomes a meaningful memory leak.

Additionally, this state is **local to one Node.js process**. If you run multiple NestJS instances (horizontal scaling), rate limiting breaks because each instance has its own Map.

#### How to fix

- Replace the in-memory Map with Redis:
  ```
  key: live:likes:{liveId}:{userId}
  type: sorted set or simple incr with TTL
  TTL: same as LIVE_LIKE_RATE_LIMIT.windowMs
  ```
- This also works correctly across multiple server instances

---

### 7. O(n²) Lookup in Hourly Leaderboard

**File:** `src/lives/lives-extras.service.ts` — `getHourlyLeaderboard()` (L264)

#### What happens

After ranking, the code does:
```ts
const live = lives.find((l) => l.id === row.liveId)!;
```
inside a `.map()` call over the ranked results. This is an **O(n²)** loop — for each ranked item, it scans the entire `lives` array. With 200 live streams, that's 200×200 = 40,000 comparisons per leaderboard request.

#### How to fix

Convert the array to a Map before the loop:
```ts
const liveById = new Map(lives.map((l) => [l.id, l]));
// then:
const live = liveById.get(row.liveId)!;
```

This reduces the lookup to O(1) and the total loop to O(n).

---

### 8. Sequential DB Queries Inside `join()`

**File:** `src/lives/lives.service.ts` — `join()` method (L259)

#### What happens

Inside `join()`, after the initial live fetch, three independent checks are run sequentially (each awaited one after another):

```ts
await this.assertNotBannedFromLive(liveId, userId);   // DB query
await this.privacy.assertNotBlocked(userId, ...);      // DB query
await this.privacy.assertCanViewPrivateContent(...);   // DB query
```

None of these depend on each other's result, yet they run one at a time. Then separately:

```ts
const viewer = await this.prisma.user.findUnique(...); // DB query
const activeGuest = await this.prisma.liveGuest...;   // DB query
```

These are also independent but sequential.

#### How to fix

Wrap independent queries in `Promise.all()`:
```ts
const [restriction, blockedCheck, viewer, activeGuest] = await Promise.all([
  this.prisma.liveViewerRestriction.findUnique(...),
  this.privacy.checkBlock(userId, live.userId),
  this.prisma.user.findUnique(...),
  this.prisma.liveGuest.findUnique(...),
]);
```

This runs all 4 queries concurrently — saving 3× network round-trips to Postgres.

---

### 9. No Caching on Moderator Permission Checks

**File:** `src/lives/lives.service.ts` — `assertCanModerateLive()` (L1471)

#### What happens

Every moderation action (delete comment, pin comment, mute chat, ban viewer) calls `assertCanModerateLive()` which runs:

1. `prisma.live.findUnique()` — to verify the live exists and get the host ID
2. `prisma.liveModerator.findUnique()` — to check if the actor is a moderator

That's 2 DB queries per moderation action. In a busy stream with active moderators, this adds up.

#### How to fix

- Cache the set of moderator user IDs per `liveId` in Redis:
  ```
  key: live:mods:{liveId}
  type: Redis Set
  TTL: 60 seconds
  ```
- Warm the cache when a moderator is added; invalidate (delete key) when removed
- The `assertCanModerateLive` check becomes a Redis `SISMEMBER` call + a single live status DB read

---

## 🟢 Infrastructure / Database

---

### 10. Missing Database Indexes

The following query patterns are hit very frequently but likely lack proper indexes. Run `EXPLAIN ANALYZE` in Postgres on each to confirm.

| Table | Columns to Index | Query that uses it |
|---|---|---|
| `liveViewerSession` | `(liveId, leftAt)` | `refreshViewerCount` — counts open sessions |
| `liveComment` | `(liveId, isPinned, isDeleted)` | `getPinnedComment` |
| `liveComment` | `(liveId, isDeleted, createdAt DESC)` | `listComments` pagination |
| `liveViewerRestriction` | `(liveId, userId)` | `assertNotBannedFromLive`, `assertCanComment` |
| `giftTransaction` | `(liveId, createdAt)` | hourly coins `groupBy` in extras service |
| `liveBattle` | `(status, live1Id, live2Id)` | `activeBattleLiveIds`, `addGiftScore` |
| `follow` | `followingId` | `notifyFollowersLiveStarted` — fetches up to 5,000 rows |
| `subscription` | `(subscriberId, creatorId, status, endDate)` | fan club membership check in `enrichManyLives` |
| `liveModerator` | `(liveId, userId)` | `assertCanModerateLive` |

**How to add indexes in Prisma:**
```prisma
model LiveViewerSession {
  // ...existing fields...
  @@index([liveId, leftAt])
}

model LiveComment {
  // ...existing fields...
  @@index([liveId, isPinned, isDeleted])
  @@index([liveId, isDeleted, createdAt(sort: Desc)])
}
```

Then run:
```bash
npx prisma migrate dev --name add_lives_performance_indexes
```

---

### 11. No Redis Caching Layer

Currently **every** request to the Lives API hits Postgres directly. There is no in-memory cache. The following data is hot-read but changes slowly enough to be safely cached:

| Endpoint / Data | Cache Key | Recommended TTL |
|---|---|---|
| `GET /lives/:id` full response | `live:detail:{liveId}` | 3–5 seconds |
| `GET /lives/feed` (per filter) | `live:feed:{categoryId}:{followingOnly}` | 5–10 seconds |
| Hourly rank for a live | `live:rank:{liveId}` | 30–60 seconds |
| Pinned comment | `live:pinned:{liveId}` | 5 seconds (invalidate on pin/unpin) |
| Hourly leaderboard | `live:leaderboard` | 15–30 seconds |
| Fan club membership per viewer+host | `live:fanclub:{viewerId}:{hostId}` | 60 seconds |

**Implementation steps:**
1. Add `ioredis` (or NestJS `cache-manager` with Redis adapter) to the project
2. Create a `CacheService` wrapper in `src/cache/`
3. Wrap the above reads with cache-aside pattern: check cache → if miss, query DB → write to cache → return
4. Use `cache.del()` on mutation events (pin comment, live end, etc.)

---

### 12. Battle Expire Sweep is Sequential

**File:** `src/lives/lives-battles.service.ts` — `expireDueBattles()` (L418)

#### What happens

The background sweep that expires overdue battles processes them one-by-one:

```ts
for (const battle of due) {
  await this.finishBattle(battle); // waits for each before starting the next
}
```

If 10 battles expire simultaneously, they are finished one at a time. `finishBattle()` involves a DB `updateMany`, a `findUnique`, and 2 WebSocket emits — so with 10 battles this is ~40 sequential DB operations.

#### How to fix

Process all due battles in parallel:
```ts
await Promise.all(due.map((b) => this.finishBattle(b)));
```

This reduces 10×N operations back to N operations (concurrent), limited only by the DB connection pool.

Alternatively, migrate to BullMQ delayed jobs:
- When a battle is created, schedule a job with `delay: durationSeconds * 1000`
- The job fires exactly at `endTime` and calls `finishBattle()` — no sweep needed

---

## Fix Execution Order

Apply fixes in this order to get the most impact with the least risk:

```
Phase 1 — Quick wins (no infrastructure changes needed)
  [x] Fix #7  — O(n²) leaderboard lookup (one-line change)
  [x] Fix #8  — Parallelize join() queries with Promise.all
  [x] Fix #12 — Parallelize battle expire sweep with Promise.all
  [x] Fix #1  — Remove findOne() call from inside join()

Phase 2 — Debouncing & background jobs
  [x] Fix #3  — Debounced onViewersChanged() rank scan on viewer changes
  [x] Fix #2  — Debounce onLiveGiftReceived() rank recompute (5s per liveId)
  [x] Fix #5  — Batched notifyFollowersLiveStarted() in chunks of 200
  [x] Fix #6  — Auto-pruning for likeAttempts map in sweepStaleLives

Phase 3 — Database
  [x] Fix #10 — Add missing indexes to schema.prisma (LiveComment, LiveBattle, LiveViewerSession, Call)

Phase 4 — Redis / Advanced
  [x] Fix #11 — Redis integration via RedisService (Set ops, TTL cache, resilience fallback)
  [x] Fix #9  — Cache moderator IDs per live in Redis (`live:mods:{liveId}`)
  [x] Fix #4  — Discovery feed cached in Redis (`live:feed:public:{category}:{page}:{limit}`)
```

---

> **Related docs:** [endpoints.md](./endpoints.md) · [logic.md](./logic.md) · [tasks.md](./tasks.md) · [production.md](./production.md)
