# Lives — Complete API Endpoints Reference

> **Audience:** Frontend, Mobile (iOS/Android/Flutter/React Native), Backend Engineers & QA.  
> **Base URL:** `http://localhost:3000` (or `https://api.yourdomain.com`)  
> **Auth Header:** `Authorization: Bearer <Firebase_ID_Token>`  
> **Related:** [mobile-api.md](./mobile-api.md) · [admin-api.md](./admin-api.md) · [tasks.md](./tasks.md) · [live-database.md](./live-database.md)

---

## Table of Contents

- [1. Host Stream Lifecycle](#1-host-stream-lifecycle)
- [2. Discovery & Feed](#2-discovery--feed)
- [3. Viewer Watch & Presence](#3-viewer-watch--presence)
- [4. Realtime Chat, Likes & Pins](#4-realtime-chat-likes--pins)
- [5. Stream Viewer Moderation](#5-stream-viewer-moderation)
- [6. Multi-Guest Stage & Co-Hosting](#6-multi-guest-stage--co-hosting)
- [7. Stream Room Moderators](#7-stream-room-moderators)
- [8. PK Battles & Speed Multipliers](#8-pk-battles--speed-multipliers)
- [9. Interactive Tools (Goals, Polls, Q&A, Treasure Boxes)](#9-interactive-tools)
- [10. Live Shopping & Auction Gallery](#10-live-shopping--auction-gallery)
- [11. Hourly Leaderboards, Leagues & Fan Clubs](#11-hourly-leaderboards-leagues--fan-clubs)
- [12. Post-Live Analytics Summary](#12-post-live-analytics-summary)
- [13. Admin Management & Moderation](#13-admin-management--moderation)
- [14. Infrastructure Webhooks](#14-infrastructure-webhooks)

---

## 1. Host Stream Lifecycle

### `POST /lives`
Creates a planned stream or starts broadcasting immediately.

- **Auth:** Required (Any authenticated user)
- **Request Body:**
```json
{
  "title": "Acoustic Night & Song Requests",
  "coverUrl": "https://cdn.example.com/covers/stream.jpg",
  "categoryId": "c9284240-5b5c-4395-9788-0f56e9c9c812",
  "startNow": true
}
```
- **Response (201 Created with `startNow: true`):**
```json
{
  "live": {
    "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
    "title": "Acoustic Night & Song Requests",
    "roomName": "live_764be4ec-9e90-4828-98e9-4e78280fbe91",
    "streamUrl": "wss://live.example.com",
    "coverUrl": "https://cdn.example.com/covers/stream.jpg",
    "categoryId": "c9284240-5b5c-4395-9788-0f56e9c9c812",
    "status": "LIVE",
    "viewers": 0,
    "likeCount": 0,
    "totalEarnedCoins": 0,
    "guestsEnabled": true,
    "guestRequestMode": "EVERYONE",
    "maxGuests": 8,
    "layout": "GRID",
    "allowGuestCamera": true,
    "moderatorsCanManageGuests": true,
    "startedAt": "2026-08-15T12:00:00.000Z",
    "endedAt": null,
    "user": {
      "id": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
      "username": "sarah_singer",
      "fullName": "Sarah Adams",
      "avatarUrl": "https://cdn.example.com/avatars/sarah.jpg",
      "isVerified": true,
      "hostLeagueTier": "B2"
    }
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "url": "wss://live.example.com",
  "role": "host"
}
```

---

### `PATCH /lives/:id`
Updates stream metadata (title, cover, category).

- **Auth:** Required (Host only)
- **Request Body:**
```json
{
  "title": "Updated Acoustic Stream Title",
  "coverUrl": "https://cdn.example.com/new-cover.jpg",
  "categoryId": "c9284240-5b5c-4395-9788-0f56e9c9c812"
}
```
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "userId": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
  "title": "Updated Acoustic Stream Title",
  "roomName": "live_764be4ec-9e90-4828-98e9-4e78280fbe91",
  "streamUrl": "wss://live.example.com",
  "coverUrl": "https://cdn.example.com/new-cover.jpg",
  "categoryId": "c9284240-5b5c-4395-9788-0f56e9c9c812",
  "status": "LIVE",
  "viewers": 142,
  "likeCount": 2450,
  "totalEarnedCoins": 12500,
  "updatedAt": "2026-08-15T12:05:00.000Z"
}
```

---

### `POST /lives/:id/start`
Starts broadcasting an existing `PLANNED` live.

- **Auth:** Required (Host only)
- **Response (200 OK):**
```json
{
  "live": {
    "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
    "title": "Acoustic Night & Song Requests",
    "roomName": "live_764be4ec-9e90-4828-98e9-4e78280fbe91",
    "streamUrl": "wss://live.example.com",
    "status": "LIVE",
    "startedAt": "2026-08-15T12:00:00.000Z",
    "user": {
      "id": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
      "username": "sarah_singer",
      "avatarUrl": "https://cdn.example.com/avatars/sarah.jpg"
    }
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "url": "wss://live.example.com",
  "role": "host"
}
```

---

### `POST /lives/:id/end`
Ends broadcast, closes LiveKit room, cancels open auctions, and clears viewer sessions.

- **Auth:** Required (Host only)
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "userId": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
  "title": "Acoustic Night & Song Requests",
  "status": "ENDED",
  "viewers": 0,
  "likeCount": 38200,
  "totalEarnedCoins": 85000,
  "startedAt": "2026-08-15T10:00:00.000Z",
  "endedAt": "2026-08-15T11:45:00.000Z"
}
```

---

## 2. Discovery & Feed

### `GET /lives/feed`
Retrieves live streams for the vertical swipe Discovery Feed.

- **Auth:** Optional
- **Query Parameters:**
  - `page` (default 1)
  - `limit` (default 20, max 50)
  - `categoryId` (optional category filter)
  - `followingOnly` (`true` to show followed hosts only)
- **Response (200 OK):**
```json
{
  "data": [
    {
      "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
      "title": "Acoustic Night & Song Requests",
      "coverUrl": "https://cdn.example.com/covers/stream.jpg",
      "viewers": 142,
      "likeCount": 2450,
      "totalEarnedCoins": 12500,
      "isPopular": true,
      "popularReason": "hourly_rank",
      "hourlyRank": 3,
      "user": {
        "id": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
        "username": "sarah_singer",
        "avatarUrl": "https://cdn.example.com/avatars/sarah.jpg",
        "isVerified": true,
        "hostLeagueTier": "B2"
      }
    }
  ],
  "meta": {
    "total": 42,
    "page": 1,
    "limit": 20,
    "totalPages": 3
  }
}
```

---

### `GET /lives/mine`
Retrieves current user's past and planned live streams.

- **Auth:** Required
- **Query Parameters:** `page=1`, `limit=20`
- **Response (200 OK):**
```json
{
  "data": [
    {
      "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
      "title": "Acoustic Night & Song Requests",
      "coverUrl": "https://cdn.example.com/covers/stream.jpg",
      "status": "ENDED",
      "viewers": 0,
      "likeCount": 38200,
      "totalEarnedCoins": 85000,
      "startedAt": "2026-08-15T10:00:00.000Z",
      "endedAt": "2026-08-15T11:45:00.000Z"
    }
  ],
  "meta": {
    "total": 1,
    "page": 1,
    "limit": 20,
    "totalPages": 1
  }
}
```

---

## 3. Viewer Watch & Presence

### `GET /lives/:id`
Retrieves stream details, active auctions, pinned comment, and popular badges.

- **Auth:** Optional
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "title": "Acoustic Night & Song Requests",
  "coverUrl": "https://cdn.example.com/covers/stream.jpg",
  "status": "LIVE",
  "viewers": 142,
  "likeCount": 2450,
  "chatMode": "EVERYONE",
  "slowModeSeconds": 0,
  "giftGoalTitle": "Unlock Special Song 🎸",
  "giftGoalTarget": 10000,
  "giftGoalCurrent": 3400,
  "isPopular": true,
  "popularReason": "hourly_rank",
  "hourlyRank": 3,
  "pinnedComment": {
    "id": "c-pin-1",
    "content": "Welcome everyone! Feel free to request songs!",
    "user": {
      "id": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
      "username": "sarah_singer",
      "avatarUrl": "https://cdn.example.com/avatars/sarah.jpg"
    }
  },
  "activeAuctions": [
    {
      "id": "auc-1",
      "itemName": "Signed Guitar Strap",
      "itemImageUrl": "https://cdn.example.com/items/strap.jpg",
      "currentPrice": 45.0,
      "targetPrice": 50.0,
      "status": "ACTIVE"
    }
  ],
  "user": {
    "id": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
    "username": "sarah_singer",
    "avatarUrl": "https://cdn.example.com/avatars/sarah.jpg",
    "isVerified": true,
    "hostLeagueTier": "B2"
  }
}
```

---

### `POST /lives/:id/join`
Joins the stream as a viewer and receives LiveKit subscriber token.

- **Auth:** Required
- **Response (200 OK):**
```json
{
  "live": {
    "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "title": "Acoustic Night & Song Requests",
    "viewers": 143,
    "status": "LIVE"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "url": "wss://live.example.com",
  "role": "viewer",
  "guest": null
}
```

---

### `POST /lives/:id/leave`
Leaves stream and cleans viewer presence session.

- **Auth:** Required
- **Response (200 OK):**
```json
{
  "success": true,
  "viewers": 142
}
```

---

## 4. Realtime Chat, Likes & Pins

### `POST /lives/:id/like`
Increments stream like count (TikTok-style heart taps).

- **Auth:** Required
- **Response (200 OK):**
```json
{
  "likeCount": 2451,
  "liked": true,
  "alreadyLiked": true
}
```

---

### `POST /lives/:id/comments`
Sends a chat comment to the stream.

- **Auth:** Required
- **Request Body:**
```json
{
  "content": "Awesome performance! 🎸🔥"
}
```
- **Response (201 Created):**
```json
{
  "id": "c718b521-4821-4f11-9a72-881273619bb4",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "content": "Awesome performance! 🎸🔥",
  "isPinned": false,
  "createdAt": "2026-08-15T12:05:00.000Z",
  "user": {
    "id": "u-123",
    "username": "music_fan",
    "fullName": "Music Fan",
    "avatarUrl": "https://cdn.example.com/avatars/fan.jpg",
    "isVerified": false,
    "gifterLevel": 14
  }
}
```

---

### `GET /lives/:id/comments`
Lists stream comments (newest first, pinned first).

- **Auth:** Optional
- **Query Parameters:** `page=1`, `limit=50`, `mineOnly=false`
- **Response (200 OK):**
```json
{
  "pinnedComment": null,
  "data": [
    {
      "id": "c718b521-4821-4f11-9a72-881273619bb4",
      "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
      "content": "Awesome performance! 🎸🔥",
      "isPinned": false,
      "createdAt": "2026-08-15T12:05:00.000Z",
      "user": {
        "id": "u-123",
        "username": "music_fan",
        "avatarUrl": "https://cdn.example.com/avatars/fan.jpg",
        "gifterLevel": 14
      }
    }
  ],
  "meta": {
    "total": 1,
    "page": 1,
    "limit": 50,
    "totalPages": 1
  }
}
```

---

### `DELETE /lives/:id/comments/:commentId`
Soft-deletes a comment.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "success": true,
  "commentId": "c718b521-4821-4f11-9a72-881273619bb4"
}
```

---

### `POST /lives/:id/comments/:commentId/pin`
Pins comment to the viewer HUD.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "success": true,
  "commentId": "c718b521-4821-4f11-9a72-881273619bb4"
}
```

---

### `POST /lives/:id/comments/:commentId/unpin`
Unpins comment from the viewer HUD.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "success": true,
  "commentId": "c718b521-4821-4f11-9a72-881273619bb4"
}
```

---

## 5. Stream Viewer Moderation

### `POST /lives/:id/viewers/:userId/mute-chat`
Mutes a viewer from sending comments in this stream.

- **Auth:** Host or Live Moderator
- **Request Body:**
```json
{
  "reason": "Spamming links in chat"
}
```
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "userId": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
  "title": "Acoustic Night & Song Requests",
  "status": "LIVE"
}
```

---

### `POST /lives/:id/viewers/:userId/unmute-chat`
Unmutes viewer chat.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "status": "LIVE"
}
```

---

### `POST /lives/:id/viewers/:userId/ban`
Bans viewer from watching, commenting, or liking this live.

- **Auth:** Host or Live Moderator
- **Request Body:**
```json
{
  "reason": "Toxic behavior in stream"
}
```
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "status": "LIVE"
}
```

---

### `POST /lives/:id/viewers/:userId/unban`
Removes ban on viewer for this live.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "status": "LIVE"
}
```

---

## 6. Multi-Guest Stage & Co-Hosting

### `PATCH /lives/:id/settings`
Updates stage permissions and limits.

- **Auth:** Host
- **Request Body:**
```json
{
  "guestsEnabled": true,
  "guestRequestMode": "EVERYONE",
  "maxGuests": 8,
  "layout": "GRID",
  "allowGuestCamera": true,
  "moderatorsCanManageGuests": true
}
```
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "guestsEnabled": true,
  "guestRequestMode": "EVERYONE",
  "maxGuests": 8,
  "layout": "GRID",
  "allowGuestCamera": true,
  "moderatorsCanManageGuests": true
}
```

---

### `GET /lives/:id/guests`
Lists all current stage guests and requests.

- **Auth:** Optional
- **Response (200 OK):**
```json
{
  "data": [
    {
      "id": "g-1",
      "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
      "userId": "u-2",
      "role": "GUEST",
      "status": "ACTIVE",
      "mutedByHost": false,
      "cameraOffByHost": false,
      "joinedStageAt": "2026-08-15T12:10:00.000Z",
      "user": {
        "id": "u-2",
        "username": "guest_star",
        "fullName": "Guest Star",
        "avatarUrl": "https://cdn.example.com/avatars/guest.jpg",
        "isVerified": true
      }
    }
  ]
}
```

---

### `POST /lives/:id/guests/request`
Viewer requests a seat on stage.

- **Auth:** Viewer
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "role": "GUEST",
    "status": "REQUESTED",
    "createdAt": "2026-08-15T12:12:00.000Z"
  }
}
```

---

### `POST /lives/:id/guests/invite`
Host or Moderator invites a user to the stage.

- **Auth:** Host or Moderator (Only Host can set `CO_HOST`)
- **Request Body:**
```json
{
  "userId": "u-99",
  "role": "GUEST"
}
```
- **Response (201 Created):**
```json
{
  "guest": {
    "id": "g-3",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-99",
    "role": "GUEST",
    "status": "INVITED",
    "invitedById": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
    "createdAt": "2026-08-15T12:15:00.000Z"
  }
}
```

---

### `POST /lives/:id/guests/accept-invite`
Invitee accepts stage invitation and receives publish token.

- **Auth:** Invitee
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-3",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-99",
    "role": "GUEST",
    "status": "ACTIVE",
    "joinedStageAt": "2026-08-15T12:15:30.000Z"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "url": "wss://live.example.com",
  "role": "guest"
}
```

---

### `POST /lives/:id/guests/:userId/accept`
Host/Mod accepts a viewer's seat request.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "role": "GUEST",
    "status": "ACTIVE",
    "joinedStageAt": "2026-08-15T12:13:00.000Z"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "url": "wss://live.example.com",
  "role": "guest"
}
```

---

### `POST /lives/:id/guests/:userId/reject`
Host/Mod rejects a viewer's seat request.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "status": "REJECTED"
  }
}
```

---

### `POST /lives/:id/guests/leave`
Guest leaves stage.

- **Auth:** Stage Guest
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "status": "LEFT",
    "leftStageAt": "2026-08-15T12:20:00.000Z"
  }
}
```

---

### `POST /lives/:id/guests/:userId/kick`
Host/Mod removes guest from stage.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "status": "KICKED",
    "leftStageAt": "2026-08-15T12:21:00.000Z"
  }
}
```

---

### `POST /lives/:id/guests/:userId/mute`
Forces guest microphone off.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "mutedByHost": true
  }
}
```

---

### `POST /lives/:id/guests/:userId/unmute`
Allows guest microphone on.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "mutedByHost": false
  }
}
```

---

### `POST /lives/:id/guests/:userId/camera-off`
Forces guest video camera off.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "cameraOffByHost": true
  }
}
```

---

### `POST /lives/:id/guests/:userId/camera-on`
Allows guest video camera on.

- **Auth:** Host or Live Moderator
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "cameraOffByHost": false
  }
}
```

---

### `POST /lives/:id/guests/:userId/promote`
Promotes guest to `CO_HOST`.

- **Auth:** Host only
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "role": "CO_HOST"
  }
}
```

---

### `POST /lives/:id/guests/:userId/demote`
Demotes co-host back to `GUEST`.

- **Auth:** Host only
- **Response (200 OK):**
```json
{
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "role": "GUEST"
  }
}
```

---

### `POST /lives/:id/guests/token`
Refreshes LiveKit stage publisher token.

- **Auth:** Active Stage Guest
- **Response (200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "url": "wss://live.example.com",
  "role": "guest",
  "guest": {
    "id": "g-2",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-viewer-1",
    "role": "GUEST",
    "status": "ACTIVE"
  }
}
```

---

## 7. Stream Room Moderators

### `GET /lives/:id/moderators`
Lists assigned moderators for this stream.

- **Auth:** Required
- **Response (200 OK):**
```json
{
  "data": [
    {
      "userId": "u-55",
      "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
      "assignedAt": "2026-08-15T12:00:00.000Z",
      "user": {
        "id": "u-55",
        "username": "mod_alex",
        "avatarUrl": "https://cdn.example.com/avatars/alex.jpg"
      }
    }
  ]
}
```

---

### `POST /lives/:id/moderators`
Assigns a moderator to the live stream.

- **Auth:** Host only
- **Request Body:**
```json
{
  "userId": "u-55"
}
```
- **Response (201 Created):**
```json
{
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "userId": "u-55",
  "assignedAt": "2026-08-15T12:05:00.000Z"
}
```

---

### `DELETE /lives/:id/moderators/:userId`
Removes moderator assignment.

- **Auth:** Host only
- **Response (200 OK):**
```json
{
  "success": true
}
```

---

## 8. PK Battles & Speed Multipliers

### `GET /lives/:id/battle/opponents`
Suggests available broadcasting opponents for PK Battles.

- **Auth:** Host only
- **Query Parameters:** `limit=20`
- **Response (200 OK):**
```json
{
  "data": [
    {
      "id": "live-opp-1",
      "title": "Guitar Riffs & Fun",
      "viewers": 85,
      "user": {
        "id": "u-opp-1",
        "username": "john_guitar",
        "avatarUrl": "https://cdn.example.com/avatars/john.jpg",
        "isVerified": true
      },
      "category": {
        "id": "c-1",
        "name": "Music"
      }
    }
  ]
}
```

---

### `POST /lives/:id/battle/match`
1-Tap Auto Matching for PK Battle.

- **Auth:** Host
- **Request Body:**
```json
{
  "durationSeconds": 300
}
```
- **Response (201 Created):**
```json
{
  "id": "b-auto-1",
  "live1Id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "live2Id": "live-opp-1",
  "live1Score": 0,
  "live2Score": 0,
  "status": "ACTIVE",
  "phase": "BATTLE",
  "multiplier": 1.0,
  "multiplierEndsAt": null,
  "startTime": "2026-08-15T12:10:00.000Z",
  "endTime": "2026-08-15T12:15:00.000Z",
  "winnerLiveId": null
}
```

---

### `POST /lives/:id/battle`
Starts a PK Battle against a specific opponent.

- **Auth:** Host
- **Request Body:**
```json
{
  "opponentLiveId": "live-opp-1",
  "durationSeconds": 300
}
```
- **Response (201 Created):**
```json
{
  "id": "b-1",
  "live1Id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "live2Id": "live-opp-1",
  "live1Score": 0,
  "live2Score": 0,
  "status": "ACTIVE",
  "phase": "BATTLE",
  "multiplier": 1.0,
  "multiplierEndsAt": null,
  "startTime": "2026-08-15T12:10:00.000Z",
  "endTime": "2026-08-15T12:15:00.000Z",
  "winnerLiveId": null
}
```

---

### `GET /lives/:id/battle`
Gets current PK battle status.

- **Auth:** Optional
- **Response (200 OK):**
```json
{
  "battle": {
    "id": "b-1",
    "live1Id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "live2Id": "live-opp-1",
    "live1Score": 4200,
    "live2Score": 3800,
    "status": "ACTIVE",
    "phase": "BATTLE",
    "multiplier": 2.0,
    "multiplierEndsAt": "2026-08-15T12:13:30.000Z",
    "startTime": "2026-08-15T12:10:00.000Z",
    "endTime": "2026-08-15T12:15:00.000Z",
    "winnerLiveId": null
  }
}
```

---

### `POST /lives/:id/battle/multiplier`
Triggers 1.5x–5.0x speed challenge multiplier window.

- **Auth:** Competing Host
- **Request Body:**
```json
{
  "multiplier": 2.0,
  "durationSeconds": 30
}
```
- **Response (200 OK):**
```json
{
  "id": "b-1",
  "live1Id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "live2Id": "live-opp-1",
  "live1Score": 4200,
  "live2Score": 3800,
  "status": "ACTIVE",
  "multiplier": 2.0,
  "multiplierEndsAt": "2026-08-15T12:13:30.000Z"
}
```

---

### `POST /lives/:id/battle/:battleId/end`
Manually finishes the battle.

- **Auth:** Competing Host
- **Response (200 OK):**
```json
{
  "id": "b-1",
  "live1Id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "live2Id": "live-opp-1",
  "live1Score": 5400,
  "live2Score": 4100,
  "status": "FINISHED",
  "phase": "VICTORY_LAP",
  "winnerLiveId": "764be4ec-9e90-4828-98e9-4e78280fbe91"
}
```

---

## 9. Interactive Tools

### `POST /lives/:id/gift-goal`
Sets a coin progress target for the broadcast.

- **Auth:** Host
- **Request Body:**
```json
{
  "title": "Cosplay Dance Stream 🎉",
  "target": 10000
}
```
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "giftGoalTitle": "Cosplay Dance Stream 🎉",
  "giftGoalTarget": 10000,
  "giftGoalCurrent": 0
}
```

---

### `PATCH /lives/:id/chat-rules`
Configures chat mode, slow mode, and keyword filtering.

- **Auth:** Host
- **Request Body:**
```json
{
  "chatMode": "FOLLOWERS",
  "slowModeSeconds": 5,
  "blockedKeywords": ["badword", "spamlink"]
}
```
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "chatMode": "FOLLOWERS",
  "slowModeSeconds": 5,
  "blockedKeywords": ["badword", "spamlink"]
}
```

---

### `POST /lives/:id/polls`
Creates a live interactive poll.

- **Auth:** Host
- **Request Body:**
```json
{
  "question": "Which song should I play next?",
  "options": ["Acoustic Solo 🎸", "Pop Cover 🎤", "Jazz Chill 🎷"]
}
```
- **Response (201 Created):**
```json
{
  "id": "poll-1",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "question": "Which song should I play next?",
  "options": [
    { "text": "Acoustic Solo 🎸", "votes": 0, "percentage": 0 },
    { "text": "Pop Cover 🎤", "votes": 0, "percentage": 0 },
    { "text": "Jazz Chill 🎷", "votes": 0, "percentage": 0 }
  ],
  "totalVotes": 0,
  "status": "ACTIVE",
  "createdAt": "2026-08-15T12:00:00.000Z"
}
```

---

### `POST /lives/:id/polls/:pollId/vote`
Votes in active poll.

- **Auth:** Viewer
- **Request Body:**
```json
{
  "optionIndex": 0
}
```
- **Response (200 OK):**
```json
{
  "id": "poll-1",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "question": "Which song should I play next?",
  "options": [
    { "text": "Acoustic Solo 🎸", "votes": 1, "percentage": 100 },
    { "text": "Pop Cover 🎤", "votes": 0, "percentage": 0 },
    { "text": "Jazz Chill 🎷", "votes": 0, "percentage": 0 }
  ],
  "totalVotes": 1,
  "status": "ACTIVE"
}
```

---

### `POST /lives/:id/polls/:pollId/end`
Closes active poll.

- **Auth:** Host
- **Response (200 OK):**
```json
{
  "id": "poll-1",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "question": "Which song should I play next?",
  "status": "ENDED",
  "endedAt": "2026-08-15T12:15:00.000Z"
}
```

---

### `GET /lives/:id/polls/active`
Gets currently active poll.

- **Auth:** Optional
- **Response (200 OK):**
```json
{
  "id": "poll-1",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "question": "Which song should I play next?",
  "options": [
    { "text": "Acoustic Solo 🎸", "votes": 25, "percentage": 50 },
    { "text": "Pop Cover 🎤", "votes": 15, "percentage": 30 },
    { "text": "Jazz Chill 🎷", "votes": 10, "percentage": 20 }
  ],
  "totalVotes": 50,
  "status": "ACTIVE"
}
```

---

### `POST /lives/:id/qa`
Submits question to Q&A box.

- **Auth:** Viewer
- **Request Body:**
```json
{
  "question": "What tuning do you use on that acoustic guitar?"
}
```
- **Response (201 Created):**
```json
{
  "id": "qa-1",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "userId": "u-123",
  "question": "What tuning do you use on that acoustic guitar?",
  "isAnswered": false,
  "isPinned": false,
  "createdAt": "2026-08-15T12:05:00.000Z"
}
```

---

### `GET /lives/:id/qa`
Lists Q&A questions (pinned first).

- **Auth:** Optional
- **Response (200 OK):**
```json
[
  {
    "id": "qa-1",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "userId": "u-123",
    "question": "What tuning do you use on that acoustic guitar?",
    "isAnswered": false,
    "isPinned": true,
    "createdAt": "2026-08-15T12:05:00.000Z",
    "user": {
      "id": "u-123",
      "username": "music_fan",
      "avatarUrl": "https://cdn.example.com/avatars/fan.jpg"
    }
  }
]
```

---

### `POST /lives/:id/qa/:qaId/pin`
Pins Q&A question on screen.

- **Auth:** Host
- **Response (200 OK):**
```json
{
  "id": "qa-1",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "isPinned": true
}
```

---

### `POST /lives/:id/qa/:qaId/answer`
Marks question as answered.

- **Auth:** Host
- **Response (200 OK):**
```json
{
  "id": "qa-1",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "isAnswered": true
}
```

---

### `POST /lives/:id/treasure-boxes`
Drops a coin chest with countdown timer.

- **Auth:** Required (Creator)
- **Request Body:**
```json
{
  "totalCoins": 1000,
  "maxClaims": 20,
  "delaySeconds": 180
}
```
- **Response (201 Created):**
```json
{
  "id": "box-1",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "creatorId": "u-sponsor",
  "totalCoins": 1000,
  "remainingCoins": 1000,
  "maxClaims": 20,
  "claimedCount": 0,
  "unlocksAt": "2026-08-15T12:03:00.000Z",
  "status": "WAITING"
}
```

---

### `POST /lives/:id/treasure-boxes/:boxId/claim`
Claims randomized coins from opened chest.

- **Auth:** Viewer
- **Response (200 OK):**
```json
{
  "id": "claim-1",
  "boxId": "box-1",
  "userId": "u-viewer",
  "coinsWon": 48,
  "box": {
    "id": "box-1",
    "status": "OPEN",
    "claimedCount": 1,
    "maxClaims": 20,
    "remainingCoins": 952
  }
}
```

---

### `GET /lives/:id/treasure-boxes`
Lists active/waiting treasure boxes.

- **Auth:** Optional
- **Response (200 OK):**
```json
[
  {
    "id": "box-1",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "creatorId": "u-sponsor",
    "totalCoins": 1000,
    "remainingCoins": 952,
    "maxClaims": 20,
    "claimedCount": 1,
    "unlocksAt": "2026-08-15T12:03:00.000Z",
    "status": "OPEN",
    "creator": {
      "id": "u-sponsor",
      "username": "generous_fan",
      "avatarUrl": "https://cdn.example.com/avatars/sponsor.jpg"
    }
  }
]
```

---

## 10. Live Shopping & Auction Gallery

### `POST /lives/:id/auctions`
Creates an auction item bound to this live broadcast.

- **Auth:** Host (Seller-Verified)
- **Request Body:**
```json
{
  "itemName": "Signed Guitar Strap",
  "itemImageUrl": "https://cdn.example.com/items/strap.jpg",
  "targetPrice": 50.0,
  "startingPrice": 5.0
}
```
- **Response (201 Created):**
```json
{
  "id": "auc-1",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "itemName": "Signed Guitar Strap",
  "itemImageUrl": "https://cdn.example.com/items/strap.jpg",
  "currentPrice": 5.0,
  "targetPrice": 50.0,
  "startingPrice": 5.0,
  "status": "ACTIVE",
  "pinOrder": 0,
  "isPinned": false,
  "createdAt": "2026-08-15T12:00:00.000Z"
}
```

---

### `GET /lives/:id/gallery`
Retrieves shop items (pinned first, then by `pinOrder`).

- **Auth:** Optional
- **Response (200 OK):**
```json
[
  {
    "id": "auc-1",
    "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
    "itemName": "Signed Guitar Strap",
    "itemImageUrl": "https://cdn.example.com/items/strap.jpg",
    "currentPrice": 45.0,
    "targetPrice": 50.0,
    "status": "ACTIVE",
    "isPinned": true,
    "pinOrder": 1
  }
]
```

---

### `GET /lives/:id/auctions/active`
Retrieves active auctions for stream HUD.

- **Auth:** Optional
- **Response (200 OK):**
```json
[
  {
    "id": "auc-1",
    "itemName": "Signed Guitar Strap",
    "currentPrice": 45.0,
    "status": "ACTIVE"
  }
]
```

---

### `GET /lives/:id/auctions`
Paginated auctions list on stream (`?status=ACTIVE|COMPLETED|CANCELLED|ALL`).

- **Auth:** Optional
- **Query Parameters:** `page=1`, `limit=20`, `status=ACTIVE`
- **Response (200 OK):**
```json
{
  "data": [
    {
      "id": "auc-1",
      "itemName": "Signed Guitar Strap",
      "currentPrice": 45.0,
      "status": "ACTIVE"
    }
  ],
  "meta": {
    "total": 1,
    "page": 1,
    "limit": 20,
    "totalPages": 1
  }
}
```

---

### `PATCH /lives/:id/auctions/:auctionId/pin`
Pins an auction item to the stream showcase banner.

- **Auth:** Host
- **Request Body:**
```json
{
  "pinned": true
}
```
- **Response (200 OK):**
```json
{
  "id": "auc-1",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "isPinned": true,
  "pinnedAt": "2026-08-15T12:10:00.000Z"
}
```

---

### `PATCH /lives/:id/auctions/reorder`
Reorders showcase gallery item positions.

- **Auth:** Host
- **Request Body:**
```json
{
  "auctionIds": ["auc-1", "auc-2"]
}
```
- **Response (200 OK):**
```json
[
  { "id": "auc-1", "pinOrder": 0 },
  { "id": "auc-2", "pinOrder": 1 }
]
```

---

## 11. Hourly Leaderboards, Leagues & Fan Clubs

### `GET /lives/leaderboard/hourly`
Global hourly host ranking for the current UTC hour.

- **Auth:** Optional
- **Query Parameters:** `limit=20`
- **Response (200 OK):**
```json
{
  "windowStartsAt": "2026-08-15T12:00:00.000Z",
  "windowEndsAt": "2026-08-15T13:00:00.000Z",
  "data": [
    {
      "rank": 1,
      "score": 4520,
      "hourlyCoins": 4200,
      "isPopular": true,
      "popularReason": "hourly_rank",
      "live": {
        "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
        "title": "Acoustic Night & Song Requests",
        "viewers": 142,
        "user": {
          "id": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
          "username": "sarah_singer",
          "avatarUrl": "https://cdn.example.com/avatars/sarah.jpg",
          "hostLeagueTier": "B2"
        }
      }
    }
  ]
}
```

---

### `GET /lives/:id/leaderboard/hourly`
This stream's rank and score in current hour.

- **Auth:** Optional
- **Response (200 OK):**
```json
{
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "rank": 3,
  "score": 2840,
  "hourlyCoins": 2500,
  "isPopular": true,
  "popularReason": "hourly_rank"
}
```

---

### `GET /lives/:id/leaderboard/gifters`
Top contributors for this stream session or current hour.

- **Auth:** Optional
- **Query Parameters:** `limit=10`, `window=session` (`session` | `hour`)
- **Response (200 OK):**
```json
{
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "window": "session",
  "data": [
    {
      "rank": 1,
      "totalCoins": 12500,
      "user": {
        "id": "u-1",
        "username": "top_fan",
        "avatarUrl": "https://cdn.example.com/avatars/topfan.jpg",
        "isVerified": true,
        "gifterLevel": 32
      }
    }
  ]
}
```

---

### `GET /lives/leagues`
Retrieves tier definitions (D5 to S).

- **Auth:** None
- **Response (200 OK):**
```json
{
  "tiers": [
    { "tier": "S", "minCoins": 5000000, "minFollowers": 200000 },
    { "tier": "A1", "minCoins": 2000000, "minFollowers": 100000 },
    { "tier": "B2", "minCoins": 300000, "minFollowers": 25000 },
    { "tier": "D5", "minCoins": 0, "minFollowers": 0 }
  ]
}
```

---

### `GET /lives/host-league/:userId`
Retrieves creator host league tier and progress toward next tier.

- **Auth:** Optional
- **Response (200 OK):**
```json
{
  "userId": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
  "username": "sarah_singer",
  "hostLeagueTier": "B2",
  "totalLiveEarnedCoins": 350000,
  "followerCount": 42000,
  "nextTier": "B1",
  "progressPercentage": 65
}
```

---

### `GET /creators/:creatorId/fan-club`
Gets creator fan club subscription details.

- **Auth:** Optional
- **Response (200 OK):**
```json
{
  "enabled": true,
  "name": "Sarah's VIPs",
  "isMember": true
}
```

---

### `POST /creators/:creatorId/fan-club/subscribe`
Subscribes to creator fan club.

- **Auth:** Required
- **Response (201 Created):**
```json
{
  "id": "sub-1",
  "subscriberId": "u-fan",
  "creatorId": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
  "status": "ACTIVE",
  "startDate": "2026-08-15T12:00:00.000Z"
}
```

---

### `DELETE /creators/:creatorId/fan-club/subscribe`
Cancels fan club subscription.

- **Auth:** Required
- **Response (200 OK):**
```json
{
  "success": true
}
```

---

## 12. Post-Live Analytics Summary

### `GET /lives/:id/summary`
Host post-stream summary analytics recap.

- **Auth:** Host only
- **Response (200 OK):**
```json
{
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "title": "Acoustic Night & Song Requests",
  "coverUrl": "https://cdn.example.com/covers/stream.jpg",
  "startedAt": "2026-08-15T10:00:00.000Z",
  "endedAt": "2026-08-15T11:45:00.000Z",
  "durationSeconds": 6300,
  "peakViewers": 540,
  "totalViewerSessions": 2840,
  "totalLikes": 38200,
  "totalComments": 1420,
  "totalEarnedCoins": 85000,
  "topGifters": [
    {
      "user": {
        "id": "u-1",
        "username": "alex_music",
        "fullName": "Alex Smith",
        "avatarUrl": "https://cdn.example.com/avatars/alex.jpg",
        "isVerified": true,
        "gifterLevel": 32
      },
      "totalCoins": 42000
    }
  ]
}
```

---

## 13. Admin Management & Moderation

### `GET /lives/admin/all`
Paginated stream management queue for ops dashboard.

- **Auth:** `lives.admin.read`
- **Query Parameters:** `page=1`, `limit=20`, `status=LIVE`, `search=sarah`, `userId=uuid`
- **Response (200 OK):**
```json
{
  "data": [
    {
      "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
      "title": "Acoustic Night & Song Requests",
      "status": "LIVE",
      "viewers": 142,
      "likeCount": 2450,
      "totalEarnedCoins": 12500,
      "user": {
        "id": "d748f3b1-e24c-473d-82d2-8b65672abcb7",
        "username": "sarah_singer",
        "avatarUrl": "https://cdn.example.com/avatars/sarah.jpg"
      }
    }
  ],
  "meta": {
    "total": 1,
    "page": 1,
    "limit": 20,
    "totalPages": 1
  }
}
```

---

### `POST /lives/admin/:id/end`
Admin force end (soft teardown).

- **Auth:** `lives.admin.moderate`
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "status": "ENDED",
  "endedAt": "2026-08-15T12:30:00.000Z"
}
```

---

### `POST /lives/admin/:id/ban`
Admin ban stream with violation reason.

- **Auth:** `lives.admin.moderate`
- **Request Body:**
```json
{
  "reason": "Violated copyright and stream safety terms"
}
```
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "status": "BANNED",
  "banReason": "Violated copyright and stream safety terms",
  "endedAt": "2026-08-15T12:30:00.000Z"
}
```

---

### `POST /lives/admin/:id/boost`
Boosts stream ranking in Discovery feed.

- **Auth:** `lives.admin.moderate`
- **Request Body:**
```json
{
  "durationMinutes": 120
}
```
- **Response (200 OK):**
```json
{
  "id": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "feedBoostUntil": "2026-08-15T14:30:00.000Z"
}
```

---

### `POST /lives/admin/:id/guests/:userId/kick`
Admin force kick guest from stage.

- **Auth:** `lives.admin.moderate`
- **Response (200 OK):**
```json
{
  "id": "g-2",
  "liveId": "764be4ec-9e90-4828-98e9-4e78280fbe91",
  "userId": "u-viewer-1",
  "status": "KICKED",
  "leftStageAt": "2026-08-15T12:30:00.000Z"
}
```

---

## 14. Infrastructure Webhooks

### `POST /lives/webhooks/livekit`
Signed Webhook listener for LiveKit SFU server events.

- **Auth:** LiveKit Webhook Signature (`Authorization` or `Authorize` header)
- **Request Body:**
```json
{
  "event": "participant_left",
  "room": {
    "name": "live_764be4ec-9e90-4828-98e9-4e78280fbe91"
  },
  "participant": {
    "identity": "d748f3b1-e24c-473d-82d2-8b65672abcb7"
  }
}
```
- **Response (200 OK):**
```json
{
  "ok": true
}
```
