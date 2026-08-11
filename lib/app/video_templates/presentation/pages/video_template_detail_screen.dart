import 'dart:async';

import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_studio_preview.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/usecases/video_templates_usecases.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/di/video_templates_injector.dart'
    as vt_di;
import 'package:bimobondapp/app/video_templates/presentation/pages/video_template_editor_screen.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Template detail → pick one photo/video (TikTok) → all slots use that media.
class VideoTemplateDetailScreen extends StatefulWidget {
  const VideoTemplateDetailScreen({super.key, required this.card});

  final VideoTemplateCardEntity card;

  @override
  State<VideoTemplateDetailScreen> createState() =>
      _VideoTemplateDetailScreenState();
}

class _VideoTemplateDetailScreenState extends State<VideoTemplateDetailScreen> {
  bool _preparing = false;
  String? _error;
  PreparedVideoTemplateSession? _session;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _preparing = true;
      _error = null;
    });
    // Recipe first — don't block UI on preview MP4 download.
    final result = await vt_di.sl<PrepareVideoTemplateEditorUseCase>()(
      templateId: widget.card.id,
      card: widget.card,
      expectedVersion: widget.card.version,
      prefetchPreview: false,
      prefetchEditorAssets: false,
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _preparing = false;
        _error = f.message;
      }),
      (s) {
        setState(() {
          _preparing = false;
          _session = s;
        });
        unawaited(
          vt_di.sl<PrepareVideoTemplateEditorUseCase>()(
            templateId: widget.card.id,
            card: widget.card,
            expectedVersion: s.recipe.version,
            prefetchPreview: true,
            prefetchEditorAssets: false,
          ).then((r) {
            if (!mounted) return;
            r.fold((_) {}, (ready) {
              if (_session?.recipe.id == ready.recipe.id) {
                setState(() => _session = ready);
              }
            });
          }),
        );
      },
    );
  }

  /// TikTok: one gallery pick fills every slot with the same media.
  Future<void> _useTemplate() async {
    final session = _session;
    if (session == null) return;

    setState(() {
      _preparing = true;
      _error = null;
    });

    // Prefetch stickers/LUTs while gallery is open — don't await.
    unawaited(
      vt_di.sl<PrepareVideoTemplateEditorUseCase>()(
        templateId: widget.card.id,
        card: widget.card,
        expectedVersion: session.recipe.version,
        prefetchPreview: false,
        prefetchEditorAssets: true,
        forceRefresh: false,
      ),
    );

    final recipe = session.recipe;
    final slotEngine = SlotEngine(recipe: recipe);
    final slots = slotEngine.slots;
    final acceptsVideo = slots.any((s) => s.acceptsVideo);
    final acceptsImage = slots.any((s) => s.acceptsImage);

    final picked = await _pickMedia(
      acceptsVideo: acceptsVideo,
      acceptsImage: acceptsImage,
    );
    if (!mounted) return;
    if (picked == null) {
      setState(() => _preparing = false);
      return;
    }

    // Same file repeated across all slots (TikTok apply).
    var fills = slotEngine.fillFromFiles([picked.file]);
    fills = slotEngine.applyBeatSyncTrims(fills);

    final projectId =
        VideoTemplateProjectIds.normalizeServerId(session.selection.projectId);
    if (projectId == null) {
      unawaited(
        vt_di.sl<CreateVideoTemplateProjectUseCase>()(
          templateId: recipe.id,
          title: recipe.name,
        ),
      );
    }

    setState(() => _preparing = false);

    final selection = await Navigator.of(context).push<VideoTemplateSelection>(
      MaterialPageRoute(
        builder: (_) => VideoTemplateEditorScreen(
          recipe: recipe,
          card: widget.card,
          initialSelection: session.selection.copyWith(projectId: projectId),
          initialFills: fills,
          projectId: projectId,
        ),
      ),
    );
    if (selection != null && mounted) {
      Navigator.of(context).pop(selection);
    }
  }

  Future<GalleryMediaItem?> _pickMedia({
    required bool acceptsVideo,
    required bool acceptsImage,
  }) async {
    // Let user choose Photo or Video when both are allowed (TikTok sheet).
    if (acceptsVideo && acceptsImage) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF1C1C1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Apply template',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'One photo or video fills every clip',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                  ),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.image, color: Colors.white),
                  title: const Text(
                    'Photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(ctx, 'image'),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.video, color: Colors.white),
                  title: const Text(
                    'Video',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(ctx, 'video'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
      if (choice == null) return null;
      if (choice == 'video') {
        final items = await MediaGalleryPicker.pickVideos(limit: 1);
        return items.isEmpty ? null : items.first;
      }
      final items = await MediaGalleryPicker.pickImages(limit: 1);
      return items.isEmpty ? null : items.first;
    }

    if (acceptsVideo) {
      final items = await MediaGalleryPicker.pickVideos(limit: 1);
      return items.isEmpty ? null : items.first;
    }

    final items = await MediaGalleryPicker.pickImages(limit: 1);
    return items.isEmpty ? null : items.first;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final recipe = _session?.recipe;
    final previewFile = _session?.preview?.previewVideoFile;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (previewFile != null)
            MediaStudioPreview(
              key: ValueKey(previewFile.path),
              file: previewFile,
              isVideo: true,
              arFilterId: 'none',
              applyArColorPreview: false,
            )
          else if (card.coverUrl != null)
            SafeNetworkImage(imageUrl: card.coverUrl, fit: BoxFit.cover)
          else
            const ColoredBox(color: Colors.black),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (recipe != null)
                            '${recipe.applySlotCount} clips'
                          else if (card.slotCount > 0)
                            '${card.slotCount} clips',
                          if (card.duration != null)
                            '${card.duration!.toStringAsFixed(0)}s',
                          card.templateKind,
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            _preparing || _session == null ? null : _useTemplate,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _preparing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Use template',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
