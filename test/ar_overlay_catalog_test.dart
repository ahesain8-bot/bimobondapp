import 'package:flutter_test/flutter_test.dart';
import 'package:bimobondapp/app/ar_camera/ar_overlay_catalog_model.dart';

void main() {
  group('ArOverlayItemModel Lottie Extension & Backend Parsing Tests', () {
    test('parses .lottie extension as ArOverlayMediaType.lottie', () {
      final json = {
        'id': 'test_lottie',
        'label': 'Test Lottie',
        'sortOrder': 1,
        'animationUrl': 'https://example.com/assets/overlay.lottie',
        'emoji': '✨',
      };

      final model = ArOverlayItemModel.fromJson(json);
      expect(model, isNotNull);
      expect(model!.mediaType, equals(ArOverlayMediaType.lottie));
      expect(model.isVideo, isFalse);
      expect(model.animationUrl, equals('https://example.com/assets/overlay.lottie'));
    });

    test('parses .dotlottie extension as ArOverlayMediaType.lottie', () {
      final json = {
        'id': 'test_dotlottie',
        'label': 'DotLottie Test',
        'sortOrder': 2,
        'animationUrl': 'https://example.com/assets/animation.dotlottie',
        'emoji': '🎨',
      };

      final model = ArOverlayItemModel.fromJson(json);
      expect(model, isNotNull);
      expect(model!.mediaType, equals(ArOverlayMediaType.lottie));
      expect(model.isVideo, isFalse);
    });

    test('parses bundledAsset with .lottie extension', () {
      final json = {
        'id': 'bundled_lottie',
        'label': 'Bundled Lottie',
        'sortOrder': 3,
        'bundledAsset': 'sparkles.lottie',
        'emoji': '⭐',
      };

      final model = ArOverlayItemModel.fromJson(json);
      expect(model, isNotNull);
      expect(model!.bundledAsset, equals('sparkles.lottie'));
      expect(model.mediaType, equals(ArOverlayMediaType.lottie));
      expect(model.isVideo, isFalse);
    });

    test('explicit mediaType dotlottie resolves to ArOverlayMediaType.lottie', () {
      final json = {
        'id': 'explicit_dotlottie',
        'label': 'Explicit DotLottie',
        'sortOrder': 4,
        'animationUrl': 'https://example.com/raw_animation',
        'mediaType': 'dotlottie',
        'emoji': '🔥',
      };

      final model = ArOverlayItemModel.fromJson(json);
      expect(model, isNotNull);
      expect(model!.mediaType, equals(ArOverlayMediaType.lottie));
    });

    test('parses snake_case backend keys (lottie_url, thumbnail_url, etc.)', () {
      final json = {
        'id': 'remote_backend_lottie',
        'title': 'Remote Overlay',
        'sort_order': 10,
        'lottie_url': 'https://cdn.example.com/overlays/hearts.json',
        'thumbnail_url': 'https://cdn.example.com/thumbnails/hearts.png',
        'is_active': true,
      };

      final model = ArOverlayItemModel.fromJson(json);
      expect(model, isNotNull);
      expect(model!.id, equals('remote_backend_lottie'));
      expect(model.label, equals('Remote Overlay'));
      expect(model.lottieUrl, equals('https://cdn.example.com/overlays/hearts.json'));
      expect(model.animationUrl, equals('https://cdn.example.com/overlays/hearts.json'));
      expect(model.thumbnailUrl, equals('https://cdn.example.com/thumbnails/hearts.png'));
      expect(model.mediaType, equals(ArOverlayMediaType.lottie));
    });

    test('parses flat array catalog from backend response', () {
      final json = {
        'data': [
          {
            'id': 'overlay_1',
            'name': 'Overlay 1',
            'url': 'https://cdn.example.com/1.json',
            'emoji': '🎉',
          },
          {
            'id': 'overlay_2',
            'name': 'Overlay 2',
            'lottie_url': 'https://cdn.example.com/2.lottie',
            'emoji': '❄️',
          }
        ]
      };

      final catalog = ArOverlayCatalog.fromJson(json);
      expect(catalog.overlays.length, equals(2));
      expect(catalog.overlays[0].id, equals('overlay_1'));
      expect(catalog.overlays[1].mediaType, equals(ArOverlayMediaType.lottie));
    });
  });
}
