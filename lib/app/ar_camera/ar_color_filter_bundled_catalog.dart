import 'package:bimobondapp/app/ar_camera/ar_color_filter_catalog_model.dart';

/// Offline beauty-filter seed (no LUT PNGs).
///
/// Dynamic source: GET /camera-studio/color-filters
/// Fallback: [ArFilterCatalog.restoreBundledColorCatalog]
class ArColorFilterBundledCatalog {
  ArColorFilterBundledCatalog._();

  static const ArColorFilterCatalog catalog = ArColorFilterCatalog(
    version: 'bundled-beauty',
    categories: [
      ArColorFilterCategoryModel(
        id: 'beauty',
        label: 'Beauty',
        sortOrder: 0,
        filters: [
          ArColorFilterItemModel(
            id: 'soft_glow',
            label: 'Soft Glow',
            type: ArColorFilterRenderType.beauty,
            emoji: '✨',
            sortOrder: 0,
            previewColorHex: '#F5E6D3',
            defaultIntensity: 0.70,
            params: ArBeautyFilterParams(
              smooth: 0.65,
              whiten: 0.55,
              brighten: 0.40,
              blush: 0.25,
              lipTint: '#E8527A',
              lipStrength: 0.45,
            ),
          ),
          ArColorFilterItemModel(
            id: 'pure_white',
            label: 'Pure',
            type: ArColorFilterRenderType.beauty,
            emoji: '🤍',
            sortOrder: 1,
            previewColorHex: '#F0E0D0',
            defaultIntensity: 0.75,
            params: ArBeautyFilterParams(
              smooth: 0.55,
              whiten: 0.80,
              brighten: 0.50,
              blush: 0.10,
              lipTint: '#E91E63',
              lipStrength: 0.35,
            ),
          ),
          ArColorFilterItemModel(
            id: 'rosy_soft',
            label: 'Rosy',
            type: ArColorFilterRenderType.beauty,
            emoji: '🌸',
            sortOrder: 2,
            previewColorHex: '#F9DCE0',
            defaultIntensity: 0.65,
            params: ArBeautyFilterParams(
              smooth: 0.60,
              whiten: 0.45,
              brighten: 0.35,
              blush: 0.45,
              lipTint: '#E8527A',
              lipStrength: 0.55,
            ),
          ),
          ArColorFilterItemModel(
            id: 'clean_bright',
            label: 'Clean',
            type: ArColorFilterRenderType.beauty,
            emoji: '☀️',
            sortOrder: 3,
            previewColorHex: '#EAF2F5',
            defaultIntensity: 0.70,
            params: ArBeautyFilterParams(
              smooth: 0.50,
              whiten: 0.60,
              brighten: 0.55,
              blush: 0.15,
              lipTint: '#F48FB1',
              lipStrength: 0.30,
            ),
          ),
        ],
      ),
    ],
  );
}
