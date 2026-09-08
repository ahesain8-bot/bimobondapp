# LIVE endpoints 2 — full catalog + why each exists

> **Audience:** Mobile and admin developers implementing LIVE.  
> **Base:** `/lives` unless another prefix is shown.  
> **Auth:** `Authorization: Bearer <Firebase ID token>` when Auth = required / host / staff.  
> **Older catalog (request samples):** [endpoints.md](./endpoints.md)  
> **How it works:** [mobile-api.md](./mobile-api.md) · [logic.md](./logic.md)  
> **New product files:** [P0](./live-p0-parity.md) · [P1](./live-p1-parity.md) · [P2](./live-p2-parity.md) · **[P3](./live-p3-parity.md)** · **[audio rooms](./live-audio-rooms.md)** · [promotions](./live-promotions.md) · [camera](./live-camera.md) · [post-live + user sort](../users/user%20sort%20an%20live%20info.md)

This file lists **every LIVE route in the current code**, including routes added in the new parity files. Each row answers: **what it is** and **why the app needs it**.

**Auth legend**

| Value | Meaning |
|-------|---------|
| optional | Works logged out; extra fields / 18+ / private host when authed |
| required | Any signed-in user |
| host | Owner of this live |
| host/mod | Host or a moderator on this live |
| host/guest | Host or the on-stage guest |
| staff | Permission `lives.admin.read` or `lives.admin.moderate` |
| LiveKit | Server-to-server webhook (not the app) |

**Era** = when we added it for TikTok parity (`core` = original LIVE, then P0 / P1 / P2 / P3).

---

## Why these endpoints exist (product map)

TikTok LIVE is not one API. The app needs separate calls because each job is different:

| Job | Why a dedicated API |
|-----|---------------------|
| Go live / end / pause | Room + LiveKit token + status must stay consistent |
| For You / Nearby / Following | Different ranking; Nearby must not inject ads |
| Join | Issues a **subscribe token**, counts a viewer, records traffic source |
| Chat / likes / gifts | High volume; gifts also hit the wallet (not `/lives`) |
| Guests vs host-to-host co-host | Guest = seat in **this** room. Cohost = two **other LIVE rooms** linked |
| PK / 2v2 / BO3 / power-ups | Timed match with scores; cannot reuse a guest seat |
| Replay / clips | Video file after the room is gone |
| Summary | Host end screen — history stays after `ENDED` |
| Admin | Staff must end / boost / kick without being the host |
| Shop / fan club / promote | Other modules, but the HUD calls them from LIVE |
| Voice Chat | Same LIVE APIs with `mediaMode: AUDIO` — mic only, no video tile |
| Tickets / games / House / scene | Paid entry, in-LIVE games, multi-room venue, dual/screen |

After **end**, comments, gifts, who-watched, and likes **stay**. `viewers` (watching now) becomes **0**. See [user sort an live info.md](../users/user%20sort%20an%20live%20info.md).

---

## A. New in P0 / P1 / P2 / P3 / audio (read these first)

### P0 — replay, report, shop bag, fan club, post-live stats

| Method | Path | Auth | Why |
|--------|------|------|-----|
| `GET` | `/lives/:id/replay` | optional | Watch the recording after `ENDED`. Counts a replay view. |
| `POST` | `/lives/:id/replay` | host | Publish a replay URL if auto-record failed. |
| `DELETE` | `/lives/:id/replay` | host | Remove replay (host takedown). |
| `POST` | `/lives/:id/report` | required | Report **this LIVE** (same queue as `POST /reports` with `liveId`). |
| `GET` | `/lives/:id/summary` | host | End-screen: unique viewers, watch time, comments, coins, top gifters, new followers, traffic, shop. |
| `PATCH` | `/products/lives/:liveId/items/:productId/deal` | host | Flash price / coupon on a bag item (TikTok shop bag). |
| `GET` | `/creators/:creatorId/fan-club` | optional | Club card, tiers, emotes, `isMember`. |
| `PATCH` | `/creators/:creatorId/fan-club` | host | Enable club, name, BASIC price. |
| `POST` | `/creators/:creatorId/fan-club/subscribe` | required | Pay coins for BASIC / PLUS / PREMIUM. |
| `DELETE` | `/creators/:creatorId/fan-club/subscribe` | required | Leave club. |
| `POST` | `/creators/:creatorId/fan-club/emotes` | host | Add a paid emote (`minTier`). |
| `DELETE` | `/creators/:creatorId/fan-club/emotes/:emoteId` | host | Remove emote. |
| `GET` | `/creators/:creatorId/fan-club/members` | host | Member list. |
| `GET` | `/users/me/fan-clubs` | required | Clubs I joined. |

Join body for stats: `{ "trafficSource": "FOR_YOU", "campaignId": "…" }`.

### P1 — RTMP studio, Nearby, 18+, clips, 2-room co-host, team PK

| Method | Path | Auth | Why |
|--------|------|------|-----|
| `GET` | `/lives/:id/studio` | host | RTMP URL + stream key for OBS / LIVE Studio. |
| `GET` | `/lives/:id/settings` | host | Read guest + P1 flags (18+, Nearby coords, replay). PATCH-only was not enough for the settings screen. |
| `PATCH` | `/lives/:id/settings` | host | Same flags while LIVE (replay toggle starts/stops Egress). |
| `GET` | `/lives/nearby` | optional | Nearby tab. Needs `latitude`/`longitude`. **No** promote inject. |
| `GET` | `/lives/feed?nearby=true` | optional | Same as Nearby (one feed client). |
| `POST` | `/lives/:id/clips` | host | Mark a highlight on a READY replay (`startSeconds` / `endSeconds`). |
| `GET` | `/lives/:id/clips` | optional | List clips. |
| `POST` | `/lives/:id/clips/:clipId/post` | host | Publish clip to For You (`Post` VIDEO). |
| `GET` | `/lives/:id/cohost/hosts` | host | Other hosts currently LIVE (invite picker). |
| `GET` | `/lives/:id/cohost` | host | My co-host sessions (invite / active). |
| `POST` | `/lives/:id/cohost/invite` | host | Link **another live room** (`guestLiveId`). Not a guest seat. |
| `POST` | `/lives/:id/cohost/:sessionId/accept` | host | Other host accepts. |
| `POST` | `/lives/:id/cohost/:sessionId/end` | host | Hang up multi-room. |
| `GET` | `/lives/:id/battle/open-teams` | host | Open 2v2 lobbies with empty slots. |
| `POST` | `/lives/:id/battle` `{ "mode": "TEAM" }` | host | Open a team PK lobby (do not need 4 hosts yet). |
| `POST` | `/lives/:yourLiveId/battle/:battleId/join` | host | Join team `1` or `2`. |
| `POST` | `/lives/:id/battle/:battleId/invite` | host | Captain invites a teammate live. |
| `POST` | `/lives/:id/battle/:battleId/leave` | host | Leave a team lobby. |
| `POST` | `/lives/:id/battle/match` `{ "mode": "TEAM" }` | host | Auto-open a team lobby. |

18+ is **not** a new route: set `ageRestricted` on create / settings. Viewer must `PATCH /users/me` `{ "dateOfBirth": "YYYY-MM-DD" }`.

### P2 — pause, 3–4 host co-host, BO3, power-ups, look

| Method | Path | Auth | Why |
|--------|------|------|-----|
| `POST` | `/lives/:id/pause` | host | Pause camera; room stays `LIVE`; host disconnect does not auto-end. |
| `POST` | `/lives/:id/resume` | host | Unpause. Socket `livePaused`. |
| `PATCH` | `/lives/:id/look` | host | Bind beauty / filter / effect slugs so guests match (`liveLook`). |
| `POST` | `/lives/:id/battle` `{ "bestOf": 3 }` | host | Best-of-3 series (`wins1` / `wins2`). |
| `POST` | `/lives/:id/battle/:battleId/power-up` | host | `GLOVE` / `TIME` / `STUN` during PK. |

3–4 host co-host reuses `/cohost/*` (up to 3 partners). Join/start returns `cohosts[]`.

### P3 — scene, tickets, games, LIVE House, topic, profile LIVE

| Method | Path | Auth | Why |
|--------|------|------|-----|
| `PATCH` | `/lives/:id/scene` | host | Persist CAMERA / SCREEN / DUAL + facing (was socket-only). |
| `GET` | `/lives/:id/ticket` | optional | Price + whether I already paid. |
| `POST` | `/lives/:id/ticket` | required | Pay coins (80/20). Required before join when ticketed. |
| `GET` | `/lives/games/catalog` | optional | Official quiz / wheel / lucky draw. |
| `POST` | `/lives/:id/games` | host | Start one ACTIVE in-LIVE game. |
| `GET` | `/lives/:id/games/active` | optional | Current game + plays (quiz answer hidden). |
| `POST` | `/lives/:id/games/:gameId/play` | required | One play per viewer. |
| `POST` | `/lives/:id/games/:gameId/end` | host | Close game; lucky-draw winner. |
| `POST` | `/lives/houses` | required | Create a multi-room venue. |
| `GET` | `/lives/houses` | optional | Open houses + LIVE rooms. |
| `GET` | `/lives/houses/:houseId` | optional | House detail. |
| `POST` | `/lives/houses/:houseId/rooms` | host | Attach **your** live as a room. |
| `PATCH` | `/lives/houses/:houseId` | host | Close the house. |

`topic` / `ticketEnabled` / `ticketPriceCoins` are on create, PATCH live, and settings. Feed: `?topic=`. Profile: `isLive` + `currentLive` on `GET /users/:id` and `GET /auth/me`.

---

## 1. Discovery

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `GET` | `/lives/feed` | optional | core | For You / Following / category. Main LIVE tab. May inject promoted lives. Query `mediaMode=AUDIO` for Voice Chat only. |
| `GET` | `/lives/audio` | optional | audio | TikTok Voice Chat tab (sound rooms, no video). Same as `feed?audioOnly=true`. Query `topic` for radio shows. |
| `GET` | `/lives/games/catalog` | optional | P3 | Official in-LIVE games (quiz / wheel / lucky draw). |
| `GET` | `/lives/houses` | optional | P3 | Open LIVE House venues. |
| `POST` | `/lives/houses` | required | P3 | Create a multi-room house. |
| `GET` | `/lives/houses/:houseId` | optional | P3 | House + rooms. |
| `POST` | `/lives/houses/:houseId/rooms` | host | P3 | Attach your live as a room. |
| `PATCH` | `/lives/houses/:houseId` | host | P3 | Close the house. |
| `GET` | `/lives/nearby` | optional | P1 | Distance-sorted lives. Viewer GPS required. Organic only (no ads). |
| `GET` | `/lives/mine` | required | core | Host history: planned, live, **ended**. Profile “my lives” + end-screen list. |
| `GET` | `/lives/leaderboard/hourly` | optional | core | Global hourly rank (TikTok LIVE rank). |
| `GET` | `/lives/leagues` | optional | core | League ladder definitions (B2, A1, S…). |
| `GET` | `/lives/host-league/:userId` | optional | core | One host’s league + earnings. Profile / LIVE HUD badge. |

**Feed query:** `page`, `limit`, `categoryId`, `followingOnly`, `latitude`, `longitude`, `nearby`, `radiusKm` (Nearby, default 50, max 150), `mediaMode`, `audioOnly`, `topic`.

---

## 2. Host lifecycle

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `POST` | `/lives` | required | core | Create `PLANNED` or go live (`startNow`). Title, cover, category, 18+, lat/lng, replay, look, **`mediaMode: AUDIO`** for Voice Chat, **`topic`**, **`ticketEnabled`**. Returns LiveKit **host** token when started. |
| `PATCH` | `/lives/:id` | host | core | Edit title / cover / category / replay / age / location / topic / tickets before or during LIVE. |
| `GET` | `/lives/:id/settings` | host | P1 | Load guest + P1 settings form. |
| `PATCH` | `/lives/:id/settings` | host | core+P1 | Guest rules, 18+, Nearby pair, `replayEnabled` (starts/stops recording). |
| `POST` | `/lives/:id/start` | host | core | `PLANNED` → `LIVE`. Creates LiveKit room, host token, optional Ingress + Egress. |
| `POST` | `/lives/:id/end` | host | core | Teardown: battles, auctions, room, sessions, guests. Status `ENDED`. History **kept**. |
| `POST` | `/lives/:id/pause` | host | P2 | Brief break without ending (TikTok pause). |
| `POST` | `/lives/:id/resume` | host | P2 | Continue after pause. |
| `PATCH` | `/lives/:id/look` | host | P2 | Persist beauty/filter so other tiles can apply the same catalog look. |
| `PATCH` | `/lives/:id/scene` | host | P3 | Scene switcher + dual cam + persist facing. |
| `GET` | `/lives/:id/studio` | host | P1 | OBS / LIVE Studio: `rtmpUrl` + `streamKey`. Null if Ingress worker is down. |

---

## 3. Watch, presence, replay

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `GET` | `/lives/:id` | optional | core | Live card + host + `paused` + `look` + `replay`. 18+ / private / block checks. Guests get 403 on 18+ rooms. |
| `POST` | `/lives/:id/join` | required | core+P0 | **Enter the room.** LiveKit viewer token, open viewer session, emit `liveViewers`. Body: `trafficSource`, `campaignId` (promoted slot). Ticketed rooms: **403** until `POST /ticket`. |
| `GET` | `/lives/:id/ticket` | optional | P3 | Ticket price + `hasTicket`. |
| `POST` | `/lives/:id/ticket` | required | P3 | Pay coins to enter a ticketed LIVE. |
| `GET` | `/lives/:id/games/active` | optional | P3 | Current official game. |
| `POST` | `/lives/:id/games` | host | P3 | Start quiz / wheel / lucky draw. |
| `POST` | `/lives/:id/games/:gameId/play` | required | P3 | One play per user. |
| `POST` | `/lives/:id/games/:gameId/end` | host | P3 | End game and publish result. |
| `POST` | `/lives/:id/leave` | required | core | Close session, add `watchSeconds`, decrement presence. |
| `GET` | `/lives/:id/viewers` | optional | core | Who is in the room. After end use `?activeOnly=false` for **who watched**. |
| `POST` | `/lives/:id/share` | required | core | Increment `shareCount` + optional target (story/chat). |
| `POST` | `/lives/:id/remind` | required | core | Notify me when a `PLANNED` live starts. |
| `GET` | `/lives/:id/replay` | optional | P0 | Play replay; increment `replayViewCount`. After `ENDED` (+ host can preview earlier). |
| `POST` | `/lives/:id/replay` | host | P0 | Manual replay URL (fallback if Egress failed). |
| `DELETE` | `/lives/:id/replay` | host | P0 | Hide replay. |
| `POST` | `/lives/:id/report` | required | P0 | Safety: report this stream. |

**Join is required to watch video.** `GET /lives/:id` is metadata only.

---

## 4. Chat, likes, comments

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `POST` | `/lives/:id/like` | required | core | Heart tap. Every tap increments `likeCount`. Socket `liveLike`. |
| `POST` | `/lives/:id/comments` | required | core | Send chat (1–500 chars). Honors chat rules / mute. |
| `GET` | `/lives/:id/comments` | optional | core | History + pinned. **Works after ENDED.** |
| `DELETE` | `/lives/:id/comments/:commentId` | host/mod/author | core | Soft-delete. |
| `POST` | `/lives/:id/comments/:commentId/pin` | host/mod | core | Pin one comment to the HUD. |
| `POST` | `/lives/:id/comments/:commentId/unpin` | host/mod | core | Unpin. |
| `PATCH` | `/lives/:id/chat-rules` | host | core | `chatMode`, slow mode, blocked words, `watchAccessMode`. |
| `POST` | `/lives/:id/gift-goal` | host | core | “X coins for a song” progress bar. |

**Gifts are not `/lives`:** `POST /gifts/send` with `liveId`. They still bump `totalEarnedCoins` and PK scores.

---

## 5. Viewer moderation (this live only)

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `POST` | `/lives/:id/viewers/:userId/mute-chat` | host/mod | core | Silence chat; they can still watch. |
| `POST` | `/lives/:id/viewers/:userId/unmute-chat` | host/mod | core | Restore chat. |
| `POST` | `/lives/:id/viewers/:userId/ban` | host/mod | core | Kick + block rejoin for this live. |
| `POST` | `/lives/:id/viewers/:userId/unban` | host/mod | core | Allow back. |

Restrictions are **deleted when the live ends** (they are not a platform ban).

---

## 6. Multi-guest (same room)

On-stage users in **this** LiveKit room (TikTok “multi-guest”).

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `GET` | `/lives/:id/guests` | optional | core | Seats + pending requests. |
| `POST` | `/lives/:id/guests/request` | required | core | Viewer asks to come up. |
| `POST` | `/lives/:id/guests/invite` | host/mod | core | Host invites a user. |
| `POST` | `/lives/:id/guests/accept-invite` | required | core | Invitee accepts → publish token. |
| `POST` | `/lives/:id/guests/:userId/accept` | host/mod | core | Accept a request. |
| `POST` | `/lives/:id/guests/:userId/reject` | host/mod | core | Decline request. |
| `POST` | `/lives/:id/guests/leave` | guest | core | Leave stage. |
| `POST` | `/lives/:id/guests/token` | guest | core | Refresh publish token if it expired. |
| `POST` | `/lives/:id/guests/:userId/kick` | host/mod | core | Force off stage. |
| `POST` | `/lives/:id/guests/:userId/mute` | host/mod | core | Mute their mic (server flag; client applies). |
| `POST` | `/lives/:id/guests/:userId/unmute` | host/mod | core | Unmute. |
| `POST` | `/lives/:id/guests/:userId/camera-off` | host/mod | core | Force camera off. |
| `POST` | `/lives/:id/guests/:userId/camera-on` | host/mod | core | Allow camera. |
| `POST` | `/lives/:id/guests/:userId/promote` | host | core | Guest → `CO_HOST` (same room, extra rights). |
| `POST` | `/lives/:id/guests/:userId/demote` | host | core | Co-host → guest. |

Blocked while the host is **paused** (P2).

---

## 7. Host-to-host co-host (other LIVE rooms) — P1/P2

Two to four **separate** lives linked. Different from §6.

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `GET` | `/lives/:id/cohost/hosts` | host | P1 | Pick another live host. |
| `GET` | `/lives/:id/cohost` | host | P1 | Session list. |
| `POST` | `/lives/:id/cohost/invite` | host | P1 | `{ "guestLiveId" }`. Up to 3 partners (P2). |
| `POST` | `/lives/:id/cohost/:sessionId/accept` | host | P1 | Other host joins; gets subscribe token (`cohost` identity). |
| `POST` | `/lives/:id/cohost/:sessionId/end` | host | P1 | End link. |

Join/start bundle includes `cohost` (first) + `cohosts[]`.

---

## 8. Room moderators

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `GET` | `/lives/:id/moderators` | required | core | Who can mute / kick / pin. |
| `POST` | `/lives/:id/moderators` | host | core | `{ "userId" }` add a mod. |
| `DELETE` | `/lives/:id/moderators/:userId` | host | core | Remove a mod. |

---

## 9. PK battles (1v1, team / 2v2, BO3)

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `GET` | `/lives/:id/battle` | optional | core | Active battle + scores / teams / rounds. HUD poll + socket fallback. |
| `GET` | `/lives/:id/battle/opponents` | host | core | Other LIVE hosts to challenge. |
| `POST` | `/lives/:id/battle` | host | core+P1+P2 | Start PK. Body: `opponentLiveId` or `mode: TEAM`, `durationSeconds`, `scoring`, `bestOf`. |
| `POST` | `/lives/:id/battle/match` | host | core+P1 | Auto-match 1v1 or open a TEAM lobby. |
| `GET` | `/lives/:id/battle/open-teams` | host | P1 | Lobbies with empty slots. |
| `POST` | `/lives/:id/battle/:battleId/join` | host | P1 | `{ "team": 1 \| 2 }` — 2v2 join. |
| `POST` | `/lives/:id/battle/:battleId/invite` | host | P1 | `{ "teammateLiveId" }`. |
| `POST` | `/lives/:id/battle/:battleId/leave` | host | P1 | Leave lobby before start. |
| `POST` | `/lives/:id/battle/:battleId/end` | host | core+P2 | Finish match or **whole BO3 series**. |
| `POST` | `/lives/:id/battle/multiplier` | host | core | Temporary score multiplier (speed challenge). |
| `POST` | `/lives/:id/battle/:battleId/power-up` | host | P2 | `{ "type": "GLOVE" \| "TIME" \| "STUN" }`. |

Team 1 = live1+live3, team 2 = live2+live4. Scoring: `ALL` \| `GIFTS` \| `LIKES` \| `SPECIFIC_GIFT`.

Cannot start PK while **paused**.

---

## 10. Clips → For You (P1)

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `GET` | `/lives/:id/clips` | optional | P1 | Highlights on this replay. |
| `POST` | `/lives/:id/clips` | host | P1 | `{ startSeconds, endSeconds, title, clipUrl? }`. Needs READY replay. |
| `POST` | `/lives/:id/clips/:clipId/post` | host | P1 | Create a VIDEO post. Idempotent if already posted. |

---

## 11. Interactive (polls, Q&A, treasure)

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `POST` | `/lives/:id/polls` | host | core | Start a poll. |
| `GET` | `/lives/:id/polls/active` | optional | core | Current poll + counts. |
| `POST` | `/lives/:id/polls/:pollId/vote` | required | core | Cast a vote. |
| `POST` | `/lives/:id/polls/:pollId/end` | host | core | Close voting. |
| `POST` | `/lives/:id/qa` | required | core | Viewer asks a question. |
| `GET` | `/lives/:id/qa` | optional | core | Question list. |
| `POST` | `/lives/:id/qa/:qaId/answer` | host | core | Mark answered. |
| `POST` | `/lives/:id/qa/:qaId/pin` | host | core | Pin a question. |
| `POST` | `/lives/:id/treasure-boxes` | host | core | Drop coins with a countdown. |
| `GET` | `/lives/:id/treasure-boxes` | optional | core | Active / waiting boxes. |
| `POST` | `/lives/:id/treasure-boxes/:boxId/claim` | required | core | Claim a share into the wallet. |

---

## 12. Live shopping (auctions + product bag)

### On `/lives`

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `POST` | `/lives/:id/auctions` | host | core | Bind an auction to this live (seller-verified). |
| `GET` | `/lives/:id/auctions/active` | optional | core | HUD: running auctions. |
| `GET` | `/lives/:id/auctions` | optional | core | History. Query `status`. |
| `GET` | `/lives/:id/gallery` | optional | core | TikTok “المعرض” — pinned + active shop. |
| `PATCH` | `/lives/:id/auctions/reorder` | host | core | Gallery order. |
| `PATCH` | `/lives/:id/auctions/:auctionId/pin` | host | core | Pin one auction. |

### On `/products` (bag)

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `POST` | `/products/lives/:liveId/items` | host | core | Add a product to the bag. |
| `GET` | `/products/lives/:liveId/items` | optional | core | Bag list (HUD). |
| `PATCH` | `/products/lives/:liveId/items/:productId/pin` | host | core | Pin a product. |
| `PATCH` | `/products/lives/:liveId/items/reorder` | host | core | Bag order. |
| `PATCH` | `/products/lives/:liveId/items/:productId/deal` | host | P0 | Flash price + coupon. |
| `DELETE` | `/products/lives/:liveId/items/:productId` | host | core | Remove from bag. |

Checkout still uses the normal products checkout with `liveId` so the summary can count shop revenue.

---

## 13. Leaderboards on a live

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `GET` | `/lives/:id/leaderboard/gifters` | optional | core | Top gifters (`window=session\|hour`). Works after end. |
| `GET` | `/lives/:id/leaderboard/hourly` | optional | core | This live’s hourly rank vs others. |

---

## 14. Post-live summary

| Method | Path | Auth | Era | Why |
|--------|------|------|-----|-----|
| `GET` | `/lives/:id/summary` | host | P0 | Host end screen. Unique viewers, watch seconds, likes, comments, coins, top 5 gifters, new followers, traffic breakdown, shop. |

Admin copy: `GET /lives/admin/:id/summary`.

Who watched after end: `GET /lives/:id/viewers?activeOnly=false`.

---

## 15. Promote this LIVE (ads)

Prefix `/promotions`. Paid For You inject. See [live-promotions.md](./live-promotions.md).

| Method | Path | Auth | Why |
|--------|------|------|-----|
| `GET` | `/promotions/lives/options` | required | Packages / targeting for a LIVE campaign. |
| `GET` | `/promotions/lives/custom/preview` | required | Price preview. |
| `POST` | `/promotions/lives` | required | Create a LIVE campaign (`liveId`). |
| `GET` | `/promotions/lives/mine` | required | My LIVE campaigns. |
| `GET` | `/promotions/lives/:id` | required | One campaign. |
| `GET` | `/promotions/lives/:id/stats` | required | Spend / impressions. |
| `GET` | `/promotions/lives/by-live/:liveId` | required | Campaigns for one live. |
| `GET` | `/promotions/lives/by-live/:liveId/stats` | required | Aggregated stats. |
| `POST` | `/promotions/lives/:id/pay` | required | Pay and start inject. |
| `PATCH` | `/promotions/lives/:id` | required | Edit while draft. |
| `PATCH` | `/promotions/lives/:id/pause` | required | Pause spend. |
| `PATCH` | `/promotions/lives/:id/resume` | required | Resume. |
| `PATCH` | `/promotions/lives/:id/cancel` | required | Cancel. |

Feed injects these on main For You only (not Nearby / Following). Join with `campaignId` to bill the view.

---

## 16. Fan club (subscriptions)

Prefix `/creators/:creatorId/fan-club`. Why: TikTok subscriber badge, exclusive chat (`SUBSCRIBERS` mode), paid emotes. **Not** `PATCH /users/me`.

See P0 table in section A.

---

## 17. Admin (`/lives/admin`)

| Method | Path | Permission | Why |
|--------|------|------------|-----|
| `GET` | `/lives/admin/stats` | read | Ops dashboard: live now, ended today, concurrent viewers. |
| `GET` | `/lives/admin/all` | read | Staff list (all statuses, including BANNED). |
| `GET` | `/lives/admin/:id` | read | Full card + moderation counters. |
| `GET` | `/lives/admin/:id/summary` | read | Same post-live report as the host. |
| `GET` | `/lives/admin/:id/restrictions` | read | Current mutes/bans (empty after end). |
| `POST` | `/lives/admin/:id/end` | moderate | Force-end a stuck / violating stream. |
| `POST` | `/lives/admin/:id/ban` | moderate | Ban the live (`BANNED`, no public replay). |
| `POST` | `/lives/admin/:id/boost` | moderate | `feedBoostUntil` — push in For You. |
| `POST` | `/lives/admin/:id/unboost` | moderate | Clear boost. |
| `PATCH` | `/lives/admin/:id/settings` | moderate | Override guest / 18+ / replay. |
| `DELETE` | `/lives/admin/:id/comments/:commentId` | moderate | Staff delete chat. |
| `POST` | `/lives/admin/:id/viewers/:userId/mute-chat` | moderate | Staff mute. |
| `POST` | `/lives/admin/:id/viewers/:userId/unmute-chat` | moderate | Staff unmute. |
| `POST` | `/lives/admin/:id/viewers/:userId/ban` | moderate | Staff ban from live. |
| `POST` | `/lives/admin/:id/viewers/:userId/unban` | moderate | Staff unban. |
| `POST` | `/lives/admin/:id/guests/:userId/kick` | moderate | Staff kick guest. |
| `POST` | `/lives/admin/:id/guests/:userId/mute` | moderate | Staff mute guest. |
| `POST` | `/lives/admin/:id/guests/:userId/unmute` | moderate | Staff unmute guest. |
| `GET` | `/lives/admin/:id/battle` | read | Inspect PK. |
| `POST` | `/lives/admin/:id/battle/:battleId/end` | moderate | Force-end PK. |
| `POST` | `/lives/admin/:id/polls/:pollId/end` | moderate | Force-end poll. |

Permissions: `lives.admin.read` · `lives.admin.moderate`.

---

## 18. Infrastructure

| Method | Path | Auth | Why |
|--------|------|------|-----|
| `POST` | `/lives/webhooks/livekit` | LiveKit HMAC | Presence + empty-room auto-end + **`egress_ended`** → set `replayUrl`. **Not for the app.** |

Configure in LiveKit: `deploy/livekit.yaml` → `webhook.urls`.

---

## 19. Related (not under `/lives` but LIVE HUD)

| Method | Path | Why |
|--------|------|-----|
| `POST` | `/gifts/send` | Send a gift (`liveId`). Wallet + PK score + `liveGift` socket. |
| `GET` | `/gifts` / `/gifts/groups` | Gift catalog for the picker. |
| `PATCH` | `/users/me` `{ dateOfBirth }` | Unlock 18+ lives. |
| `PUT` | `/users/me/location` | Viewer GPS; pass the same coords on Nearby. |
| `GET` | `/auth/me` | Self profile (DOB, league, fan club, **`isLive` + `currentLive`**). There is no `GET /users/me`. |
| `GET` | `/users/:id` | Other profile — same `isLive` / `currentLive` (also on locked cards). |
| `POST` | `/camera-studio/...` | Beauty / filter **catalog**. Persist choice with `PATCH /lives/:id/look`. |
| `PATCH` | `/lives/:id/scene` | Persist CAMERA / SCREEN / DUAL + facing. Socket `switchLiveCamera` still flips instantly. |

---

## Typical app flows (which endpoints, in order)

### Host goes live (phone)

1. `POST /lives` `{ "startNow": true, "title": "…" }` → publish with `token`
2. Optional: `GET /lives/:id/studio` if using OBS
3. Optional: `PATCH /lives/:id/look` after picking a filter
4. `POST /lives/:id/end` when done
5. `GET /lives/:id/summary` end screen
6. If replay READY: `POST /lives/:id/clips` → `POST …/post`

### Viewer watches

1. `GET /lives/feed` or `GET /lives/nearby` or `GET /lives/audio`
2. `GET /lives/:id` (card). If `ticketEnabled`, `POST /lives/:id/ticket` first
3. `POST /lives/:id/join` `{ "trafficSource": "FOR_YOU" }` → subscribe with `token`
4. `POST /lives/:id/like` · `POST /lives/:id/comments` · `POST /gifts/send`
5. `POST /lives/:id/leave`

### 2v2 PK

1. Host A: `POST /lives/:id/battle` `{ "mode": "TEAM" }`
2. Others: `GET /lives/:id/battle/open-teams`
3. `POST /lives/:yourId/battle/:battleId/join` `{ "team": 2 }`
4. Watch `GET /lives/:id/battle` + socket `liveBattle`
5. `POST …/power-up` during fight (P2)
6. `POST …/end` when the series is over

### Multi-room co-host

1. `GET /lives/:id/cohost/hosts`
2. `POST /lives/:id/cohost/invite` `{ "guestLiveId" }`
3. Other host: `POST /lives/:theirId/cohost/:sessionId/accept`
4. Use `cohosts[]` tokens from join/start to subscribe to partner rooms

---

## Socket events (why REST is not enough)

REST starts / lists. Sockets update the HUD without polling:

| Event | Why |
|-------|-----|
| `liveViewers` | Counter |
| `liveComment` · `liveLike` · `liveGift` | Chat / hearts / gifts |
| `liveEnded` · `livePaused` | Leave / pause UI |
| `liveLook` | Apply host filter |
| `liveGuest` · `liveCohost` | Stage / multi-room |
| `liveBattle` · `liveBattlePhase` | PK scores, rounds, power-ups |
| `livePollUpdated` · `liveTreasureBox*` | Interactive |
| `liveCameraChanged` · `liveScene` | Front/back + scene/dual |
| `liveTicket` · `liveGame` · `liveHouse` | Paid entry, official games, venue |
| `liveProduct` | Shop deal |

Connect to rooms `live_<liveId>` and `user_<userId>`. See [events/mobile-api.md](../events/mobile-api.md).

---

## Count (this build)

| Surface | Approx. routes |
|---------|----------------|
| `/lives` app | ~110 |
| `/lives/admin` | 22 |
| Webhook | 1 |
| `/products/lives/…` | 6 |
| `/creators/…/fan-club` + my clubs | 8 |
| `/promotions/lives/…` | 12 |

If a path is missing here, it is not in `lives.controller.ts` / the LIVE-related controllers above.

---

## Related docs

| File | Use |
|------|-----|
| [endpoints.md](./endpoints.md) | Older reference with JSON samples |
| [mobile-api.md](./mobile-api.md) | Full mobile guide |
| [admin-api.md](./admin-api.md) | Staff screens |
| [live-p0-parity.md](./live-p0-parity.md) | Replay, report, bag, fan club, summary |
| [live-p1-parity.md](./live-p1-parity.md) | Studio, Nearby, 18+, clips, co-host, 2v2 |
| [live-p2-parity.md](./live-p2-parity.md) | Pause, 4-host, BO3, power-ups, look |
| [live-p3-parity.md](./live-p3-parity.md) | Scene, tickets, games, House, topic, profile LIVE |
| [live-audio-rooms.md](./live-audio-rooms.md) | Voice Chat / sound rooms |
| [README.md](./README.md) | Doc index |
| [live-promotions.md](./live-promotions.md) | Paid For You |
| [user sort an live info.md](../users/user%20sort%20an%20live%20info.md) | What stays after end + admin user sort |
