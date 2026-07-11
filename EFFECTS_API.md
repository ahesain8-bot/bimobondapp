# Camera Effects API

Complete reference for **AR effects** and **screen overlays** in the camera studio module.

**Base path:** `/camera-studio`  
**Auth:** Public read endpoints need no token. Admin endpoints require `Authorization: Bearer <firebase_id_token>` and role `ADMIN` or `MODERATOR` (create/update/delete usually `ADMIN` only).

---

## Table of contents

1. [Concepts](#concepts)
2. [Face detection & placement](#face-detection--placement)
3. [Public endpoints](#public-endpoints)
4. [Admin — effect categories](#admin--effect-categories)
5. [Admin — effects CRUD](#admin--effects-crud)
6. [Posts integration](#posts-integration)
7. [Enums & field reference](#enums--field-reference)

---

## Concepts

| Term | Description |
|------|-------------|
| **Effect** | A camera overlay — face AR (emoji/sticker on face) or full-screen animation |
| **Effect category** | A tab in the effects strip (e.g. `trending`) listing effects in order |
| **Slug** | Stable client id (`crown`, `sunglasses`, `sparkle`) — stored on posts as `effectSlug` |
| **Placement** | How the client positions the effect using face geometry (`anchorType`, offsets, etc.) |
| **Catalog version** | String timestamp; apps refetch when it changes after admin publish |

### Effect types

| API value (public) | Admin body value | Meaning |
|--------------------|------------------|---------|
| `face_ar` | `FACE_AR` | Anchored to face detection or face box |
| `screen_overlay` | `SCREEN_OVERLAY` | Full-screen effect (`sparkle`, `neon`, `glitch`) |

---

## Face detection & placement

The **backend stores placement metadata**. It does **not** run face detection. The mobile app runs on-device TFLite detection and uses this metadata to draw effects.

### What the client gets from detection

When `requiresFaceDetection` is `true`, the client should have:

1. **Face bounding box** — rectangle in image/canvas pixels (`left`, `top`, `right`, `bottom`). Always available. Not stored in `anchorLandmarks`.
2. **Landmarks** — optional keypoints for fine placement (see [Landmarks](#landmarks)).

### Preferred placement: full face

Use **`on_face`** or **`cover_face`** so effects align to the **whole face box**, not only eyes or nose.

| `anchorType` | Uses face box | Uses landmarks | Typical use |
|--------------|---------------|----------------|-------------|
| `on_face` | Yes | No | Sunglasses, hearts — centered on face, size = face width × `scaleFactor` |
| `cover_face` | Yes | No | Dog mask, PNG face filters — stretch to cover the box |
| `above_face` | Yes | No | Crown above head |
| `dual_above_face` | Yes | No | Bunny ears (two mirrored items) |
| `between_landmarks` | No | Yes (2+) | Legacy: between two points |
| `on_landmark` | No | Yes (1+) | Single keypoint |
| `on_landmarks` | No | Yes (1+) | One draw per keypoint |
| `screen` | No | No | Sparkle, neon, glitch |

### Placement fields (on every effect in catalog & admin)

| Field | Type | Description |
|-------|------|-------------|
| `anchorType` | string | How to position (snake_case in responses) |
| `anchorLandmarks` | string[] \| omitted | Landmark keys when anchor needs points |
| `scaleFactor` | number \| omitted | Size multiplier (meaning depends on `anchorType`) |
| `offsetX` | number \| omitted | Horizontal shift vs face box width (−1 … 1) |
| `offsetY` | number \| omitted | Vertical shift vs face box height (−1 … 1) |
| `landmarkSize` | number \| omitted | Size vs face width for `on_landmark` / `on_landmarks` |
| `fallbackAnchorType` | string \| omitted | Used when landmarks are missing |
| `fallbackOffsetY` | number \| omitted | Fallback vertical offset |
| `fallbackScaleFactor` | number \| omitted | Fallback size multiplier |

If placement fields are omitted on **create**, the server merges **defaults by `slug`** (see `GET /camera-studio/effect-placement/schema` → `defaultsBySlug`).

### Landmarks

These are the **only** valid values for `anchorLandmarks` in the API:

| API key | TFLite model key | Description |
|---------|------------------|-------------|
| `leftEye` | `leftEye` | Left eye |
| `rightEye` | `rightEye` | Right eye |
| `noseBase` | `noseTip` | Nose tip |
| `mouth` | `mouth` | Mouth center |
| `leftEar` | `leftEyeTragion` | Left ear / tragion |
| `rightEar` | `rightEyeTragion` | Right ear / tragion |

There are **no other landmark keys** in the API. The face **bounding box** is separate geometry (not a landmark).

> **Client note:** The TFLite front model exposes exactly these six keypoints. The mobile app may not populate all six yet; `on_face` / `cover_face` only need the bounding box.

### Offset & scale semantics

- **`on_face`:** Center = face box center + offsets. Draw size ≈ `face.width × scaleFactor × 0.45` (emoji) or proportional for `assetUrl`.
- **`cover_face`:** Rect = face box inflated by `scaleFactor` (1.0 = exact fit).
- **`above_face`:** Center X = face center; Y = `face.top + face.height × offsetY`.
- **`between_landmarks`:** Center = midpoint of first two landmarks; width = eye distance × `scaleFactor`.

---

## Public endpoints

### `GET /camera-studio/catalog`

Active filters **and** effects for the camera UI. No auth.

#### Response `200 OK` (effects portion)

```json
{
  "version": "2026-07-09T12:00:00.000Z",
  "effectCategories": [
    {
      "slug": "trending",
      "labelKey": "cameraCategoryTrending",
      "sortOrder": 0,
      "effects": [
        {
          "id": "660e8400-e29b-41d4-a716-446655440000",
          "slug": "none",
          "effectType": "face_ar",
          "emoji": "○",
          "previewColorHex": "#E8D5C4",
          "labelKey": "cameraFilterOriginal",
          "requiresFaceDetection": false,
          "isScreenEffect": false,
          "sortOrder": 0
        },
        {
          "id": "660e8400-e29b-41d4-a716-446655440001",
          "slug": "sunglasses",
          "effectType": "face_ar",
          "emoji": "😎",
          "previewColorHex": "#2F4F4F",
          "labelKey": "cameraEffectSunglasses",
          "requiresFaceDetection": true,
          "isScreenEffect": false,
          "anchorType": "on_face",
          "scaleFactor": 1,
          "offsetY": 0.12,
          "fallbackAnchorType": "on_face",
          "fallbackOffsetY": 0.12,
          "fallbackScaleFactor": 1,
          "sortOrder": 3
        },
        {
          "id": "660e8400-e29b-41d4-a716-446655440002",
          "slug": "sparkle",
          "effectType": "screen_overlay",
          "emoji": "✨",
          "previewColorHex": "#FFD700",
          "labelKey": "cameraEffectSparkle",
          "requiresFaceDetection": false,
          "isScreenEffect": true,
          "anchorType": "screen",
          "sortOrder": 6
        }
      ]
    }
  ]
}
```

#### Effect object fields (public)

| Field | Type | Description |
|-------|------|-------------|
| `id` | uuid | Database id |
| `slug` | string | Client effect id |
| `effectType` | string | `face_ar` \| `screen_overlay` |
| `emoji` | string? | Strip icon + emoji overlay |
| `assetUrl` | string? | PNG/sticker URL |
| `previewColorHex` | string | Chip color `#RRGGBB` |
| `labelKey` | string | i18n key |
| `requiresFaceDetection` | boolean | Needs face box / landmarks |
| `isScreenEffect` | boolean | Full-screen overlay |
| `anchorType` | string? | Placement mode (snake_case) |
| `anchorLandmarks` | string[]? | Landmark keys |
| `scaleFactor` | number? | Size multiplier |
| `offsetX` | number? | Horizontal offset |
| `offsetY` | number? | Vertical offset |
| `landmarkSize` | number? | Landmark-relative size |
| `fallbackAnchorType` | string? | Fallback placement |
| `fallbackOffsetY` | number? | Fallback Y offset |
| `fallbackScaleFactor` | number? | Fallback scale |
| `sortOrder` | number | Order within category |

---

### `GET /camera-studio/effect-placement/schema`

Metadata for admin dashboards and client implementers. No auth.

#### Response `200 OK`

```json
{
  "version": 2,
  "faceDetection": {
    "description": "When requiresFaceDetection is true, the client always receives a face bounding box plus all landmarks below.",
    "boundingBox": {
      "fields": ["left", "top", "right", "bottom"],
      "description": "Face rectangle in image/canvas pixels."
    },
    "landmarks": [
      { "key": "leftEye", "label": "Left eye", "description": "Left eye keypoint." },
      { "key": "rightEye", "label": "Right eye", "description": "Right eye keypoint." },
      { "key": "noseBase", "label": "Nose", "description": "Nose tip keypoint." },
      { "key": "mouth", "label": "Mouth", "description": "Mouth center keypoint." },
      { "key": "leftEar", "label": "Left ear", "description": "Left ear / tragion keypoint." },
      { "key": "rightEar", "label": "Right ear", "description": "Right ear / tragion keypoint." }
    ]
  },
  "anchorTypes": [
    {
      "key": "on_face",
      "label": "On face",
      "description": "Center on the face bounding box...",
      "requiresLandmarks": false,
      "usesFaceBox": true
    }
  ],
  "landmarks": [],
  "defaultsBySlug": {
    "sunglasses": {
      "anchorType": "on_face",
      "scaleFactor": 1,
      "offsetY": 0.12,
      "fallbackAnchorType": "on_face",
      "fallbackOffsetY": 0.12,
      "fallbackScaleFactor": 1
    }
  }
}
```

---

## Admin — effect categories

| Method | Path | Role | Description |
|--------|------|------|-------------|
| `GET` | `/camera-studio/admin/effect-categories` | Admin, Mod | List tabs |
| `POST` | `/camera-studio/admin/effect-categories` | Admin | Create tab |
| `PATCH` | `/camera-studio/admin/effect-categories/reorder` | Admin | Reorder tabs |
| `PATCH` | `/camera-studio/admin/effect-categories/:id` | Admin | Update tab |
| `PUT` | `/camera-studio/admin/effect-categories/:id/effects` | Admin | Set effects in tab |
| `DELETE` | `/camera-studio/admin/effect-categories/:id` | Admin | Delete tab |

### Create category — `POST /camera-studio/admin/effect-categories`

#### Request body

```json
{
  "slug": "trending",
  "labelKey": "cameraCategoryTrending",
  "sortOrder": 0,
  "isActive": true
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `slug` | string | Yes | Max 50 chars, unique |
| `labelKey` | string | Yes | i18n key, max 100 |
| `sortOrder` | number | No | Tab order (default `0`) |
| `isActive` | boolean | No | Visible in app (default `true`) |

#### Response `201` — category object

```json
{
  "id": "cat-uuid",
  "slug": "trending",
  "labelKey": "cameraCategoryTrending",
  "sortOrder": 0,
  "isActive": true,
  "effects": [],
  "createdAt": "2026-07-09T10:00:00.000Z",
  "updatedAt": "2026-07-09T10:00:00.000Z"
}
```

### Update category — `PATCH /camera-studio/admin/effect-categories/:id`

Partial body — any fields from create.

### Reorder categories — `PATCH /camera-studio/admin/effect-categories/reorder`

#### Request body

```json
{
  "items": [
    { "id": "cat-uuid-1", "sortOrder": 0 },
    { "id": "cat-uuid-2", "sortOrder": 1 }
  ]
}
```

#### Response `200` — updated category list

### Set category effects — `PUT /camera-studio/admin/effect-categories/:id/effects`

Replaces the full ordered list of effects in a tab.

#### Request body

```json
{
  "effects": [
    { "effectId": "effect-uuid-none", "sortOrder": 0 },
    { "effectId": "effect-uuid-crown", "sortOrder": 1 },
    { "effectId": "effect-uuid-sunglasses", "sortOrder": 2 }
  ]
}
```

#### Response `200` — category with nested effects (admin shape)

### Delete category — `DELETE /camera-studio/admin/effect-categories/:id`

#### Response `200`

```json
{ "deleted": true }
```

---

## Admin — effects CRUD

| Method | Path | Role | Description |
|--------|------|------|-------------|
| `GET` | `/camera-studio/admin/effects` | Admin, Mod | List all effects |
| `POST` | `/camera-studio/admin/effects` | Admin | Create effect |
| `GET` | `/camera-studio/admin/effects/:id` | Admin, Mod | Get one |
| `PATCH` | `/camera-studio/admin/effects/:id` | Admin | Update (partial) |
| `PATCH` | `/camera-studio/admin/effects/:id/activate` | Admin, Mod | Set `isActive: true` |
| `PATCH` | `/camera-studio/admin/effects/:id/deactivate` | Admin, Mod | Set `isActive: false` |
| `DELETE` | `/camera-studio/admin/effects/:id` | Admin | Delete |

Related admin (full studio):

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/camera-studio/admin/catalog` | Full catalog incl. inactive effects |
| `POST` | `/camera-studio/admin/catalog/publish` | Bump catalog `version` for apps |
| `POST` | `/camera-studio/admin/seed` | Re-seed default effects |

---

### `GET /camera-studio/admin/effects`

#### Response `200 OK`

```json
[
  {
    "id": "effect-uuid",
    "slug": "crown",
    "effectType": "face_ar",
    "emoji": "👑",
    "previewColorHex": "#FFD700",
    "labelKey": "cameraEffectCrown",
    "requiresFaceDetection": true,
    "isScreenEffect": false,
    "anchorType": "above_face",
    "scaleFactor": 1.1,
    "offsetY": -0.55,
    "isActive": true,
    "sortOrder": 1,
    "createdAt": "2026-07-02T00:00:00.000Z",
    "updatedAt": "2026-07-09T10:00:00.000Z"
  }
]
```

Admin effect objects include all public placement fields plus `isActive`, `createdAt`, `updatedAt`.

---

### `POST /camera-studio/admin/effects`

#### Request body — full face AR (`on_face`)

```json
{
  "slug": "sunglasses",
  "effectType": "FACE_AR",
  "emoji": "😎",
  "previewColorHex": "#2F4F4F",
  "labelKey": "cameraEffectSunglasses",
  "requiresFaceDetection": true,
  "isScreenEffect": false,
  "anchorType": "on_face",
  "scaleFactor": 1.0,
  "offsetY": 0.12,
  "fallbackAnchorType": "on_face",
  "fallbackOffsetY": 0.12,
  "fallbackScaleFactor": 1.0,
  "sortOrder": 3,
  "isActive": true
}
```

#### Request body — face mask (`cover_face` + asset)

```json
{
  "slug": "dog-mask",
  "effectType": "FACE_AR",
  "assetUrl": "https://cdn.example.com/effects/dog-face.png",
  "previewColorHex": "#D2691E",
  "labelKey": "cameraEffectDogMask",
  "requiresFaceDetection": true,
  "isScreenEffect": false,
  "anchorType": "cover_face",
  "scaleFactor": 1.0,
  "sortOrder": 4,
  "isActive": true
}
```

#### Request body — screen overlay

```json
{
  "slug": "sparkle",
  "effectType": "SCREEN_OVERLAY",
  "emoji": "✨",
  "previewColorHex": "#FFD700",
  "labelKey": "cameraEffectSparkle",
  "requiresFaceDetection": false,
  "isScreenEffect": true,
  "anchorType": "screen",
  "sortOrder": 6,
  "isActive": true
}
```

#### Request body — optional landmark placement

```json
{
  "slug": "cheek-hearts",
  "effectType": "FACE_AR",
  "emoji": "❤️",
  "previewColorHex": "#FF69B4",
  "labelKey": "cameraEffectCheekHearts",
  "requiresFaceDetection": true,
  "anchorType": "on_landmarks",
  "anchorLandmarks": ["leftEar", "rightEar"],
  "landmarkSize": 0.2,
  "sortOrder": 10,
  "isActive": true
}
```

#### Create / update field reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `slug` | string | Yes* | Unique client id, max 50 |
| `effectType` | enum | Yes* | `FACE_AR` or `SCREEN_OVERLAY` |
| `emoji` | string | No | Max 16 chars |
| `assetUrl` | url | No | Sticker / PNG |
| `previewColorHex` | string | Yes* | `#RRGGBB` |
| `labelKey` | string | Yes* | i18n key |
| `requiresFaceDetection` | boolean | No | Default `false` |
| `isScreenEffect` | boolean | No | Default `false` |
| `anchorType` | enum | No | See [anchor types](#preferred-placement-full-face) |
| `anchorLandmarks` | string[] | No | Six landmark keys only |
| `scaleFactor` | number | No | Placement size |
| `offsetX` | number | No | −1 … 1 |
| `offsetY` | number | No | −1 … 1 |
| `landmarkSize` | number | No | For `on_landmark(s)` |
| `fallbackAnchorType` | enum | No | When landmarks missing |
| `fallbackOffsetY` | number | No | |
| `fallbackScaleFactor` | number | No | |
| `sortOrder` | number | No | Global fallback order |
| `isActive` | boolean | No | Default `true` |

\*Required on create; optional on `PATCH`.

**Admin enum format:** Request bodies accept snake_case (`on_face`) or SCREAMING_SNAKE (`ON_FACE`). Responses use snake_case.

#### Response `201 Created`

Same shape as a single item from `GET /admin/effects`.

#### Errors

| Status | Reason |
|--------|--------|
| `400` | Validation failed (invalid `anchorType`, unknown landmark, etc.) |
| `409` | Duplicate `slug` |

---

### `GET /camera-studio/admin/effects/:id`

#### Response `200` — single effect (admin shape)

#### Response `404` — `{ "message": "Effect not found", "statusCode": 404 }`

---

### `PATCH /camera-studio/admin/effects/:id`

Partial update — any create fields. Placement is re-resolved (slug defaults merged).

#### Example — switch to cover face

```json
{
  "anchorType": "cover_face",
  "scaleFactor": 1.05,
  "anchorLandmarks": null
}
```

#### Response `200` — updated effect

---

### `PATCH /camera-studio/admin/effects/:id/activate`

No body.

#### Response `200` — effect with `isActive: true`

### `PATCH /camera-studio/admin/effects/:id/deactivate`

No body.

#### Response `200` — effect with `isActive: false`

---

### `DELETE /camera-studio/admin/effects/:id`

#### Response `200`

```json
{ "deleted": true }
```

---

## Posts integration

When publishing from the camera, send the effect slug on **`POST /posts`**:

```json
{
  "type": "VIDEO",
  "videoUrl": "/uploads/media/video.mp4",
  "effectSlug": "sunglasses",
  "filterName": "Juno",
  "filterCategory": "trending",
  "beautyEnabled": false
}
```

| Field | Description |
|-------|-------------|
| `effectSlug` | Effect `slug` from catalog (`none` = no effect) |

Post responses echo `effectSlug` when set.

---

## Enums & field reference

### Built-in effect slugs (seed defaults)

| Slug | Type | Default `anchorType` |
|------|------|----------------------|
| `none` | face_ar | — |
| `crown` | face_ar | `above_face` |
| `bunny` | face_ar | `dual_above_face` |
| `sunglasses` | face_ar | `on_face` |
| `dog` | face_ar | `cover_face` |
| `hearts` | face_ar | `on_face` |
| `sparkle` | screen_overlay | `screen` |
| `neon` | screen_overlay | `screen` |
| `glitch` | screen_overlay | `screen` |

### `anchorType` values (request & response)

| Request (either form) | Response (snake_case) |
|-----------------------|------------------------|
| `ON_FACE` / `on_face` | `on_face` |
| `COVER_FACE` / `cover_face` | `cover_face` |
| `ABOVE_FACE` / `above_face` | `above_face` |
| `BETWEEN_LANDMARKS` / `between_landmarks` | `between_landmarks` |
| `ON_LANDMARK` / `on_landmark` | `on_landmark` |
| `ON_LANDMARKS` / `on_landmarks` | `on_landmarks` |
| `DUAL_ABOVE_FACE` / `dual_above_face` | `dual_above_face` |
| `SCREEN` / `screen` | `screen` |

### Workflow checklist (admin)

1. `POST /admin/effects` — create effects with placement
2. `PUT /admin/effect-categories/:id/effects` — order effects in tabs
3. `POST /admin/catalog/publish` — bump version so apps refetch
4. Verify `GET /catalog` shows new effects and placement fields

---

## See also

- [Camera Studio README](./README.md) — filters + full studio overview
- Source: `src/camera-studio/` — DTOs, placement constants, seed data
