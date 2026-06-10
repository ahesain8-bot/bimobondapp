import 'dart:io';

import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/video_post_preview_placeholder.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

bool addPostIsVideoFile(File file) => VideoThumbnailUtils.isVideoFile(file);

const double _tileWidth = 108;
const double _tileHeight = 132;

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
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.14),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: CustomText(
        label,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
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
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          width: _tileWidth,
          height: _tileHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
            color: colorScheme.primary.withValues(alpha: 0.06),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.plus,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSizes.p8),
              CustomText(
                AppLocalizations.of(context)!.mediaLabel,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ],
          ),
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
      width: _tileWidth,
      height: _tileHeight,
      child: Stack(
        children: [
          Container(
            width: _tileWidth,
            height: _tileHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: isVideo
                ? const VideoPostPreviewPlaceholder(
                    iconSize: 32,
                    icon: LucideIcons.play,
                  )
                : Image.file(
                    file,
                    fit: BoxFit.cover,
                    width: _tileWidth,
                    height: _tileHeight,
                  ),
          ),
          if (isVideo)
            Positioned(
              left: AppSizes.p8,
              bottom: AppSizes.p8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.p8,
                  vertical: AppSizes.p4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.play, size: 10, color: Colors.white),
                    SizedBox(width: AppSizes.p4),
                    CustomText(
                      'Video',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: AppSizes.p6,
            right: AppSizes.p6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.62),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRemove,
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: Icon(LucideIcons.x, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddPostMediaEmptyState extends StatelessWidget {
  const AddPostMediaEmptyState({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          width: double.infinity,
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.28),
              width: 1.5,
            ),
            color: colorScheme.primary.withValues(alpha: 0.05),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.imagePlus,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: AppSizes.p12),
              CustomText(
                l10n.tapToSelectMedia,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: AppSizes.p4),
              CustomText(
                l10n.mediaLabel,
                fontSize: 12,
                variant: TextVariant.secondary,
              ),
            ],
          ),
        ),
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
    if (files.isEmpty) {
      return AddPostMediaEmptyState(onTap: onAddTap);
    }

    return SizedBox(
          height: _tileHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: files.length + (files.length < maxFiles ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.p10),
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
        );
  }
}
