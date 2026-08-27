# Lives — Production & Testing

> What you need to **run**, **deploy**, and **verify** TikTok-style LIVE.  
> Architecture: [logic.md](./logic.md) · Mobile: [mobile-api.md](./mobile-api.md) · Admin: [admin-api.md](./admin-api.md)

---

## 1. Quick checklist

| Step | Local test | Production |
|------|------------|------------|
| Postgres up + migrations | ✓ | ✓ |
| LiveKit container | ✓ | ✓ |
| Nest `LIVEKIT_*` env | ✓ | ✓ (`wss://` + strong keys) |
| LiveKit → Nest webhooks | Recommended | **Required** |
| UDP `50000–50100` open | Host firewall if remote | **Required** on VPS |
| Nginx LiveKit (`live.*`) | Optional | **Required** for `wss://` |
| Firebase auth tokens | ✓ | ✓ |
| Client LiveKit SDK | ✓ | ✓ |

---

## 2. Environment variables

Copy from [`.env.production.example`](../../.env.production.example):

```bash
# Clients (mobile/web) connect here
LIVEKIT_URL=ws://localhost:7880          # local
# LIVEKIT_URL=wss://live.example.com     # production

LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=secret_must_be_at_least_32_characters_long

# Nest RoomService (delete room, mute guest). Docker prod:
LIVEKIT_HTTP_URL=http://livekit:7880
# Local (API on host, LiveKit in Docker):
# LIVEKIT_HTTP_URL=http://localhost:7880
```

**Generate production keys** (do not ship `devkey`):

```bash
docker run --rm livekit/generate
```

Put the printed key/secret into:

1. `.env` → `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET`
2. [`deploy/livekit.yaml`](../../deploy/livekit.yaml) → `keys:` and `webhook.api_key`

They **must match**.

---

## 3. Local: start & test

### 3.1 Infrastructure

```bash
# Postgres + LiveKit
docker compose up -d postgres livekit

# API (host)
cp .env.production.example .env   # or your existing .env
# Set for local:
#   LIVEKIT_URL=ws://localhost:7880
#   LIVEKIT_HTTP_URL=http://localhost:7880
#   DATABASE_URL=postgresql://root:rootpassword@localhost:5432/tiktok_db

npx prisma migrate deploy   # or db push
npm run start:dev
```

LiveKit listens on `7880` (WS), `7881` (TCP RTC), `50000–50100/udp` (media).

### 3.2 Webhooks on local (recommended)

Local compose mounts [`deploy/livekit.local.yaml`](../../deploy/livekit.local.yaml) (webhooks commented).

For API on the **host** while LiveKit is in Docker, uncomment:

```yaml
webhook:
  api_key: devkey
  urls:
    - http://host.docker.internal:3000/lives/webhooks/livekit
```

Then `docker compose restart livekit`.

Production compose uses [`deploy/livekit.yaml`](../../deploy/livekit.yaml) → `http://api:3000/lives/webhooks/livekit`.

Without webhooks, presence still works via Socket `leave` / disconnect, but host crash may leave a `LIVE` row until `empty_timeout` (60s) + `room_finished`.

### 3.3 Smoke test (HTTP)

Use two Firebase users: **host** and **viewer**.

```bash
API=http://localhost:3000
HOST_TOKEN=...    # Firebase ID token
VIEWER_TOKEN=...

# 1. Create + start
curl -s -X POST "$API/lives" \
  -H "Authorization: Bearer $HOST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test live","startNow":true}'
# → { live, token, url, role: "host" }

LIVE_ID=<live.id>
HOST_LK_TOKEN=<token>
LK_URL=<url>

# 2. Viewer join
curl -s -X POST "$API/lives/$LIVE_ID/join" \
  -H "Authorization: Bearer $VIEWER_TOKEN"
# → { live, token, url, role: "viewer" }

# 3. Like (heart taps — each call increments)
curl -s -X POST "$API/lives/$LIVE_ID/like" \
  -H "Authorization: Bearer $VIEWER_TOKEN"

# 4. Comment
curl -s -X POST "$API/lives/$LIVE_ID/comments" \
  -H "Authorization: Bearer $VIEWER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content":"hello"}'

# 5. End
curl -s -X POST "$API/lives/$LIVE_ID/end" \
  -H "Authorization: Bearer $HOST_TOKEN"
```

### 3.4 Smoke test (media)

1. Host: LiveKit SDK `Room.connect(url, hostToken)` → **publish** camera/mic.
2. Viewer: `Room.connect(url, viewerToken)` → **subscribe** only.
3. Socket.IO: after Firebase socket auth, emit `joinLive({ liveId })` and listen for `liveComment`, `liveLike`, `liveViewers`, `liveGift`, `liveEnded`.

### 3.5 Unit tests

```bash
npx jest src/lives
```

---

## 4. Production deploy

### 4.1 Compose

```bash
cp .env.production.example .env
# Edit secrets, LIVEKIT_URL=wss://live.yourdomain.com, LIVEKIT_HTTP_URL=http://livekit:7880

docker compose -f docker-compose.prod.yml up -d --build
```

Services: `postgres`, `api`, `livekit`, `nginx`.

### 4.2 DNS & TLS

| Host | Points to | Purpose |
|------|-----------|---------|
| `api.example.com` (or apex) | nginx `:80` / TLS | Nest REST + Socket.IO |
| `live.example.com` | nginx `:80` / TLS | LiveKit WS (`server_name live.*` in nginx) |

Put TLS in front (Certbot, Cloudflare, etc.). Clients need **`wss://live.example.com`**.

Set:

```bash
LIVEKIT_URL=wss://live.example.com
LIVEKIT_HTTP_URL=http://livekit:7880
```

### 4.3 Firewall / security group

Open inbound:

| Port | Proto | Why |
|------|-------|-----|
| 80 / 443 | TCP | nginx |
| 7881 | TCP | LiveKit RTC fallback |
| 50000–50100 | UDP | LiveKit media |

`7880` can stay internal if nginx terminates WSS to `livekit:7880`.

### 4.4 Webhooks (required)

[`deploy/livekit.yaml`](../../deploy/livekit.yaml) already posts to:

```text
http://api:3000/lives/webhooks/livekit
```

Effects:

| Event | Nest action |
|-------|-------------|
| Host `participant_left` / aborted | **End** the live |
| Viewer left | Close viewer session / update count |
| `room_finished` | End live if still `LIVE` |

Nest verifies the LiveKit signature (`rawBody: true` in `main.ts`).

### 4.5 Nginx

[`deploy/nginx.conf`](../../deploy/nginx.conf):

- `_` → API (REST + Socket.IO upgrade)
- `live.*` → LiveKit (long-lived WS)

Adjust `server_name` if your live host is not `live.*`.

---

## 5. Client integration checklist

- [ ] Never mint LiveKit JWTs on device — only use tokens from Nest (`/start`, `/join`, `/guests/token`).
- [ ] Host: `POST /lives` (or create + `/start`) → publish → Socket `joinLive`.
- [ ] Viewer: `POST /lives/:id/join` → subscribe → Socket `joinLive`.
- [ ] Leave: LiveKit disconnect + `POST /lives/:id/leave` + Socket `leaveLive`.
- [ ] End: host must call `POST /lives/:id/end` (preferred); webhook ends if host drops media.
- [ ] Gifts: `POST /gifts/send` with `{ giftId, liveId }`.
- [ ] Heart taps: call `POST /lives/:id/like` per tap (rate limit ~15/s); play animation on `liveLike`.
- [ ] Handle `liveEnded` → leave room and stop media.

Full API flows: [mobile-api.md](./mobile-api.md).

---

## 6. Robustness behaviors (backend)

| Scenario | Behavior |
|----------|----------|
| Concurrent `/end` + webhook | Atomic `LIVE` → `ENDED` claim; one teardown |
| Host disconnects LiveKit | Webhook ends stream |
| Viewer disconnect (socket / LiveKit) | Presence cleaned; viewer count refreshed from DB |
| Join/leave races | Viewer count = count of open `LiveViewerSession`s |
| Live end / ban | Finish battles, cancel live auctions (escrow), delete LiveKit room, clear guests/restrictions |
| Heart spam | Rate-limited increments; unique `LiveLike` still stored for analytics |

---

## 7. Troubleshooting

| Symptom | Check |
|---------|-------|
| `LiveKit is not configured` | `LIVEKIT_URL` / `API_KEY` / `API_SECRET` on Nest |
| Token works but no video | UDP 50000–50100, `use_external_ip`, client ICE |
| `Invalid LiveKit webhook` | Same key/secret in yaml + env; Nest `rawBody` |
| Viewer count stuck | Webhooks + Socket disconnect; call `/leave` |
| Live stuck `LIVE` after host crash | Webhooks enabled? `empty_timeout` / `room_finished` |
| WSS fails in prod | nginx `live.*` block, TLS, `LIVEKIT_URL=wss://...` |
| Guest mute ignored | Nest RoomService via `LIVEKIT_HTTP_URL` |

---

## 8. Related files

| Path | Role |
|------|------|
| `src/lives/` | Nest module |
| `deploy/livekit.yaml` | Prod LiveKit + webhooks → `api:3000` |
| `deploy/livekit.local.yaml` | Local LiveKit (webhooks optional) |
| `deploy/nginx.conf` | API + LiveKit (`live.*`) proxy |
| `docker-compose.yml` | Local Postgres + LiveKit |
| `docker-compose.prod.yml` | Full prod stack (api + livekit + nginx) |
| `.env.production.example` | Env template |
