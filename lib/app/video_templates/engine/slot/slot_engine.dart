import 'dart:io';
import 'dart:math' as math;

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:equatable/equatable.dart';

/// Local user media bound to a [VideoTemplateSlotEntity] (never mutates template).
class SlotFillEntry extends Equatable {
  const SlotFillEntry({
    required this.slotId,
    required this.slotIndex,
    this.localFile,
    this.userAssetUrl,
    this.mediaKind,
    this.trimStart,
    this.trimEnd,
    this.speed = 1,
    this.rotation = 0,
    this.scale = 1,
    this.volume = 1,
    this.opacity = 1,
    this.reversed = false,
    this.freeze = false,
    this.reduceNoise = false,
    this.beautify = false,
    this.cutout = false,
    this.maskType,
    this.voiceEffect,
  });

  final String slotId;
  final int slotIndex;
  final File? localFile;
  final String? userAssetUrl;
  /// `IMAGE` | `VIDEO` from gallery/camera when path extension is unreliable.
  final String? mediaKind;
  final double? trimStart;
  final double? trimEnd;
  final double speed;
  final double rotation;
  final double scale;
  final double volume;
  final double opacity;
  final bool reversed;
  final bool freeze;
  final bool reduceNoise;
  final bool beautify;
  final bool cutout;
  /// CapCut-style mask id for encode (`circle`, `rect`, …).
  final String? maskType;
  /// CapCut-style voice effect id for encode.
  final String? voiceEffect;

  bool get hasMedia =>
      (localFile != null && localFile!.path.isNotEmpty) ||
      (userAssetUrl != null && userAssetUrl!.trim().isNotEmpty);

  bool get isLocalVideo {
    final kind = mediaKind?.trim().toUpperCase();
    if (kind == 'VIDEO') return true;
    if (kind == 'IMAGE' || kind == 'PHOTO') return false;
    return localFile != null && VideoThumbnailUtils.isVideoFile(localFile!);
  }

  bool get isLocalImage => localFile != null && !isLocalVideo;

  SlotFillEntry copyWith({
    File? localFile,
    String? userAssetUrl,
    String? mediaKind,
    double? trimStart,
    double? trimEnd,
    double? speed,
    double? rotation,
    double? scale,
    double? volume,
    double? opacity,
    bool? reversed,
    bool? freeze,
    bool? reduceNoise,
    bool? beautify,
    bool? cutout,
    String? maskType,
    String? voiceEffect,
    bool clearFile = false,
    bool clearUrl = false,
    bool clearMask = false,
    bool clearVoiceEffect = false,
  }) {
    return SlotFillEntry(
      slotId: slotId,
      slotIndex: slotIndex,
      localFile: clearFile ? null : (localFile ?? this.localFile),
      userAssetUrl: clearUrl ? null : (userAssetUrl ?? this.userAssetUrl),
      mediaKind: mediaKind ?? this.mediaKind,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      speed: speed ?? this.speed,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      volume: volume ?? this.volume,
      opacity: opacity ?? this.opacity,
      reversed: reversed ?? this.reversed,
      freeze: freeze ?? this.freeze,
      reduceNoise: reduceNoise ?? this.reduceNoise,
      beautify: beautify ?? this.beautify,
      cutout: cutout ?? this.cutout,
      maskType: clearMask ? null : (maskType ?? this.maskType),
      voiceEffect:
          clearVoiceEffect ? null : (voiceEffect ?? this.voiceEffect),
    );
  }

  /// Payload for `PATCH …/slots/:slotId` (IMAGE slots omit trim/speed).
  Map<String, dynamic> toPatchBody({required bool isImageSlot}) {
    return {
      if (userAssetUrl != null) 'userAssetUrl': userAssetUrl,
      if (!isImageSlot && trimStart != null) 'trimStart': trimStart,
      if (!isImageSlot && trimEnd != null) 'trimEnd': trimEnd,
      if (!isImageSlot) 'speed': speed,
      'rotation': rotation,
      'scale': scale,
      if (!isImageSlot) 'volume': volume,
      'opacity': opacity,
      if (!isImageSlot) 'reversed': reversed,
      if (!isImageSlot) 'freeze': freeze,
      if (!isImageSlot) 'reduceNoise': reduceNoise,
      'beautify': beautify,
      'cutout': cutout,
      if (maskType != null) 'maskType': maskType,
      if (voiceEffect != null) 'voiceEffect': voiceEffect,
    };
  }

  factory SlotFillEntry.fromProjectSlot(VideoTemplateProjectSlotEntity slot) {
    return SlotFillEntry(
      slotId: slot.slotId ?? slot.id,
      slotIndex: slot.slotIndex,
      userAssetUrl: slot.userAssetUrl,
      trimStart: slot.trimStart,
      trimEnd: slot.trimEnd,
      speed: slot.speed,
      rotation: slot.rotation,
      scale: slot.scale,
      volume: slot.volume,
    );
  }

  @override
  List<Object?> get props => [
        slotId,
        slotIndex,
        localFile?.path,
        userAssetUrl,
        mediaKind,
        trimStart,
        trimEnd,
        speed,
        rotation,
        scale,
        volume,
        opacity,
        reversed,
        freeze,
        reduceNoise,
        beautify,
        cutout,
        maskType,
        voiceEffect,
      ];
}

/// Phase 3 — generic slot fill / validate against recipe slots.
class SlotEngine {
  SlotEngine({required this.recipe});

  final VideoTemplateRecipeEntity recipe;

  List<VideoTemplateSlotEntity> get slots {
    if (recipe.slots.isNotEmpty) {
      return List<VideoTemplateSlotEntity>.from(recipe.slots)
        ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    }
    // Synthetic slots when recipe only has slotCount.
    final n = recipe.applySlotCount;
    final primary = recipe.primarySlotType.toUpperCase();
    final mixed = primary == 'MIXED';
    final type = primary == 'VIDEO'
        ? TemplateSlotMediaTypes.video
        : TemplateSlotMediaTypes.image;
    final accepted = mixed
        ? const [TemplateSlotMediaTypes.image, TemplateSlotMediaTypes.video]
        : <String>[type];
    return List.generate(
      n,
      (i) => VideoTemplateSlotEntity(
        id: 'synthetic_$i',
        slotIndex: i,
        type: type,
        acceptedTypes: accepted,
        durationSeconds: recipe.duration != null && n > 0
            ? recipe.duration! / n
            : 3,
        required: true,
      ),
    );
  }

  /// Empty fill map keyed by slot id.
  Map<String, SlotFillEntry> emptyFills() {
    final map = <String, SlotFillEntry>{};
    for (final s in slots) {
      map[s.id] = SlotFillEntry(slotId: s.id, slotIndex: s.slotIndex);
    }
    return map;
  }

  /// Alias used by composition / select callers.
  Map<String, SlotFillEntry> fillsFromFiles(
    List<File> files, {
    Map<String, SlotFillEntry>? existing,
    /// Parallel to [files]: true when gallery/camera marked the item as video
    /// (even if the path has no `.mp4` extension).
    List<bool>? isVideoHints,
  }) =>
      fillFromFiles(files, existing: existing, isVideoHints: isVideoHints);

  /// Assign local files to slots (photos + videos). Prefers type match, then
  /// repeat-pads so one clip can fill a multi-slot template.
  Map<String, SlotFillEntry> fillFromFiles(
    List<File> files, {
    Map<String, SlotFillEntry>? existing,
    List<bool>? isVideoHints,
  }) {
    final ordered = slots;
    final images = <({File file, String kind})>[];
    final videos = <({File file, String kind})>[];
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      if (f.path.isEmpty) continue;
      final hintedVideo =
          isVideoHints != null && i < isVideoHints.length && isVideoHints[i];
      final asVideo = hintedVideo || VideoThumbnailUtils.isVideoFile(f);
      final entry = (file: f, kind: asVideo ? 'VIDEO' : 'IMAGE');
      if (asVideo) {
        videos.add(entry);
      } else {
        images.add(entry);
      }
    }
    final any = [...images, ...videos];
    final out = existing != null
        ? Map<String, SlotFillEntry>.from(existing)
        : emptyFills();
    var imageCursor = 0;
    var videoCursor = 0;
    var anyCursor = 0;
    ({File file, String kind})? nextFrom(
      List<({File file, String kind})> pool,
      int cursor,
    ) {
      if (pool.isEmpty) return null;
      return pool[cursor % pool.length];
    }

    for (var i = 0; i < ordered.length; i++) {
      final slot = ordered[i];
      ({File file, String kind})? picked;
      if (slot.isVideoOnly) {
        picked = nextFrom(videos, videoCursor++);
        picked ??= nextFrom(any, anyCursor++);
      } else if (slot.isImageOnly) {
        picked = nextFrom(images, imageCursor++);
        // Photo templates also accept a video clip (same dump path).
        picked ??= nextFrom(videos, videoCursor++);
        picked ??= nextFrom(any, anyCursor++);
      } else if (slot.acceptsVideo) {
        picked = nextFrom(videos, videoCursor++);
        picked ??= nextFrom(images, imageCursor++);
        picked ??= nextFrom(any, anyCursor++);
      } else {
        picked = nextFrom(images, imageCursor++);
        picked ??= nextFrom(any, anyCursor++);
      }
      final prev = out[slot.id];
      out[slot.id] = SlotFillEntry(
        slotId: slot.id,
        slotIndex: slot.slotIndex,
        localFile: picked?.file,
        mediaKind: picked?.kind ?? prev?.mediaKind,
        userAssetUrl: prev?.userAssetUrl,
        trimStart: prev?.trimStart,
        trimEnd: prev?.trimEnd,
        speed: prev?.speed ?? 1,
        rotation: prev?.rotation ?? 0,
        scale: prev?.scale ?? 1,
        volume: prev?.volume ?? 1,
      );
    }
    return out;
  }

  /// Apply beat-sync trim defaults for VIDEO slots.
  Map<String, SlotFillEntry> applyBeatSyncTrims(
    Map<String, SlotFillEntry> fills,
  ) {
    final beats = recipe.beatTimestamps;
    final out = Map<String, SlotFillEntry>.from(fills);
    for (final slot in slots) {
      final fill = out[slot.id];
      if (fill == null || !fill.hasMedia || !fill.isLocalVideo) continue;
      if (!slot.syncToBeat || slot.beatIndex == null) continue;
      final bi = slot.beatIndex!;
      if (bi < 0 || bi >= beats.length) continue;
      final start = beats[bi];
      double? end;
      if (bi + 1 < beats.length) {
        end = beats[bi + 1];
      } else if (slot.resolvedDurationSeconds > 0) {
        end = start + slot.resolvedDurationSeconds;
      }
      out[slot.id] = fill.copyWith(trimStart: start, trimEnd: end, speed: 1);
    }
    return out;
  }

  SlotValidationResult validate(Map<String, SlotFillEntry> fills) {
    final missing = <String>[];
    final typeMismatches = <String>[];
    final durationIssues = <String>[];

    for (final slot in slots) {
      if (!slot.required) continue;
      final fill = fills[slot.id];
      if (fill == null || !fill.hasMedia) {
        missing.add(slot.id);
        continue;
      }
      if (fill.localFile != null) {
        final kind = fill.isLocalVideo
            ? MediaSourceKinds.video
            : MediaSourceKinds.image;
        if (!slot.acceptsMediaKind(kind)) {
          typeMismatches.add(slot.id);
        }
      }
      if (!slot.isImage &&
          fill.trimStart != null &&
          fill.trimEnd != null &&
          fill.trimEnd! <= fill.trimStart!) {
        durationIssues.add(slot.id);
      }
      final len = slot.resolvedDurationSeconds;
      if (len > 0 && slot.minDuration != null && len < slot.minDuration!) {
        durationIssues.add(slot.id);
      }
      if (slot.maxDuration != null &&
          len > 0 &&
          len > slot.maxDuration!) {
        durationIssues.add(slot.id);
      }
    }

    return SlotValidationResult(
      missingRequiredSlotIds: missing,
      typeMismatchSlotIds: typeMismatches,
      durationIssueSlotIds: durationIssues,
    );
  }

  List<File> localFilesInOrder(Map<String, SlotFillEntry> fills) {
    final files = <File>[];
    for (final slot in slots) {
      final f = fills[slot.id]?.localFile;
      if (f != null) files.add(f);
    }
    return files;
  }

  /// UI label helper (respects `acceptedTypes` mixed slots).
  static String slotActionLabel(VideoTemplateSlotEntity slot) =>
      slot.pickerActionLabel;

  static String slotTitle(VideoTemplateSlotEntity slot) =>
      'Slot ${slot.slotIndex + 1}';
}

class SlotValidationResult {
  const SlotValidationResult({
    this.missingRequiredSlotIds = const [],
    this.typeMismatchSlotIds = const [],
    this.durationIssueSlotIds = const [],
  });

  final List<String> missingRequiredSlotIds;
  final List<String> typeMismatchSlotIds;
  final List<String> durationIssueSlotIds;

  bool get isValid =>
      missingRequiredSlotIds.isEmpty && durationIssueSlotIds.isEmpty;

  bool get canExport => isValid;

  String? get firstError {
    if (missingRequiredSlotIds.isNotEmpty) {
      return 'Fill all required slots';
    }
    if (durationIssueSlotIds.isNotEmpty) {
      return 'Fix slot trim / duration';
    }
    if (typeMismatchSlotIds.isNotEmpty) {
      return 'Media type does not match slot';
    }
    return null;
  }
}

/// Phase 4 — map fills ↔ UserProjectSlot without mutating VideoTemplate.
class UserProjectSlotMapper {
  UserProjectSlotMapper._();

  static List<SlotFillEntry> fromProject(VideoTemplateProjectEntity project) {
    final list = project.slots
        .map(SlotFillEntry.fromProjectSlot)
        .toList(growable: false);
    list.sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    return list;
  }

  static Map<String, SlotFillEntry> mergeProjectIntoFills({
    required Map<String, SlotFillEntry> fills,
    required VideoTemplateProjectEntity project,
  }) {
    final out = Map<String, SlotFillEntry>.from(fills);
    for (final ps in project.slots) {
      final key = ps.slotId ?? ps.id;
      if (key.isEmpty) continue;
      final prev = out[key];
      out[key] = SlotFillEntry(
        slotId: key,
        slotIndex: ps.slotIndex,
        localFile: prev?.localFile,
        userAssetUrl: ps.userAssetUrl ?? prev?.userAssetUrl,
        trimStart: ps.trimStart ?? prev?.trimStart,
        trimEnd: ps.trimEnd ?? prev?.trimEnd,
        speed: ps.speed,
        rotation: ps.rotation,
        scale: ps.scale,
        volume: ps.volume,
      );
    }
    return out;
  }

  static double resolveSlotDuration(
    VideoTemplateSlotEntity slot,
    SlotFillEntry? fill,
  ) {
    if (fill?.trimStart != null &&
        fill?.trimEnd != null &&
        fill!.trimEnd! > fill.trimStart!) {
      final raw = fill.trimEnd! - fill.trimStart!;
      final speed = fill.speed <= 0 ? 1.0 : fill.speed;
      return math.max(0.05, raw / speed);
    }
    // IMAGE fills (and IMAGE slots without trim) use the image hold duration
    // (default 5s) so preview timeline and export share one clock.
    final isImageHold = fill == null ||
        fill.isLocalImage ||
        (!fill.isLocalVideo && (slot.isImage || slot.isImageOnly));
    if (isImageHold) {
      return math.max(0.05, slot.imageHoldDurationSeconds);
    }
    return math.max(
      0.05,
      slot.resolvedDurationSeconds > 0 ? slot.resolvedDurationSeconds : 3.0,
    );
  }
}
