import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/video_templates/composition/composition_preview_controller.dart';
import 'package:bimobondapp/app/video_templates/composition/composition_session.dart';
import 'package:bimobondapp/app/video_templates/composition/template_composition_engine.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/di/video_templates_injector.dart'
    as vt_di;
import 'package:bimobondapp/app/video_templates/presentation/widgets/video_template_composed_preview.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style template editor: preview + timeline + replace (Phases 13–14).
class VideoTemplateEditorScreen extends StatefulWidget {
  const VideoTemplateEditorScreen({
    super.key,
    required this.recipe,
    this.card,
    this.initialSelection,
    this.initialFills,
    this.projectId,
  });

  final VideoTemplateRecipeEntity recipe;
  final VideoTemplateCardEntity? card;
  final VideoTemplateSelection? initialSelection;
  final Map<String, SlotFillEntry>? initialFills;
  final String? projectId;

  @override
  State<VideoTemplateEditorScreen> createState() =>
      _VideoTemplateEditorScreenState();
}

class _VideoTemplateEditorScreenState extends State<VideoTemplateEditorScreen> {
  late final TemplateCompositionEngine _engine;
  late CompositionSession _session;
  CompositionPreviewController? _preview;
  bool _busy = false;
  String? _error;
  double _exportProgress = 0;

  @override
  void initState() {
    super.initState();
    _engine = vt_di.sl<TemplateCompositionEngine>();
    _session = _engine.open(
      widget.recipe,
      projectId: widget.projectId ?? widget.initialSelection?.projectId,
    );
    if (widget.initialFills != null) {
      _session.fills = Map<String, SlotFillEntry>.from(widget.initialFills!);
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _session.prepareSources();
    final preview = CompositionPreviewController(
      engine: _engine,
      session: _session,
    );
    await preview.attach();
    if (!mounted) {
      preview.dispose();
      return;
    }
    setState(() => _preview = preview);
  }

  @override
  void dispose() {
    _preview?.dispose();
    _session.dispose();
    super.dispose();
  }

  /// TikTok: pick one photo/video and apply it to every slot.
  Future<void> _changeMediaForAll() async {
    final slots = _session.slots;
    final acceptsVideo = slots.any((s) => s.acceptsVideo);
    final acceptsImage = slots.any((s) => s.acceptsImage);

    List<GalleryMediaItem> items;
    if (acceptsVideo && acceptsImage) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF1C1C1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.image, color: Colors.white),
                title: const Text('Photo', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'image'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.video, color: Colors.white),
                title: const Text('Video', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'video'),
              ),
            ],
          ),
        ),
      );
      if (choice == null) return;
      items = choice == 'video'
          ? await MediaGalleryPicker.pickVideos(limit: 1)
          : await MediaGalleryPicker.pickImages(limit: 1);
    } else if (acceptsVideo) {
      items = await MediaGalleryPicker.pickVideos(limit: 1);
    } else {
      items = await MediaGalleryPicker.pickImages(limit: 1);
    }
    if (!mounted || items.isEmpty) return;

    await _session.replaceAllFromFiles([items.first.file]);
    await _preview?.attach();
    setState(() => _error = null);
  }

  Future<void> _exportAndFinish() async {
    setState(() {
      _busy = true;
      _error = null;
      _exportProgress = 0;
    });

    final result = await _engine.export(
      _session,
      onProgress: (p) {
        if (mounted) setState(() => _exportProgress = p);
      },
    );

    if (!mounted) return;

    result.fold(
      (e) {
        setState(() {
          _busy = false;
          _error = e.userMessage;
        });
      },
      (file) {
        setState(() => _busy = false);
        final selection = (widget.initialSelection ??
                VideoTemplateSelection.fromRecipe(widget.recipe))
            .copyWith(
          projectId:
              VideoTemplateProjectIds.normalizeServerId(_session.projectId),
          recipe: widget.recipe,
        );
        Navigator.of(context).pop(selection);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final slots = _session.slots;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.recipe.name),
        actions: [
          TextButton(
            onPressed: _busy ? null : _changeMediaForAll,
            child: const Text(
              'Change',
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            tooltip: 'Undo',
            onPressed: _busy || !_session.canUndo
                ? null
                : () async {
                    _session.undo();
                    await _preview?.attach();
                    setState(() {});
                  },
            icon: const Icon(LucideIcons.undo2),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _busy || !_session.canRedo
                ? null
                : () async {
                    _session.redo();
                    await _preview?.attach();
                    setState(() {});
                  },
            icon: const Icon(LucideIcons.redo2),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy)
            LinearProgressIndicator(
              value: _exportProgress <= 0 ? null : _exportProgress,
              backgroundColor: Colors.white12,
              color: Colors.white,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Expanded(
            child: preview == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : ListenableBuilder(
                    listenable: preview,
                    builder: (context, _) {
                      return VideoTemplateComposedPreview(
                        canvasWidth: widget.recipe.width > 0
                            ? widget.recipe.width
                            : 1080,
                        canvasHeight: widget.recipe.height > 0
                            ? widget.recipe.height
                            : 1920,
                        frame: preview.frame,
                        videoController: preview.videoController,
                        imageFile: preview.imageFile,
                        decodedImage: preview.decodedImage,
                      );
                    },
                  ),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: slots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final slot = slots[i];
                final fill = _session.fills[slot.id];
                final has = fill?.hasMedia == true;
                return InkWell(
                  onTap: _busy ? null : _changeMediaForAll,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 88,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: has ? Colors.white54 : Colors.white12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clip ${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          has ? 'Same media' : 'Add media',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: _busy ? null : _exportAndFinish,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_busy ? 'Exporting…' : 'Export & continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
