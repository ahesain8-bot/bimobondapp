import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/pages/sound_detail_screen.dart';
import 'package:bimobondapp/core/routes/app_router.dart';
import 'package:flutter/material.dart';

/// Opens the TikTok-style sound page above modals (e.g. the sound picker sheet).
/// Returns a [SoundEntity] when the user confirms "Use this sound" in [pickMode].
Future<SoundEntity?> openSoundDetail(
  BuildContext context, {
  required String soundId,
  bool pickMode = false,
  SoundEntity? preview,
}) {
  if (soundId.isEmpty) return Future.value(null);

  final navigatorContext =
      AppRouter.rootNavigatorKey.currentContext ?? context;

  return Navigator.of(navigatorContext, rootNavigator: true).push<SoundEntity>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SoundDetailScreen(
        soundId: soundId,
        pickMode: pickMode,
        previewSound: preview,
      ),
    ),
  );
}

/// Pops a sound detail page opened via [openSoundDetail].
void popSoundDetail(BuildContext context, [SoundEntity? result]) {
  Navigator.of(context, rootNavigator: true).pop(result);
}
