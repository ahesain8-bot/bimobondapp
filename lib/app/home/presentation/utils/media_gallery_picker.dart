import 'dart:io';

import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:image_picker/image_picker.dart';

class GalleryMediaItem {
  const GalleryMediaItem({required this.file, required this.type});

  final File file;
  final String type;

  bool get isVideo =>
      type == 'VIDEO' || VideoThumbnailUtils.isVideoFile(file);
}

/// Picks multiple images and/or videos from the device gallery.
class MediaGalleryPicker {
  MediaGalleryPicker._();

  static final ImagePicker _picker = ImagePicker();

  static String typeForPath(String path) {
    return VideoThumbnailUtils.isVideoFile(File(path)) ? 'VIDEO' : 'IMAGE';
  }

  static String typeForXFile(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (mime != null && mime.startsWith('video/')) return 'VIDEO';
    if (mime != null && mime.startsWith('image/')) return 'IMAGE';
    return typeForPath(file.path);
  }

  static List<GalleryMediaItem> fromXFiles(List<XFile> files) {
    return files
        .map(
          (file) => GalleryMediaItem(
            file: File(file.path),
            type: typeForXFile(file),
          ),
        )
        .toList(growable: false);
  }

  static Future<List<GalleryMediaItem>> pickImages({int? limit}) async {
    final picked = await _picker.pickMultiImage(limit: limit);
    return fromXFiles(picked);
  }

  static Future<List<GalleryMediaItem>> pickSingleImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return const [];
    return fromXFiles([picked]);
  }

  static Future<List<GalleryMediaItem>> pickVideos({int? limit}) async {
    final picked = await _picker.pickMultiVideo(limit: limit);
    return fromXFiles(picked);
  }

  static Future<List<GalleryMediaItem>> pickSingleVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return const [];
    return fromXFiles([picked]);
  }

  /// Images and videos in one native multi-select sheet (iOS 14+, Android).
  static Future<List<GalleryMediaItem>> pickMixed({int? limit}) async {
    final picked = await _picker.pickMultipleMedia(limit: limit);
    return fromXFiles(picked);
  }
}
