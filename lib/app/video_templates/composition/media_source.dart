import 'dart:io';

import 'package:bimobondapp/app/video_templates/composition/image_media_source.dart';
import 'package:bimobondapp/app/video_templates/composition/video_media_source.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';

/// Unified media input for [TemplateCompositionEngine] (Phase 4).
///
/// Image and video share one contract — the composition engine never branches
/// on template “kind”; it only consumes [MediaSource] instances.
abstract class MediaSource {
  String get id;
  String get kind;
  File get file;
  bool get isPrepared;

  Future<void> prepare();

  /// Effective on-timeline duration for this slot fill.
  Future<Duration> getDuration();

  /// Map composition-local time (0…duration) → source media time.
  Duration mapLocalTime(Duration local);

  Future<void> dispose();

  /// Factory: pick Image vs Video implementation from a local file.
  static MediaSource fromFill({
    required VideoTemplateSlotEntity slot,
    required SlotFillEntry fill,
    required File file,
  }) {
    // Honor gallery/camera VIDEO hint on [fill], not only path extension.
    final isVideo = fill.isLocalVideo || VideoThumbnailUtils.isVideoFile(file);
    final holdSeconds = UserProjectSlotMapper.resolveSlotDuration(slot, fill);
    if (isVideo) {
      return VideoMediaSource(
        id: slot.id,
        file: file,
        trimStart: fill.trimStart,
        trimEnd: fill.trimEnd,
        speed: fill.speed,
        volume: fill.volume,
        targetDurationSeconds: holdSeconds,
      );
    }
    return ImageMediaSource(
      id: slot.id,
      file: file,
      holdDuration: Duration(
        milliseconds: (holdSeconds * 1000).round().clamp(200, 30000),
      ),
    );
  }
}
