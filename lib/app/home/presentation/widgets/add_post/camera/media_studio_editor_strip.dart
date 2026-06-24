import 'dart:io';

import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Bottom strip of selected media thumbnails in the studio editor.
class MediaStudioEditorStrip extends StatelessWidget {
  const MediaStudioEditorStrip({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<GalleryMediaItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _thumbSize = 56.0;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: _thumbSize + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _thumbSize,
              height: _thumbSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _MediaThumb(file: item.file, isVideo: item.isVideo),
                  if (item.isVideo)
                    const Align(
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.play,
                        color: Colors.white,
                        size: 20,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 6),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.file, required this.isVideo});

  final File file;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    if (isVideo) {
      return _VideoThumb(file: file);
    }
    return Image.file(file, fit: BoxFit.cover);
  }
}

class _VideoThumb extends StatefulWidget {
  const _VideoThumb({required this.file});

  final File file;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  File? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final thumb = await VideoThumbnailUtils.generateThumbnailFile(
      widget.file,
      maxHeight: 120,
    );
    if (mounted) setState(() => _thumb = thumb);
  }

  @override
  Widget build(BuildContext context) {
    if (_thumb != null) {
      return Image.file(_thumb!, fit: BoxFit.cover);
    }
    return const ColoredBox(
      color: Color(0xFF1A1A1A),
      child: Center(
        child: Icon(LucideIcons.film, color: Colors.white38, size: 20),
      ),
    );
  }
}
