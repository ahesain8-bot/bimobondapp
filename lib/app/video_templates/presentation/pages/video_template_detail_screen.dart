import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_studio_preview.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/usecases/video_templates_usecases.dart';
import 'package:bimobondapp/app/video_templates/presentation/di/video_templates_injector.dart'
    as vt_di;
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Template detail — preview + **Use template** returns a [VideoTemplateSelection]
/// for the camera / studio (pick template pre-capture, edit after capture).
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

  Future<void> _useTemplate() async {
    final session = _session;
    if (session == null) return;

    setState(() {
      _preparing = true;
      _error = null;
    });

    unawaited(vt_di.sl<RecordVideoTemplateUseUseCase>()(widget.card.id));
    unawaited(
      vt_di.sl<CreateVideoTemplateProjectUseCase>()(
        templateId: widget.card.id,
        title: widget.card.name,
      ),
    );

    if (!mounted) return;
    setState(() => _preparing = false);
    Navigator.of(context).pop(session.selection);
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
