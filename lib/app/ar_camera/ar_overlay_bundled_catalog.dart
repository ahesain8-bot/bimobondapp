import 'package:bimobondapp/app/ar_camera/ar_overlay_catalog_model.dart';

/// Offline fallback for the screen-overlay catalog: the four animations that
/// ship inside the APK (`android/app/src/main/assets/*.json`).
///
/// Used until `GET /camera-studio/ar-overlays` responds, and kept in place if
/// it never does — so the effect carousel is never empty on a cold, offline
/// start. Ids match the backend's ids on purpose: when the remote catalog does
/// arrive it replaces these entries rather than duplicating them, and a user
/// who had one selected keeps their selection.
class ArOverlayBundledCatalog {
  ArOverlayBundledCatalog._();

  static final catalog = ArOverlayCatalog(
    version: 'bundled',
    categories: [
      ArOverlayCategoryModel(
        id: 'overlays',
        label: 'Overlays',
        sortOrder: 0,
        overlays: [
          const ArOverlayItemModel(
            id: 'confetti',
            label: 'Confetti',
            sortOrder: 0,
            bundledAsset: 'Confetti.json',
            emoji: '🎉',
          ),
          const ArOverlayItemModel(
            id: 'keywords',
            label: 'Keywords',
            sortOrder: 1,
            bundledAsset: 'Keywords.json',
            emoji: '🔤',
          ),
          const ArOverlayItemModel(
            id: 'snowfall',
            label: 'Snowfall',
            sortOrder: 2,
            bundledAsset: 'snowfall.json',
            emoji: '❄️',
          ),
          const ArOverlayItemModel(
            id: 'snow_off_white',
            label: 'Snow White',
            sortOrder: 3,
            bundledAsset: 'Snow Off white.json',
            emoji: '🌨️',
          ),
          ArOverlayItemModel(
            id: 'static_360_test',
            label: '360° Space',
            sortOrder: 4,
            emoji: '🌐',
            videoId: 'demo-360-vid',
            video: VideoOverlay(
              id: 'demo-360-vid',
              url:
                  'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
              projection: VideoProjection.equirectangular,
              stereoMode: VideoStereoMode.mono,
              is360: true,
            ),
          ),
        ],
      ),
    ],
  );
}
