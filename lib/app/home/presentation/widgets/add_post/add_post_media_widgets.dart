import 'dart:io';

import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/video_post_preview_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

bool addPostIsVideoFile(File file) {
  final ext = file.path.toLowerCase().split('?').first;
  return MediaUtils.videoExtensions.any((e) => ext.endsWith(e));
}

class AddPostMediaCountChip extends StatelessWidget {
  const AddPostMediaCountChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p10,
        vertical: AppSizes.p4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSizes.p12),
      ),
      child: CustomText(
        label,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

class AddPostAddMediaTile extends StatelessWidget {
  const AddPostAddMediaTile({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 90,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Icon(
          LucideIcons.plus,
          size: 24,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class AddPostMediaTile extends StatelessWidget {
  const AddPostMediaTile({
    required this.file,
    required this.onRemove,
    super.key,
  });

  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isVideo = addPostIsVideoFile(file);
    return SizedBox(
      width: 80,
      height: 90,
      child: Stack(
        children: [
          Container(
            width: 80,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            clipBehavior: Clip.antiAlias,
            child: isVideo
                ? const VideoPostPreviewPlaceholder(
                    iconSize: 28,
                    icon: LucideIcons.play,
                  )
                : Image.file(file, fit: BoxFit.cover, width: 80, height: 90),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddPostMediaStrip extends StatelessWidget {
  const AddPostMediaStrip({
    required this.files,
    required this.maxFiles,
    required this.onAddTap,
    required this.onRemoveAt,
    super.key,
  });

  final List<File> files;
  final int maxFiles;
  final VoidCallback onAddTap;
  final ValueChanged<int> onRemoveAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (files.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.p8),
            child: Align(
              alignment: Alignment.centerRight,
              child: AddPostMediaCountChip(
                label: '${files.length}/$maxFiles',
              ),
            ),
          ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: files.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.p8),
            itemBuilder: (context, index) {
              if (index == files.length) {
                return AddPostAddMediaTile(onTap: onAddTap);
              }
              return AddPostMediaTile(
                file: files[index],
                onRemove: () => onRemoveAt(index),
              );
            },
          ),
        ),
      ],
    );
  }
}
