// =============================================================================
// BEAUTY / COLOR FILTERS — BACKEND IMPLEMENTATION GUIDE
// =============================================================================
//
// This file is NOT wired into the app. It is a handoff document for the
// backend/dashboard developer, describing exactly what API to build so the
// app can load filters dynamically instead of the current hardcoded list in
// ar_color_filter_bundled_catalog.dart.
//
// The real, currently-live app model (which still uses a 0–1 / -1..1 scale)
// lives in ar_color_filter_catalog_model.dart. Once the backend is ready and
// we decide to switch the scale below to 0–100, that file's fromJson parsing
// gets updated to match — that is a separate, later step, not part of this
// document.
//
// -----------------------------------------------------------------------------
// 1. WHAT THIS API IS FOR
// -----------------------------------------------------------------------------
//
// The camera screen shows a horizontal list of filters (Normal, Fade,
// Vintage, Bright, ...). Each filter is just a set of numbers that get sent
// to the native beauty/color-grade shader — there is NO .cube file, NO LUT
// image, NO video processing on the backend. The dashboard only needs to let
// someone type numbers and pick a thumbnail; the app does all the rendering.
//
// Goal: a non-developer (designer/marketing) should be able to log into the
// dashboard, create a new filter, type some numbers on sliders, upload a
// thumbnail, and it shows up in the app — no app update required.
//
// -----------------------------------------------------------------------------
// 2. ENDPOINT
// -----------------------------------------------------------------------------
//
//   GET /camera-studio/color-filters
//
// Called once when the camera screen opens (and can be safely cached/CDN'd —
// content changes rarely). No auth requirements beyond whatever the rest of
// the app's API already uses.
//
// -----------------------------------------------------------------------------
// 3. RESPONSE SHAPE
// -----------------------------------------------------------------------------
//
// {
//   "version": "2026-01-15",              // any string; app just stores it,
//                                          // bump it whenever content changes
//                                          // so the app knows to re-fetch/log
//   "colorFilterCategories": [
//     {
//       "id": "beauty",                   // category key
//       "label": "Filters",               // category display name
//       "sortOrder": 0,                   // categories sorted ascending
//       "filters": [
//         { ...one filter object, see section 4... },
//         { ...another filter object... }
//       ]
//     }
//   ]
// }
//
// Right now there's only ever been ONE category ("Filters"), but the shape
// supports more later (e.g. a separate "Portrait" or "Seasonal" category row)
// without any app changes.
//
// -----------------------------------------------------------------------------
// 4. FIELDS PER FILTER — THE IMPORTANT PART
// -----------------------------------------------------------------------------
//
// *** SCALE CHANGE FROM THE OLD STATIC FILE ***
// The old hardcoded Dart file used raw decimals (0.55, -0.15, etc.) because
// that's convenient for a programmer, not for a dashboard form. Below, EVERY
// numeric field is a plain WHOLE NUMBER from 0 to 100 — easy for a slider UI,
// easy for a non-technical person to type. The app converts these to the
// internal decimal ranges the shader needs; the backend never has to know
// about that math (it's documented in section 5 purely for reference).
//
// There are two kinds of numeric fields — read this carefully, it changes
// what "50" means:
//
//   (a) ONE-DIRECTION fields (smooth, whiten, brighten, blush, lipStrength)
//       0   = effect completely off
//       100 = effect at maximum strength
//       50  = effect at half strength
//       (no negative direction — these can't "reverse", only add strength)
//
//   (b) BALANCED fields (brightness, contrast, saturation, warmth)
//       0   = maximum in the negative direction (e.g. warmth 0 = as cold/blue
//             as the effect goes)
//       50  = NEUTRAL — no change at all, exactly like the original camera
//             frame. This is the default value for every field in this
//             group unless the filter is deliberately meant to push that
//             direction.
//       100 = maximum in the positive direction (e.g. warmth 100 = as warm/
//             orange as the effect goes)
//       Going ABOVE 50 increases/pushes that quality up; going BELOW 50
//       decreases/pushes it down. This is the "50 = center" rule.
//
// Field-by-field table:
//
//   Field             Type      Range      Default   Group        Notes
//   ----------------- --------- ---------- --------- ------------ -------------------------------
//   id                string    —          required  —            unique key, e.g. "vintage"
//   label             string    —          required  —            display name shown under the
//                                                                   thumbnail
//   emoji             string    —          optional* —             offline fallback icon (used if
//                                                                   thumbnailUrl fails/unset)
//   thumbnailUrl      string    —          optional* —             preview image shown in the
//                                                                   filter picker (recommended:
//                                                                   square, ~200x200px)
//   previewColorHex   string    —          optional  —             e.g. "#C9A876" — solid-color
//                                                                   swatch used as a placeholder
//                                                                   while thumbnailUrl loads
//   sortOrder         int       —          0         —             filters sorted ascending
//                                                                   within their category
//   defaultIntensity  int       0–100      70        intensity     see section 6 — the LIVE
//                                                                   slider's starting position
//   smooth            int       0–100      18        one-direction skin smoothing strength
//                                                                   (18 ≈ natural; 50+ reads plastic)
//   whiten            int       0–100      0         one-direction skin brightening/whitening
//   brighten          int       0–100      0         one-direction overall face brightening
//   blush             int       0–100      0         one-direction cheek blush strength
//   lipTint           hex color —          "#E8527A" —             lip tint color (only visible
//                                                                   if lipStrength > 0)
//   lipStrength       int       0–100      0         one-direction lip tint opacity
//   brightness        int       0–100      50        balanced      50 = no change
//   contrast          int       0–100      50        balanced      50 = no change
//   saturation        int       0–100      50        balanced      50 = no change (100 = punchy/
//                                                                   vivid colors, 0 = grayscale)
//   warmth            int       0–100      50        balanced      50 = no change (100 = warm/
//                                                                   orange tint, 0 = cool/blue tint)
//
// *at least ONE of emoji / thumbnailUrl is required — a filter with neither
//  is invalid and the app will silently drop it from the list.
//
// -----------------------------------------------------------------------------
// 5. HOW THE APP CONVERTS THESE NUMBERS (reference only — backend doesn't
//    need to implement this, just send 0–100 integers)
// -----------------------------------------------------------------------------
//
//   One-direction fields:  internal = incoming / 100.0
//     e.g. smooth = 18  ->  internal smooth = 0.18
//
//   Balanced fields:       internal = (incoming - 50) / 50.0
//     e.g. saturation = 15   ->  internal saturation = (15-50)/50  = -0.70
//     e.g. saturation = 50   ->  internal saturation = 0.0  (neutral)
//     e.g. saturation = 90   ->  internal saturation = (90-50)/50 = +0.80
//
// -----------------------------------------------------------------------------
// 6. THE LIVE INTENSITY SLIDER (defaultIntensity)
// -----------------------------------------------------------------------------
//
// After a user taps a filter, the app shows a slider under the preview so
// they can dial the strength up or down without leaving the filter. This
// slider ALSO uses the 0–100 / 50-center rule:
//
//   50  = the filter plays exactly as authored (the values from section 4,
//         unmodified) — this is the slider's default/starting position,
//         driven by "defaultIntensity" above.
//   >50 = every field in the filter is pushed stronger than authored
//         (e.g. 80 = noticeably more intense than the designed look).
//   <50 = every field is pulled back toward the original, unfiltered camera
//         image (e.g. 20 = filter is barely visible; 0 = fully off, camera
//         looks completely unfiltered).
//
// So defaultIntensity is just "where does the slider start" — most filters
// should ship with 70 (slightly softened from full strength) unless the
// filter is specifically designed to always be shown at full strength.
//
// -----------------------------------------------------------------------------
// 7. WORKED EXAMPLE — "Vivid" filter
// -----------------------------------------------------------------------------
//
// The old hardcoded decimal version (for reference):
//   smooth: 0.18, whiten: 0, brighten: 0, blush: 0, lipTint: '#E8527A',
//   lipStrength: 0, brightness: 0.10, contrast: 0.25, saturation: 0.40
//
// The SAME filter, as the backend should send it in the new 0–100 format:
//
// {
//   "id": "vivid",
//   "label": "Vivid",
//   "emoji": "🌈",
//   "thumbnailUrl": "https://cdn.example.com/filters/vivid.jpg",
//   "previewColorHex": "#FF6B9D",
//   "sortOrder": 8,
//   "defaultIntensity": 70,
//   "smooth": 18,
//   "whiten": 0,
//   "brighten": 0,
//   "blush": 0,
//   "lipTint": "#E8527A",
//   "lipStrength": 0,
//   "brightness": 60,     // was 0.10  -> 50 + 0.10*50 = 55, rounded/tuned to 60
//   "contrast": 63,       // was 0.25  -> 50 + 0.25*50 = 62.5 ≈ 63
//   "saturation": 70,     // was 0.40  -> 50 + 0.40*50 = 70
//   "warmth": 50          // unset originally -> neutral default
// }
//
// -----------------------------------------------------------------------------
// 8. VALIDATION THE BACKEND SHOULD ENFORCE
// -----------------------------------------------------------------------------
//
//   - Every numeric field above must be an integer between 0 and 100
//     inclusive. Reject/clamp anything outside that range — do not rely on
//     the app to fix bad data (the app will clamp defensively, but a bad
//     value should never be saved in the dashboard in the first place).
//   - id must be unique across the whole response.
//   - lipTint must be a valid 6-digit hex color starting with "#".
//   - At least one of emoji / thumbnailUrl must be non-empty.
//
// -----------------------------------------------------------------------------
// 9. WHAT DOES NOT CHANGE
// -----------------------------------------------------------------------------
//
//   - No .cube LUT files, no video/image processing on the backend at all.
//   - No per-user or per-device logic — this is a single global filter list.
//   - Category structure (section 3) stays as-is.
//
// =============================================================================
// REFERENCE MODEL CLASSES (illustrative only)
// =============================================================================
//
// These classes are NOT used by the running app — the app's real model is
// ArColorFilterCatalog in ar_color_filter_catalog_model.dart, which still
// expects the old 0–1 / -1..1 scale. These exist purely so this document has
// a concrete, typed shape to hand to the backend developer alongside the
// plain-English guide above. When we're ready to switch the live app over to
// the 0–100 scale, ar_color_filter_catalog_model.dart gets updated to match
// these shapes (dividing/centering the incoming ints as described in
// section 5) — that is a separate follow-up step.

/// Top-level response of GET /camera-studio/color-filters.
class ArColorFilterBackendCatalog {
  const ArColorFilterBackendCatalog({
    required this.version,
    required this.colorFilterCategories,
  });

  /// Any string. Bump it whenever filter content changes on the dashboard —
  /// lets the app know its cached copy is stale.
  final String version;

  final List<ArColorFilterBackendCategory> colorFilterCategories;
}

/// One row of filters (currently only ever "Filters" / id "beauty").
class ArColorFilterBackendCategory {
  const ArColorFilterBackendCategory({
    required this.id,
    required this.label,
    required this.sortOrder,
    required this.filters,
  });

  final String id;
  final String label;

  /// Categories are shown ascending by this value.
  final int sortOrder;

  final List<ArColorFilterBackendItem> filters;
}

/// A single filter, e.g. "Vintage", "Vivid", "Bright".
///
/// See section 4 of the guide above for the full field-by-field table
/// (ranges, defaults, one-direction vs. balanced fields).
class ArColorFilterBackendItem {
  const ArColorFilterBackendItem({
    required this.id,
    required this.label,
    this.emoji,
    this.thumbnailUrl,
    this.previewColorHex,
    this.sortOrder = 0,
    this.defaultIntensity = 70,
    this.smooth = 18,
    this.whiten = 0,
    this.brighten = 0,
    this.blush = 0,
    this.lipTint = '#E8527A',
    this.lipStrength = 0,
    this.brightness = 50,
    this.contrast = 50,
    this.saturation = 50,
    this.warmth = 50,
  });

  /// Unique key, e.g. "vintage". Must be unique across the whole response.
  final String id;

  /// Display name shown under the thumbnail in the filter picker.
  final String label;

  /// Offline fallback icon. At least one of [emoji] / [thumbnailUrl] is
  /// required, or the app drops this filter from the list.
  final String? emoji;

  /// Preview image shown in the filter picker. Recommended: square,
  /// ~200x200px. At least one of [emoji] / [thumbnailUrl] is required.
  final String? thumbnailUrl;

  /// Solid-color swatch (e.g. "#C9A876") shown as a placeholder while
  /// [thumbnailUrl] loads.
  final String? previewColorHex;

  /// Filters are sorted ascending by this value within their category.
  final int sortOrder;

  /// 0–100, 50-centered — where the live intensity slider starts when the
  /// user first taps this filter. 50 = plays exactly as authored below.
  /// See section 6.
  final int defaultIntensity;

  /// 0–100, one-direction. Skin smoothing strength. 0 = off, 100 = max.
  final int smooth;

  /// 0–100, one-direction. Skin brightening/whitening. 0 = off, 100 = max.
  final int whiten;

  /// 0–100, one-direction. Overall face brightening. 0 = off, 100 = max.
  final int brighten;

  /// 0–100, one-direction. Cheek blush strength. 0 = off, 100 = max.
  final int blush;

  /// 6-digit hex color (e.g. "#E8527A"). Only visible if [lipStrength] > 0.
  final String lipTint;

  /// 0–100, one-direction. Lip tint opacity. 0 = off, 100 = max.
  final int lipStrength;

  /// 0–100, balanced (50 = no change, <50 darker, >50 brighter).
  final int brightness;

  /// 0–100, balanced (50 = no change, <50 flatter, >50 punchier).
  final int contrast;

  /// 0–100, balanced (50 = no change, 0 = grayscale, 100 = vivid).
  final int saturation;

  /// 0–100, balanced (50 = no change, 0 = cool/blue tint, 100 = warm/orange
  /// tint).
  final int warmth;
}

/// Worked example — the "Vivid" filter from section 7, expressed as this
/// reference model. Handy for the backend dev to compare their saved record
/// against.
const vividFilterExample = ArColorFilterBackendItem(
  id: 'vivid',
  label: 'Vivid',
  emoji: '🌈',
  thumbnailUrl: 'https://cdn.example.com/filters/vivid.jpg',
  previewColorHex: '#FF6B9D',
  sortOrder: 8,
  defaultIntensity: 70,
  smooth: 18,
  brightness: 60,
  contrast: 63,
  saturation: 70,
  // warmth left at the default (50 = neutral) — this filter doesn't touch it.
);
