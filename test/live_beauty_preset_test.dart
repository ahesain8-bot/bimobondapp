import 'package:bimobondapp/core/services/live_beauty_preference.dart';
import 'package:bimobondapp/features/live/domain/entities/live_beauty_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveBeautyPreset', () {
    test('every parameter stays inside the shader range', () {
      for (final preset in LiveBeautyPreset.catalog) {
        for (final value in [
          preset.smooth,
          preset.brighten,
          preset.tone,
          preset.sharpen,
          preset.eyes,
        ]) {
          expect(value, inInclusiveRange(0.0, 1.0), reason: preset.id);
        }
      }
    });

    test('"off" is the only inactive look, and it is first in the picker', () {
      expect(LiveBeautyPreset.catalog.first, LiveBeautyPreset.off);
      final inactive = LiveBeautyPreset.catalog.where((p) => !p.isActive);
      expect(inactive, [LiveBeautyPreset.off]);
    });

    test('the default look is gentle, not a plastic filter', () {
      // A heavy default is what makes a beauty filter read as fake, and it is
      // the first frame a host ever sees of the app.
      expect(LiveBeautyPreset.natural.smooth, lessThan(0.4));
      expect(LiveBeautyPreset.natural.isActive, isTrue);
    });

    test('ids are unique so byId cannot resolve two looks', () {
      final ids = LiveBeautyPreset.catalog.map((p) => p.id).toSet();
      expect(ids.length, LiveBeautyPreset.catalog.length);
    });

    test('byId falls back to the default rather than to no beauty', () {
      expect(LiveBeautyPreset.byId('nope'), LiveBeautyPreset.natural);
      expect(
        LiveBeautyPreset.byId(LiveBeautyPreset.glow.id),
        LiveBeautyPreset.glow,
      );
    });
  });

  group('LiveBeautyPreference', () {
    setUp(() {
      LiveBeautyPreference.instance
        ..select(LiveBeautyPreset.natural)
        ..setIntensity(1.0);
    });

    test('beauty is on by default, the way TikTok opens its camera', () {
      expect(LiveBeautyPreference.instance.preset, LiveBeautyPreset.natural);
      expect(LiveBeautyPreference.instance.isActive, isTrue);
    });

    test('selecting the same look twice notifies only once', () {
      var notifications = 0;
      void listener() => notifications++;
      LiveBeautyPreference.instance.addListener(listener);
      addTearDown(() => LiveBeautyPreference.instance.removeListener(listener));

      LiveBeautyPreference.instance.select(LiveBeautyPreset.glow);
      LiveBeautyPreference.instance.select(LiveBeautyPreset.glow);

      expect(notifications, 1);
    });

    test('intensity clamps and zero intensity turns the look off', () {
      LiveBeautyPreference.instance.setIntensity(2.5);
      expect(LiveBeautyPreference.instance.intensity, 1.0);

      LiveBeautyPreference.instance.setIntensity(0);
      expect(LiveBeautyPreference.instance.intensity, 0);
      // The preset is still chosen, but nothing reaches the frame.
      expect(LiveBeautyPreference.instance.isActive, isFalse);
    });
  });
}
