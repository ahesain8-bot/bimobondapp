import 'package:bimobondapp/core/services/live_video_quality_preference.dart';
import 'package:bimobondapp/features/live/domain/entities/live_capture_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveCaptureProfile', () {
    test('ladder descends 1080p → 720p → 480p and stops there', () {
      expect(LiveCaptureProfile.ladder, [
        LiveCaptureProfile.fullHd,
        LiveCaptureProfile.hd,
        LiveCaptureProfile.sd,
      ]);
    });

    test('every tier is a true 16:9 video mode, never a 4:3 photo format', () {
      for (final profile in LiveCaptureProfile.ladder) {
        final ratio = profile.width / profile.height;
        expect((ratio - 16 / 9).abs() < 0.02, isTrue, reason: profile.label);
      }
    });

    test('no tier drops below the 854x480 publish floor', () {
      for (final profile in LiveCaptureProfile.ladder) {
        expect(profile.width, greaterThanOrEqualTo(854));
        expect(profile.height, greaterThanOrEqualTo(480));
      }
    });

    test('fallbacks start at the chosen tier and walk down', () {
      expect(LiveCaptureProfile.fullHd.fallbacks, [
        LiveCaptureProfile.fullHd,
        LiveCaptureProfile.hd,
        LiveCaptureProfile.sd,
      ]);
      expect(LiveCaptureProfile.hd.fallbacks, [
        LiveCaptureProfile.hd,
        LiveCaptureProfile.sd,
      ]);
      expect(LiveCaptureProfile.sd.fallbacks, [LiveCaptureProfile.sd]);
    });

    test('bitrate ceiling grows with resolution', () {
      expect(
        LiveCaptureProfile.fullHd.maxBitrate,
        greaterThan(LiveCaptureProfile.hd.maxBitrate),
      );
      expect(
        LiveCaptureProfile.hd.maxBitrate,
        greaterThan(LiveCaptureProfile.sd.maxBitrate),
      );
    });
  });

  group('LiveVideoQualityPreference', () {
    tearDown(() {
      LiveVideoQualityPreference.instance.resetForTest();
    });

    test('defaults to 720p until a device proves it can sustain more', () {
      // 1080p is raised at runtime by resolveDeviceDefault(), and only on
      // hardware that passes the capability probe — never as a bare default.
      expect(
        LiveVideoQualityPreference.instance.profile,
        LiveCaptureProfile.hd,
      );
    });

    test('a host choice is not overruled by a later capability probe', () async {
      final preference = LiveVideoQualityPreference.instance;
      preference.select(LiveCaptureProfile.sd);
      await preference.resolveDeviceDefault();

      expect(preference.profile, LiveCaptureProfile.sd);
    });

    test('selecting a tier notifies listeners once', () {
      final preference = LiveVideoQualityPreference.instance;
      var notifications = 0;
      void listener() => notifications++;

      preference.addListener(listener);
      // Must differ from the default, or the first select is a no-op and
      // there is nothing to notify about.
      preference.select(LiveCaptureProfile.fullHd);
      preference.select(LiveCaptureProfile.fullHd);
      preference.removeListener(listener);

      expect(notifications, 1);
      expect(preference.profile, LiveCaptureProfile.fullHd);
    });
  });
}
