import 'dart:io';

import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_media_widgets.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:bimobondapp/core/widgets/video_post_preview_placeholder.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style cover preview beside the description.
class AddPostCoverPreview extends StatefulWidget {
  const AddPostCoverPreview({
    required this.file,
    required this.onEdit,
    required this.onAdd,
    super.key,
  });

  final File? file;
  final VoidCallback onEdit;
  final VoidCallback onAdd;

  @override
  State<AddPostCoverPreview> createState() => _AddPostCoverPreviewState();
}

class _AddPostCoverPreviewState extends State<AddPostCoverPreview> {
  File? _videoThumb;

  @override
  void initState() {
    super.initState();
    _maybeLoadThumb();
  }

  @override
  void didUpdateWidget(AddPostCoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file?.path != widget.file?.path) {
      _videoThumb = null;
      _maybeLoadThumb();
    }
  }

  Future<void> _maybeLoadThumb() async {
    final file = widget.file;
    if (file == null || !addPostIsVideoFile(file)) return;
    final thumb = await VideoThumbnailUtils.generateThumbnailFile(
      file,
      maxHeight: 320,
    );
    if (mounted) setState(() => _videoThumb = thumb);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final file = widget.file;
    final isVideo = file != null && addPostIsVideoFile(file);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: file == null ? widget.onAdd : widget.onEdit,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 100,
            height: 132,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (file == null)
                  ColoredBox(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF2A2A2D)
                        : const Color(0xFFF1F1F2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.plus,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.45,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.mediaLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isVideo)
                  (_videoThumb != null
                      ? Image.file(_videoThumb!, fit: BoxFit.cover)
                      : const VideoPostPreviewPlaceholder(
                          iconSize: 28,
                          icon: LucideIcons.play,
                        ))
                else
                  Image.file(file, fit: BoxFit.cover),
                if (file != null) ...[
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Text(
                      l10n.previewLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          l10n.editCoverLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
