// =============================================================================
// SCREEN-OVERLAY FILTERS — BACKEND IMPLEMENTATION GUIDE
// =============================================================================
//
// This file is NOT wired into the app. It is a handoff document for the
// backend/dashboard developer, describing exactly what API to build so the
// app can load screen-overlay animations (Confetti, Snowfall, Snow White,
// Keywords, ...) dynamically instead of the current hardcoded list bundled
// as Android assets (android/app/src/main/assets/*.json) and mapped in
// FilterType.kt / ar_filter_catalog.dart.
//
// -----------------------------------------------------------------------------
// 1. WHAT THIS API IS FOR
// -----------------------------------------------------------------------------
//
// "Screen overlays" are full-screen decorative animations (confetti falling,
// snow falling, floating keywords, ...) that play on top of the live camera
// preview and get baked into recorded video. They are NOT face-anchored (no
// landmark tracking, no positioning logic) — every overlay just plays the
// same full-screen animation regardless of who or what is in frame. This is
// what makes them simpler than beauty/color filters: there is no slider math,
// no 0–100 scale, no conversion. The only real "content" is the animation
// file itself.
//
// The animation format is Lottie (https://airbnb.io/lottie/) — a JSON file
// describing a vector animation, already used by this app (the `lottie`
// Android/Flutter package renders it). The dashboard's job is to let someone
// upload a Lottie JSON file (exported from Adobe After Effects via the
// Bodymovin plugin, or downloaded from a Lottie marketplace) and give it a
// name + icon; the app downloads and plays that file — no video processing,
// no per-frame rendering work on the backend.
//
// Goal: same as the color-filters dashboard — a non-developer should be able
// to upload a new overlay (pick a .json file, type a label, pick an
// icon/thumbnail) and have it show up in the app's filter picker with no app
// update required.
//
// >>> IMPORTANT — PLEASE READ BEFORE BUILDING THE DASHBOARD FORM <<<
//
// The dashboard must have real FILE UPLOAD inputs for the animation and the
// thumbnail. It must NOT have text inputs where an admin pastes a URL.
//
//   WRONG                              RIGHT
//   ---------------------------------  ---------------------------------
//   Lottie URL:   [ text input ]       Animation:  [ Choose file ] .json
//   Thumbnail URL:[ text input ]       Thumbnail:  [ Choose file ] .jpg/.png
//
// `lottieUrl` and `thumbnailUrl` in the API response (section 3) are OUTPUTS
// that the backend generates after storing an uploaded file. They are never
// something a person types. The whole point of this feature is that a
// non-developer can publish an overlay by picking a file — asking them to
// host it somewhere first and paste a link back defeats it, and in practice
// produces links that don't work (Google Drive / Dropbox share links return
// an HTML page, not the JSON body the app needs).
//
// So the flow is:
//
//   admin picks Confetti.json in the dashboard
//     -> backend saves the file to storage      (section 9.3)
//     -> backend records its public URL in the DB (section 9.4)
//     -> GET /camera-studio/ar-overlays returns that URL as `lottieUrl`
//     -> app downloads it and plays the animation
//
// Same for the thumbnail image -> `thumbnailUrl`.
//
// -----------------------------------------------------------------------------
// 2. ENDPOINT
// -----------------------------------------------------------------------------
//
//   GET /camera-studio/ar-overlays
//
// Called once when the camera screen opens (same timing as
// /camera-studio/color-filters), and can be cached/CDN'd the same way —
// content changes rarely. No auth requirements beyond whatever the rest of
// the app's API already uses.
//
// -----------------------------------------------------------------------------
// 3. RESPONSE SHAPE
// -----------------------------------------------------------------------------
//
// {
//   "version": "2026-07-25T01",           // any string; app just stores it,
//                                          // bump it whenever content changes
//   "overlayCategories": [
//     {
//       "id": "overlays",                 // category key
//       "label": "Overlays",              // category display name
//       "sortOrder": 0,                   // categories sorted ascending
//       "overlays": [
//         { ...one overlay object, see section 4... },
//         { ...another overlay object... }
//       ]
//     }
//   ]
// }
//
// Right now there's only ever been one flat list of overlays (no sub-
// categories like the color filters have Portrait/Trending/etc.), but the
// shape supports categories from day one in case that's wanted later (e.g. a
// "Seasonal" row for holiday-themed overlays) without any app changes.
//
// -----------------------------------------------------------------------------
// 4. FIELDS PER OVERLAY
// -----------------------------------------------------------------------------
//
// Field-by-field table:
//
//   Field            Type     Required  Notes
//   ---------------- -------- --------- -------------------------------------
//   id               string   yes       unique, stable key, e.g. "confetti".
//                                        Once shipped, never change this for
//                                        an existing overlay — reused across
//                                        app sessions/caches.
//   label            string   yes       display name shown under the
//                                        thumbnail in the filter picker.
//   sortOrder        int      yes       overlays sorted ascending within
//                                        their category.
//   emoji            string   see note  fallback icon, used when there is no
//                                        thumbnail (or it fails to load).
//   thumbnailUrl     string   see note  preview image shown in the effects
//                                        carousel (recommended: square,
//                                        ~200x200px, ideally an actual frame
//                                        of the animation). GENERATED from an
//                                        uploaded file, same as lottieUrl.
//   lottieUrl        string   yes       direct URL to the Lottie .json
//                                        animation file. GENERATED by the
//                                        backend when the admin uploads the
//                                        file — never typed by hand, see the
//                                        callout in section 1. Must be
//                                        publicly reachable (no auth) and
//                                        return the raw JSON body. See
//                                        section 5.
//   previewColorHex  string   no        e.g. "#FFFFFF" — solid-color swatch
//                                        placeholder while thumbnailUrl loads.
//
// *at least ONE of emoji / thumbnailUrl is required — same rule as color
//  filters: an overlay with neither renders as a blank circle, so the app
//  drops it from the list. thumbnailUrl is preferred where available; the
//  effect carousel shows it inside the ring and falls back to emoji while it
//  loads or if it fails.
//
// -----------------------------------------------------------------------------
// 5. THE lottieUrl FILE ITSELF
// -----------------------------------------------------------------------------
//
// - Must be a valid Lottie JSON export (Bodymovin format). The backend does
//   NOT need to validate or understand the animation's contents — just host
//   the file as-is and return its URL. If someone uploads an invalid file,
//   the app's Lottie parser will fail to load it and the overlay simply won't
//   animate for anyone who picks it (fails safe, doesn't crash the camera) —
//   still worth the dashboard doing a basic "does this file parse as JSON"
//   check on upload so bad uploads are caught immediately instead of
//   discovered later by a user.
// - Keep file size reasonable. These are FULL-SCREEN animations played
//   continuously behind/over the live camera preview AND re-composited into
//   every recorded video frame — large, layer-heavy compositions (hundreds of
//   shape layers, masks, mattes) are noticeably more expensive to render live
//   than a typical UI Lottie animation. As a rough guideline, the current
//   bundled overlays range from ~130KB–470KB; treat anything much larger as
//   worth a second look before publishing.
// - The app downloads this file once per overlay (first time it's selected,
//   or eagerly when the catalog loads — implementation detail on the app
//   side) and caches it locally, so it isn't re-downloaded every time the
//   filter is picked or the camera reopens. If you update the file at the
//   SAME lottieUrl without changing `id`, the app's cache may keep serving
//   the old version for a while — see the cache-busting note below.
//
// -----------------------------------------------------------------------------
// 6. CACHE-BUSTING WHEN REPLACING AN OVERLAY'S ANIMATION
// -----------------------------------------------------------------------------
//
// If a dashboard user replaces the Lottie file behind an EXISTING overlay
// (same `id`, new animation), bump `lottieUrl` to a new path/filename (e.g.
// append a version segment: ".../confetti-v2.json") rather than
// overwriting the file at the same URL in place. This guarantees every
// client re-downloads the new content instead of serving a stale local
// cache indefinitely. Bumping the top-level `version` string alone is not
// enough to bust a per-file cache keyed by URL.
//
// -----------------------------------------------------------------------------
// 7. VALIDATION THE BACKEND SHOULD ENFORCE
// -----------------------------------------------------------------------------
//
//   - id must be unique across the whole response, and stable across time
//     (never reassign an existing id to different content).
//   - lottieUrl must be present and must resolve to a reachable, valid JSON
//     file at publish time (basic "does it parse" check on upload).
//   - At least one of emoji / thumbnailUrl must be non-empty.
//   - sortOrder should be a plain integer; the app clamps/defaults
//     defensively but bad values shouldn't be saved in the dashboard.
//
// -----------------------------------------------------------------------------
// 8. WHAT DOES NOT CHANGE / WHAT'S DIFFERENT FROM COLOR FILTERS
// -----------------------------------------------------------------------------
//
//   - No 0–100 scale, no numeric slider fields at all — overlays are on/off,
//     picked from the list, nothing to tune per-overlay.
//   - No face/beauty processing of any kind — these never touch skin
//     smoothing, blush, lip tint, or the color-grade fields. A screen overlay
//     and a color filter can theoretically both be "selected" conceptually,
//     but in this app's current UI a user picks one AR effect at a time, so
//     that combination doesn't need to be designed for yet.
//   - No per-user or per-device logic — single global overlay list, same as
//     color filters.
//   - The backend hosts the raw animation file; no video/image processing,
//     no rendering, no transcoding of the Lottie file needed on the backend
//     side at all.
//
// -----------------------------------------------------------------------------
// 9. DASHBOARD UPLOAD FLOW + STORAGE
// -----------------------------------------------------------------------------
//
// Everything above describes the READ side — the one endpoint the app calls.
// This section describes the WRITE side: how a non-developer gets a new
// overlay into that response. None of it is visible to the app, so the exact
// shape is the backend's call; what follows is the flow the app's design
// assumes.
//
// 9.1 THE FORM
//
// A dashboard "Add overlay" form collects:
//
//   Input                    Control            Becomes
//   ------------------------ ------------------ ------------------------------
//   Lottie animation (.json) FILE UPLOAD, req.  lottieUrl (generated on save)
//   Thumbnail (.jpg/.png)    FILE UPLOAD, opt.  thumbnailUrl (generated)
//   Label                    text, required     label
//   Emoji                    text               emoji  (see section 4's note —
//                                               required only if no thumbnail)
//   Category                 select             the category the item sits in
//                                               (defaults to "overlays" —
//                                               only one row exists today)
//   Sort order               number             sortOrder
//   Preview colour           colour/hex, opt.   previewColorHex
//   Loop                     checkbox, def. on  loop
//
// The first two rows are FILE PICKERS — not URL text boxes. See the callout in
// section 1: if the dashboard currently has "Lottie URL" and "Thumbnail URL"
// text fields, those need to be replaced with upload controls, and the backend
// needs to accept the files (section 9.2) and derive the URLs itself.
//
// The admin should never see or need to know the resulting URLs; they are an
// internal detail of how the backend stores the file.
//
// 9.2 SUGGESTED ENDPOINTS (admin-authenticated, NOT public)
//
//   POST   /admin/camera-studio/ar-overlays        create (multipart)
//   PUT    /admin/camera-studio/ar-overlays/{id}   update (multipart)
//   DELETE /admin/camera-studio/ar-overlays/{id}   remove / unpublish
//   GET    /admin/camera-studio/ar-overlays        list for the dashboard grid
//
// Multipart because two files are involved. Everything else can be ordinary
// form fields. Concretely, the create request body looks like:
//
//   Content-Type: multipart/form-data
//
//     lottieFile      = <binary>   Confetti.json        (file part, required)
//     thumbnailFile   = <binary>   confetti.jpg         (file part, optional)
//     id              = confetti
//     label           = Confetti
//     emoji           = 🎉
//     categoryId      = overlays
//     sortOrder       = 0
//     previewColorHex = #FFD54F
//     loop            = true
//
// Note there is no `lottieUrl` / `thumbnailUrl` field in the REQUEST — the
// backend produces those while handling the upload and returns them in the
// response (and in the public GET). On update, both file parts are optional:
// omitting them means "keep the existing file".
//
// 9.3 WHERE THE FILES GO — IMPORTANT
//
// Store the FILES in object storage / a public static directory (S3, GCS, a
// CDN bucket, or just a served `public/overlays/` folder). Store only their
// PUBLIC URLS in the database.
//
// Do NOT put the Lottie JSON in a database column as a blob or text. The app
// hands `lottieUrl` straight to the Lottie library, which fetches it over
// plain HTTP and caches it on disk by URL. A DB-backed blob means every
// device re-downloads through the application server on every cache miss, and
// gives up CDN caching entirely — for a file that can be several hundred KB
// and is fetched by every user who opens the camera.
//
// If the files genuinely must live in the DB, then expose them through a
// dedicated static route (e.g. `GET /media/overlays/{id}.json`) with proper
// cache headers, and put THAT url in `lottieUrl`. The app cannot tell the
// difference; it only needs a URL that returns the JSON body.
//
// 9.4 SUGGESTED TABLE
//
//   ar_overlays
//   ---------------------------------------------------------------------
//   id                text     PK   the stable key sent as "id"
//   category_id       text          FK -> ar_overlay_categories.id
//   label             text
//   emoji             text
//   lottie_url        text          public URL of the uploaded .json
//   thumbnail_url     text     null public URL of the uploaded image
//   preview_color_hex text     null
//   loop              bool          default true
//   sort_order        int
//   is_published      bool          unpublished rows are omitted from the
//                                    public GET response
//   created_at        timestamp
//   updated_at        timestamp
//
//   ar_overlay_categories
//   ---------------------------------------------------------------------
//   id                text     PK   e.g. "overlays"
//   label             text
//   sort_order        int
//
// The public `GET /camera-studio/ar-overlays` is then just: select published
// rows, group by category, order both by sort_order, and shape them into
// section 3's JSON.
//
// 9.5 ON UPLOAD, THE BACKEND SHOULD
//
//   1. Verify the uploaded animation parses as JSON, and that it looks like a
//      Lottie export (top-level "v", "w", "h", "layers" keys present). This is
//      the single most valuable check — it catches a wrong file immediately
//      instead of shipping a filter that silently never animates.
//   2. Reject oversized files. See section 5 — these render live over the
//      camera preview AND get re-rasterised into every recorded video frame.
//      A hard limit around 1MB is sensible; the app's own bundled overlays are
//      130KB-470KB.
//   3. Store under a versioned path, e.g.
//      `overlays/{id}/{timestamp}.json`, so replacing an animation always
//      produces a NEW url — this is what makes section 6's cache-busting work
//      automatically instead of relying on whoever uploads to remember it.
//   4. Bump the catalog's `version` string.
//
// -----------------------------------------------------------------------------
// 10. WHAT "DELETE" SHOULD MEAN
// -----------------------------------------------------------------------------
//
// Prefer unpublishing (is_published = false) over hard deletion. A user whose
// app has an older cached catalog may still have that overlay selected; if the
// file 404s, the animation simply doesn't play (the camera stays fine — it
// fails safe), but keeping the file around avoids that entirely. Reusing a
// deleted overlay's `id` for different content is the one thing that must
// never happen — see section 7.
//
// =============================================================================
// REFERENCE MODEL CLASSES (illustrative only)
// =============================================================================
//
// These classes are NOT used by the running app. They exist purely so this
// document has a concrete, typed shape to hand to the backend developer
// alongside the plain-English guide above. The app's real (currently static)
// model lives in FilterType.kt (native) / ar_filter_catalog.dart (Dart) —
// wiring this up to fetch dynamically from /camera-studio/ar-overlays is a
// separate, later implementation step, not part of this document.

/// Top-level response of GET /camera-studio/ar-overlays.
class ArOverlayBackendCatalog {
  const ArOverlayBackendCatalog({
    required this.version,
    required this.overlayCategories,
  });

  /// Any string. Bump it whenever overlay content changes on the dashboard —
  /// lets the app know its cached copy is stale.
  final String version;

  final List<ArOverlayBackendCategory> overlayCategories;
}

/// One row of overlays (currently only ever one, id "overlays").
class ArOverlayBackendCategory {
  const ArOverlayBackendCategory({
    required this.id,
    required this.label,
    required this.sortOrder,
    required this.overlays,
  });

  final String id;
  final String label;

  /// Categories are shown ascending by this value.
  final int sortOrder;

  final List<ArOverlayBackendItem> overlays;
}

/// A single screen-overlay animation, e.g. "Confetti", "Snowfall".
class ArOverlayBackendItem {
  const ArOverlayBackendItem({
    required this.id,
    required this.label,
    required this.sortOrder,
    required this.lottieUrl,
    this.emoji,
    this.thumbnailUrl,
    this.previewColorHex,
  });

  /// Unique, stable key, e.g. "confetti". Never reassign to different
  /// content once shipped.
  final String id;

  /// Display name shown under the thumbnail in the filter picker.
  final String label;

  /// Overlays are sorted ascending by this value within their category.
  final int sortOrder;

  /// Direct URL to the Lottie .json animation file. See section 5 — must be
  /// publicly reachable, valid Bodymovin JSON, reasonable file size.
  final String lottieUrl;

  /// Offline fallback icon. At least one of [emoji] / [thumbnailUrl] is
  /// required, or the app drops this overlay from the list.
  final String? emoji;

  /// Preview image shown in the filter picker. Recommended: square,
  /// ~200x200px, ideally an actual frame of the animation.
  final String? thumbnailUrl;

  /// Solid-color swatch (e.g. "#FFFFFF") shown as a placeholder while
  /// [thumbnailUrl] loads.
  final String? previewColorHex;
}

/// Worked examples — the app's current bundled overlays, expressed as this
/// reference model. Handy for the backend dev to compare their saved records
/// against.
const confettiOverlayExample = ArOverlayBackendItem(
  id: 'confetti',
  label: 'Confetti',
  sortOrder: 0,
  emoji: '🎉',
  thumbnailUrl: 'https://cdn.example.com/thumbs/confetti.jpg',
  lottieUrl: 'https://cdn.example.com/overlays/confetti.json',
);

const snowfallOverlayExample = ArOverlayBackendItem(
  id: 'snowfall',
  label: 'Snowfall',
  sortOrder: 1,
  emoji: '❄️',
  lottieUrl: 'https://cdn.example.com/overlays/snowfall.json',
);
