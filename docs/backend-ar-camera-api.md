# Bimobond AR Camera — Backend API Specification

This document defines the two REST endpoints the mobile app consumes for **color filters** (Filters panel) and **face effects** (bottom sticker carousel).

**Source-of-truth Dart models (include in handoff):**

| Feature | Model file |
|---|---|
| Color filters | `lib/app/ar_camera/ar_color_filter_catalog_model.dart` |
| Face effects | `lib/app/ar_camera/ar_effect_catalog_model.dart` |

Both models include inline comments, JSON parsing, validation helpers, and **bundled seed data** matching the current app release.

---

## Overview

| API | UI location | What it controls |
|---|---|---|
| `GET /camera-studio/color-filters` | Filters panel (Beauty) | Beauty presets (smooth/whiten/blush…) — **no LUT / no `.cube`** |
| `GET /camera-studio/ar-effects` | Bottom carousel | Stickers + face warp (glasses, dog, big eyes…) |

> **LUT removed (app):** static `assets/luts/`, PNG LUT bake, and `renderType: "lut"` are no longer used. Dashboard should send beauty params only — see `ar_color_filter_catalog_model.dart`. Sections below that mention LUT are historical reference only.

Responses may be wrapped:

```json
{ "data": { "version": "…", … } }
```

The app parser unwraps `data` automatically.

**Cache busting:** bump the top-level `version` string whenever catalog content changes.

**Critical:** do **not** rename existing `id` values without coordinating an app release — native Kotlin maps effects/filters by these slugs.

---

# 1. Color Filters API

## Endpoint

```
GET /camera-studio/color-filters
```

## Response shape

```json
{
  "version": "2026-07-20T01",
  "colorFilterCategories": [
    {
      "id": "portrait",
      "label": "Portrait",
      "sortOrder": 0,
      "filters": [ … ]
    }
  ]
}
```

## How to add a filter (dashboard workflow)

1. Pick or create a **category**: `portrait` | `life` | `retro` | `film`
2. Choose **renderType**: `matrix` or `lut` (see below)
3. Set **id** (unique snake_case slug)
4. Set **label**, **sortOrder**, **emoji**, **thumbnailUrl**, **previewColorHex**
5. Fill type-specific fields
6. Publish and bump **version**

---

## Render type A: `matrix`

**Use for:** Portrait, Life, Retro looks (Pure, Warm, Vintage, B&W, etc.)

| Field | Required | Description |
|---|---|---|
| `renderType` | yes | `"matrix"` |
| `colorMatrix` | yes | Exactly **20 numbers** (4×5 ColorMatrix, row-major) |
| `adjustments` | no | Dashboard sliders −100…100; backend may convert to matrix |

**Example:**

```json
{
  "id": "whitening",
  "label": "Pure",
  "renderType": "matrix",
  "sortOrder": 0,
  "emoji": "🤍",
  "previewColorHex": "#F0E0D0",
  "thumbnailUrl": "https://cdn.example.com/thumbs/pure.jpg",
  "colorMatrix": [
    1.12, 0.02, 0.02, 0, 12,
    0.02, 1.10, 0.02, 0, 10,
    0.02, 0.02, 1.08, 0, 8,
    0, 0, 0, 1, 0
  ],
  "adjustments": {
    "brightness": 8,
    "contrast": 6,
    "saturation": 4,
    "warmth": 10,
    "tint": 0,
    "exposure": 5,
    "fade": 0
  }
}
```

**adjustments field reference** (all integers, −100…100, 0 = neutral):

| Key | Meaning |
|---|---|
| brightness | Lighter / darker (additive) |
| contrast | Flatter / punchier |
| saturation | Color intensity (−100 ≈ B&W) |
| warmth | + warm (yellow/red), − cool (blue) |
| tint | + magenta, − green |
| exposure | Overall gain |
| fade | + matte/lifted blacks |

---

## Render type B: `lut`

**Use for:** Film pack, City Film, professional 3D LUT grades

| Field | Required | Description |
|---|---|---|
| `renderType` | yes | `"lut"` |
| `lutUrl` | yes (online) | HTTPS URL to 512×512 LUT PNG on CDN |
| `lutAsset` | no | Bundled filename for offline, e.g. `going_for_a_walk.png` |

**Example:**

```json
{
  "id": "going_for_a_walk",
  "label": "Going for a Walk",
  "renderType": "lut",
  "sortOrder": 0,
  "emoji": "🚶",
  "previewColorHex": "#A8B89A",
  "thumbnailUrl": "https://cdn.example.com/thumbs/going_for_a_walk.jpg",
  "lutUrl": "https://cdn.example.com/luts/going_for_a_walk.png",
  "lutAsset": "going_for_a_walk.png"
}
```

### LUT upload pipeline (backend)

```
Designer uploads .cube (Lightroom / Photoshop)
       ↓
Backend converts .cube → PNG (512×512, GPUImage layout)
       ↓
Store on CDN → return lutUrl in API
       ↓
(Optional) same PNG in app bundle as assets/luts/{lutAsset}
```

**LUT PNG specification:**

| Property | Value |
|---|---|
| Size | 512 × 512 pixels |
| Layout | GPUImage: 8×8 grid of 64×64 tiles = 64³ cube |
| Format | PNG, 8-bit RGB |
| Filename | lowercase_snake_case.png |

**Do NOT send `.cube` files to the mobile app.**

Dev conversion tool in repo:

```bash
dart run tool/cube_to_lut_png.dart "input.cube" assets/luts/output.png
```

---

## Color filters — seed data (current app)

| Category | id | label | renderType |
|---|---|---|---|
| portrait | whitening | Pure | matrix |
| portrait | clarendon | Bright | matrix |
| portrait | ludwig | Clean | matrix |
| portrait | rosy | Soft | matrix |
| portrait | valencia | Sunset | matrix |
| life | warm | Warm | matrix |
| life | cool | Cool | matrix |
| retro | vintage | Retro | matrix |
| retro | mono | B & W | matrix |
| retro | cityfilm | City Film | lut |
| film | going_for_a_walk | Going for a Walk | lut |
| film | good_morning | Good Morning | lut |
| film | nah | Nah | lut |
| film | once_upon_a_time | Once Upon a Time | lut |
| film | passing_by | Passing By | lut |
| film | serenity | Serenity | lut |
| film | undeniable_2 | Undeniable 2 | lut |
| film | undeniable | Undeniable | lut |
| film | urban_cowboy | Urban Cowboy | lut |
| film | you_can_do_it | You Can Do It | lut |
| film | smooth_sailing | Smooth Sailing | lut |
| film | well_see | We'll See | lut |

**LUT PNG files to upload:** all files in `assets/luts/` (22 PNGs).

Full matrix values and lutAsset names are in `ArColorFilterCatalog.bundled()` in the Dart model.

---

# 2. AR Face Effects API

## Endpoint

```
GET /camera-studio/ar-effects
```

## Response shape

```json
{
  "version": "2026-07-20T01",
  "effectCategories": [
    {
      "id": "carousel",
      "label": "Effects",
      "sortOrder": 0,
      "effects": [ … ]
    }
  ]
}
```

## How to add an effect (dashboard workflow)

1. Choose **renderType**: `none` | `sticker` | `composite` | `distortion`
2. Set **id** (unique snake_case slug)
3. Set **label**, **sortOrder**, **emoji**, **thumbnailUrl**
4. **sticker** → upload PNG + set anchor config
5. **composite** → upload multiple PNGs in `stickers[]`
6. **distortion** → select preset only (no file upload)
7. Publish and bump **version**

---

## Render type: `none`

Clears all effects. Used for the "Original" carousel slot.

```json
{
  "id": "none",
  "label": "Original",
  "renderType": "none",
  "sortOrder": 0,
  "emoji": "✨"
}
```

---

## Render type: `sticker`

Single transparent PNG overlaid on the face.

| Field | Required | Description |
|---|---|---|
| `renderType` | yes | `"sticker"` |
| `assetUrl` | yes | HTTPS URL to transparent PNG |
| `anchor` | yes | Face placement object (see below) |
| `assetAsset` | no | Offline bundled filename |

**PNG rules:** transparent background, 512–1024 px, lowercase_snake_case.png

**Example — glasses:**

```json
{
  "id": "glasses",
  "label": "Glasses",
  "renderType": "sticker",
  "sortOrder": 1,
  "emoji": "😎",
  "thumbnailUrl": "https://cdn.example.com/thumbs/glasses.jpg",
  "assetUrl": "https://cdn.example.com/stickers/glasses_round.png",
  "assetAsset": "glasses_round.png",
  "anchor": {
    "leftLandmark": 33,
    "rightLandmark": 263,
    "anchorLandmark": 168,
    "pinX": "nose_bridge",
    "pinY": "eye_line",
    "widthScreenMult": 3.5,
    "widthMinFaceFrac": 0.70,
    "pivotU": 0.5,
    "pivotV": 0.5,
    "useAveragedEyes": true
  }
}
```

---

## Render type: `composite`

Multiple PNG layers in one effect (e.g. dog = ears + nose + tongue).

| Field | Required | Description |
|---|---|---|
| `renderType` | yes | `"composite"` |
| `stickers` | yes | Array of `{ assetUrl, assetAsset?, anchor }` |

Layers are drawn in array order (first = back, last = front).

**Example — dog:** see `ArEffectCatalog.bundled()` in the Dart model for full anchor values.

---

## Render type: `distortion`

GPU face-warp shader. **No PNG upload.**

| Field | Required | Description |
|---|---|---|
| `renderType` | yes | `"distortion"` |
| `distortionPreset` | yes | One of: `big_eyes`, `big_lips`, `long_nose` |

```json
{
  "id": "big_eyes",
  "label": "Big Eyes",
  "renderType": "distortion",
  "sortOrder": 6,
  "emoji": "👀",
  "distortionPreset": "big_eyes"
}
```

---

## Anchor config reference

Used by `sticker` and each layer in `composite`. Based on MediaPipe Face Mesh (468 points).

### Common landmark indices

| Index | Face point |
|---|---|
| 33 | Left eye outer corner |
| 263 | Right eye outer corner |
| 168 | Nose bridge |
| 1 | Nose tip |
| 152 | Chin |
| 10 | Forehead |
| 61 | Mouth left |
| 291 | Mouth right |
| 17 | Mouth bottom |
| 234 | Left cheek |
| 454 | Right cheek |

### pinX values

`ref_midpoint` | `anchor` | `nose_bridge` | `mouth_midpoint` | `eye_midpoint`

### pinY values

`anchor` | `ref_midline` | `eye_line` | `nose_mouth_blend` | `top_head_offset`

### Key sizing fields

| Field | Use |
|---|---|
| `widthScreenMult` | width = eye distance × value (glasses ≈ 3.5) |
| `widthFaceFrac` | width = face width × value (dog ears ≈ 1.05) |
| `widthMinFaceFrac` | Minimum width as fraction of face width |
| `pivotU`, `pivotV` | PNG attach point within image (0…1) |
| `useAveragedEyes` | `true` for stable eye-based sizing |
| `scaleFromFaceBox` | `true` for mask-style full-face coverage |
| `heightSpanFrac` | Force quad height from landmark span (mask) |

For new stickers, copy anchor presets from `ArEffectCatalog.bundled()` or coordinate with the mobile team.

---

## Effects — seed data (current app)

| id | label | renderType | PNG files needed |
|---|---|---|---|
| none | Original | none | — |
| glasses | Glasses | sticker | glasses_round.png |
| shades | Shades | sticker | glasses_aviator.png |
| dog | Dog | composite | filter_ears.png + filter_nose.png + filter_tongue.png |
| moustache | Moustache | sticker | filter_moustache.png |
| mask | Mask | sticker | filter_skull_mask.png |
| big_eyes | Big Eyes | distortion | **none** |
| big_lips | Big Lips | distortion | **none** |
| long_nose | Nose | distortion | **none** |

**Sticker PNG source folder:** `android/app/src/main/res/drawable/` (7 files total).

Full anchor JSON is in `ArEffectCatalog.bundled()` in the Dart model.

---

# 3. Asset handoff checklist

Send the mobile team these files when standing up the CDN:

### Sticker PNGs (7 files — effects)

- glasses_round.png
- glasses_aviator.png
- filter_moustache.png
- filter_skull_mask.png
- filter_ears.png
- filter_nose.png
- filter_tongue.png

### LUT PNGs (22 files — color filters)

All files in `assets/luts/` (whitening.png, warm.png, cityfilm.png, going_for_a_walk.png, …)

### Optional

- Thumbnail JPG/PNG per filter/effect for carousel icons

---

# 4. Validation summary

| Type | Must have |
|---|---|
| matrix filter | `colorMatrix` length = 20 |
| lut filter | `lutUrl` or `lutAsset` |
| sticker effect | `assetUrl` or `assetAsset` + `anchor` |
| composite effect | `stickers[]` with asset + anchor per layer |
| distortion effect | `distortionPreset` ∈ { big_eyes, big_lips, long_nose } |

---

# 5. App integration status

| Layer | Status |
|---|---|
| Dart models + bundled seed data | ✅ Done |
| API fetch + cache in app | 🔜 Pending (backend API first) |
| Native dynamic PNG/LUT from CDN | 🔜 Phase 2 |

The app currently runs on bundled data. Once APIs are live, the mobile team wires fetch calls to `ArFilterCatalog.updateColorCatalog()` and `ArFilterCatalog.updateEffectCatalog()`.
