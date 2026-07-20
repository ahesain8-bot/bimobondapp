import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';

/// Result of [SoundPickerSheet]: chosen track and optional trim start.
class SoundPickResult {
  const SoundPickResult({
    required this.sound,
    this.offset = Duration.zero,
    this.window = const Duration(seconds: 15),
    this.muteOriginal = false,
    this.didTrim = false,
    this.needsTrim = false,
  });

  final SoundEntity sound;
  final Duration offset;

  /// Selected period length (default 15s TikTok-style clip).
  final Duration window;

  final bool muteOriginal;

  /// True when the user confirmed via the trim sheet (scissors → check).
  final bool didTrim;

  /// Internal: scissors was tapped; [SoundPickerSheet.show] should open trim
  /// after the catalog sheet closes (avoids nested modal apply bugs).
  final bool needsTrim;
}
