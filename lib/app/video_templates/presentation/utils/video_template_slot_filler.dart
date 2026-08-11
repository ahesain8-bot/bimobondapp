import 'dart:io';
import 'dart:math' as math;

import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:path_provider/path_provider.dart';

/// Fills a photo-dump / carousel template by cycling existing media.
///
/// Photo dump needs **at least 5 slots**. One photo or one video is repeated
/// (as unique temp copies) until that count is met.
class VideoTemplateSlotFiller {
  VideoTemplateSlotFiller._();

  /// Minimum slots for photo-dump / photo-carousel templates.
  static const int minPhotoDumpSlots = 5;

  /// Resolves how many slots to fill: at least [minPhotoDumpSlots], capped at 99.
  static int effectiveSlotCount(int slotCount) {
    final raw = slotCount <= 0 ? minPhotoDumpSlots : slotCount;
    return math.max(raw, minPhotoDumpSlots).clamp(1, 99);
  }

  /// Prefer recipe.applySlotCount; otherwise photo-dump min of 5.
  static int slotsForSelection({
    int slotCount = 0,
    int? recipeApplySlotCount,
  }) {
    if (recipeApplySlotCount != null && recipeApplySlotCount > 0) {
      return recipeApplySlotCount.clamp(1, 99);
    }
    return effectiveSlotCount(slotCount);
  }

  static List<T> padByRepeat<T>(List<T> source, int slotCount) {
    if (source.isEmpty) return const [];
    final need = slotCount.clamp(1, 99);
    if (source.length >= need) return List<T>.from(source.take(need));
    return List<T>.generate(need, (i) => source[i % source.length]);
  }

  static List<File> padFiles(List<File> files, int slotCount) =>
      padByRepeat(files, slotCount);

  /// Pads photos **and** videos (one clip is enough). Sync — shared paths.
  /// Pass an already-resolved count (e.g. [slotsForSelection]).
  static List<GalleryMediaItem> padGalleryItems(
    List<GalleryMediaItem> items,
    int slotCount,
  ) {
    if (items.isEmpty) return items;
    return padByRepeat(items, slotCount);
  }

  /// Like [padGalleryItems] but writes unique temp copies so each slot is a
  /// real file (uploads / carousel UI treat them as separate media).
  static Future<List<GalleryMediaItem>> padGalleryItemsUnique(
    List<GalleryMediaItem> items,
    int slotCount,
  ) async {
    if (items.isEmpty) return items;
    final need = slotCount.clamp(1, 99);
    if (items.length >= need) {
      return List<GalleryMediaItem>.from(items.take(need));
    }
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final out = <GalleryMediaItem>[];
    for (var i = 0; i < need; i++) {
      final src = items[i % items.length];
      if (i < items.length) {
        out.add(src);
        continue;
      }
      final copy = await _copyToTemp(
        src.file,
        dir: dir,
        stamp: stamp,
        index: i,
      );
      out.add(
        GalleryMediaItem(
          file: copy,
          type: src.isVideo ? 'VIDEO' : 'IMAGE',
        ),
      );
    }
    return out;
  }

  /// Expands editor states to [slotCount] slots with unique files.
  /// Pass [VideoTemplateSlotFiller.effectiveSlotCount] when recipe is unknown.
  static Future<List<MediaItemEditState>> padEditStates(
    List<MediaItemEditState> states,
    int slotCount,
  ) async {
    if (states.isEmpty) return states;
    final need = slotCount.clamp(1, 99);
    if (states.length >= need) {
      return List<MediaItemEditState>.from(states.take(need));
    }

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final out = <MediaItemEditState>[];
    for (var i = 0; i < need; i++) {
      final src = states[i % states.length];
      final File file;
      if (i < states.length) {
        file = src.sourceFile;
      } else {
        file = await _copyToTemp(
          src.sourceFile,
          dir: dir,
          stamp: stamp,
          index: i,
        );
      }
      out.add(
        MediaItemEditState(
          item: GalleryMediaItem(
            file: file,
            type: src.isVideo ? 'VIDEO' : 'IMAGE',
          ),
          filter: src.filter,
          effectSlug: src.effectSlug,
          beautyEnabled: src.beautyEnabled,
          filterCategory: src.filterCategory,
          arFilterId: src.arFilterId,
          arColorCategoryId: src.arColorCategoryId,
          arFilterIntensity: src.arFilterIntensity,
          faceSaturation: src.faceSaturation,
          faceBrightness: src.faceBrightness,
          faceContrast: src.faceContrast,
          faceExposure: src.faceExposure,
          faceWhiteBalance: src.faceWhiteBalance,
          faceHighlights: src.faceHighlights,
          faceShadows: src.faceShadows,
          faceNose: src.faceNose,
          alreadyBaked: src.alreadyBaked,
          bakedArFilterId: src.bakedArFilterId,
          textOverlays:
              i < states.length ? List.of(src.textOverlays) : const [],
          trimSegments: List.of(src.trimSegments),
          croppedFile: i < states.length ? src.croppedFile : null,
        ),
      );
    }
    return out;
  }

  static String _extensionOf(String path) {
    final slash = path.replaceAll('\\', '/').lastIndexOf('/');
    final name = slash >= 0 ? path.substring(slash + 1) : path;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return '';
    return name.substring(dot);
  }

  static Future<File> _copyToTemp(
    File source, {
    required Directory dir,
    required int stamp,
    required int index,
  }) async {
    final ext = _extensionOf(source.path);
    final dest = File(
      '${dir.path}${Platform.pathSeparator}vt_slot_${stamp}_$index$ext',
    );
    if (await dest.exists()) {
      try {
        await dest.delete();
      } catch (_) {}
    }
    return source.copy(dest.path);
  }
}
