import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/pages/sound_detail_screen.dart';
import 'package:bimobondapp/core/routes/app_router.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:flutter/material.dart';

/// Opens the TikTok-style sound page above modals (e.g. the sound picker sheet).
/// Returns a [SoundEntity] when the user confirms "Use this sound" in [pickMode].
Future<SoundEntity?> openSoundDetail(
  BuildContext context, {
  required String soundId,
  bool pickMode = false,
  SoundEntity? preview,
}) async {
  if (soundId.isEmpty) return null;

  final navigatorContext =
      AppRouter.rootNavigatorKey.currentContext ?? context;

  FeedPlaybackGate.instance.setBlocked(true);
  try {
    return await Navigator.of(navigatorContext, rootNavigator: true)
        .push<SoundEntity>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SoundDetailScreen(
          soundId: soundId,
          pickMode: pickMode,
          previewSound: preview,
        ),
      ),
    );
  } finally {
    FeedPlaybackGate.instance.syncFromRouter();
  }
}

/// Pops a sound detail page opened via [openSoundDetail].
void popSoundDetail(BuildContext context, [SoundEntity? result]) {
  Navigator.of(context, rootNavigator: true).pop(result);
}
