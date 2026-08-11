import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/usecases/video_templates_usecases.dart';
import 'package:bimobondapp/app/video_templates/presentation/di/video_templates_injector.dart'
    as vt_di;
import 'package:bimobondapp/app/video_templates/presentation/pages/video_templates_browser_screen.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Template pickers — Instagram/TikTok apply sheet when media is ready.
///
/// Selection returns a [VideoTemplateSelection]; live composition happens in
/// the media studio (the dedicated select screen was removed).
class VideoTemplatesPickerSheet {
  VideoTemplatesPickerSheet._();

  /// Empty templateId = user chose "No template".
  static const cleared = VideoTemplateSelection(templateId: '', name: '');

  static Future<VideoTemplateSelection?> showPhotoTemplates(
    BuildContext context, {
    String? selectedTemplateId,
  }) {
    return GlassBottomSheet.showContent<VideoTemplateSelection>(
      context,
      title: 'Photo templates',
      child: _PhotoTemplatesGrid(selectedTemplateId: selectedTemplateId),
    );
  }

  /// Bottom sheet carousel — never pushes a full-screen browser/select page.
  static Future<VideoTemplateSelection?> showSelect(
    BuildContext context, {
    required List<File> mediaFiles,
    String? selectedTemplateId,
    String? initialKind,
  }) {
    return GlassBottomSheet.showContent<VideoTemplateSelection>(
      context,
      title: 'Select template',
      isScrollControlled: true,
      child: _SelectTemplatesCarousel(
        selectedTemplateId: selectedTemplateId,
        initialKind: initialKind,
      ),
    );
  }

  /// Full browser (featured / trending / categories / search).
  static Future<VideoTemplateSelection?> showBrowser(
    BuildContext context, {
    String? initialKind,
  }) {
    return Navigator.of(context).push<VideoTemplateSelection>(
      MaterialPageRoute(
        builder: (_) => VideoTemplatesBrowserScreen(initialKind: initialKind),
      ),
    );
  }
}

class _SelectTemplatesCarousel extends StatefulWidget {
  const _SelectTemplatesCarousel({
    this.selectedTemplateId,
    this.initialKind,
  });

  final String? selectedTemplateId;
  final String? initialKind;

  @override
  State<_SelectTemplatesCarousel> createState() =>
      _SelectTemplatesCarouselState();
}

class _SelectTemplatesCarouselState extends State<_SelectTemplatesCarousel> {
  bool _loading = true;
  String? _error;
  List<VideoTemplateCardEntity> _items = const [];
  String? _applyingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final featuredFuture = vt_di.sl<ListFeaturedVideoTemplatesUseCase>()();
    final photoFuture = vt_di.sl<ListPhotoVideoTemplatesUseCase>()();
    final videoFuture = vt_di.sl<ListVideoTemplatesUseCase>()(
      templateKind: VideoTemplateKinds.video,
    );
    final photoCarouselFuture = vt_di.sl<ListVideoTemplatesUseCase>()(
      templateKind: VideoTemplateKinds.photoCarousel,
    );
    final trendingFuture = vt_di.sl<ListTrendingVideoTemplatesUseCase>()();
    final kind = widget.initialKind?.trim();
    final extraKindFuture = (kind != null &&
            kind.isNotEmpty &&
            kind.toUpperCase() != VideoTemplateKinds.video &&
            kind.toUpperCase() != VideoTemplateKinds.photoCarousel)
        ? vt_di.sl<ListVideoTemplatesUseCase>()(templateKind: kind)
        : null;
    final featured = await featuredFuture;
    final photo = await photoFuture;
    final video = await videoFuture;
    final photoCarousel = await photoCarouselFuture;
    final trending = await trendingFuture;
    final extraKind = extraKindFuture == null ? null : await extraKindFuture;

    if (!mounted) return;

    final byId = <String, VideoTemplateCardEntity>{};
    for (final list in [
      featured.fold((_) => <VideoTemplateCardEntity>[], (v) => v),
      trending.fold((_) => <VideoTemplateCardEntity>[], (v) => v),
      photo.fold((_) => <VideoTemplateCardEntity>[], (v) => v),
      video.fold((_) => <VideoTemplateCardEntity>[], (v) => v),
      photoCarousel.fold((_) => <VideoTemplateCardEntity>[], (v) => v),
      if (extraKind != null)
        extraKind.fold((_) => <VideoTemplateCardEntity>[], (v) => v),
    ]) {
      for (final c in list) {
        byId.putIfAbsent(c.id, () => c);
      }
    }

    setState(() {
      _loading = false;
      _items = byId.values.toList(growable: false);
      if (_items.isEmpty) _error = 'No templates yet';
    });
  }

  Future<void> _clearTemplate() async {
    Navigator.of(context).pop(VideoTemplatesPickerSheet.cleared);
  }

  Future<void> _select(VideoTemplateCardEntity card) async {
    if (_applyingId != null) return;
    setState(() => _applyingId = card.id);

    var selection = VideoTemplateSelection.fromCard(card);

    final recipeResult = await vt_di.sl<GetVideoTemplateRecipeUseCase>()(
      card.id,
      includeOverlays: true,
      expectedVersion: card.version,
    );
    if (!mounted) return;
    recipeResult.fold((_) {}, (recipe) {
      selection = VideoTemplateSelection.fromRecipe(recipe).copyWith(
        sound: recipe.sound ?? card.sound,
        soundSegmentId: recipe.soundSegmentId ?? card.soundSegmentId,
      );
    });

    unawaited(vt_di.sl<RecordVideoTemplateUseUseCase>()(card.id));
    // Don't block selection on project create — studio persist owns that.

    if (!mounted) return;
    Navigator.of(context).pop(selection);
  }

  static String _formatDuration(double? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final total = seconds.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _clearTemplate,
              icon: const Icon(LucideIcons.circleSlash, size: 18),
              label: const Text('No template'),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final card = _items[i];
                return _CarouselThumb(
                  card: card,
                  selected: card.id == widget.selectedTemplateId,
                  busy: _applyingId == card.id,
                  durationLabel: _formatDuration(card.duration),
                  onTap: () => _select(card),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselThumb extends StatelessWidget {
  const _CarouselThumb({
    required this.card,
    required this.selected,
    required this.busy,
    required this.durationLabel,
    required this.onTap,
  });

  final VideoTemplateCardEntity card;
  final bool selected;
  final bool busy;
  final String durationLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? Colors.white : Colors.white24,
                      width: selected ? 2 : 1,
                    ),
                    color: const Color(0xFF2A2A2A),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (card.coverUrl != null && card.coverUrl!.isNotEmpty)
                          SafeNetworkImage(
                            imageUrl: card.coverUrl!,
                            fit: BoxFit.cover,
                          )
                        else
                          const ColoredBox(
                            color: Color(0xFF333333),
                            child: Icon(
                              LucideIcons.layoutTemplate,
                              color: Colors.white38,
                              size: 22,
                            ),
                          ),
                        if (busy)
                          const ColoredBox(
                            color: Color(0x66000000),
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (durationLabel.isNotEmpty)
                Text(
                  durationLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTemplatesGrid extends StatefulWidget {
  const _PhotoTemplatesGrid({this.selectedTemplateId});

  final String? selectedTemplateId;

  @override
  State<_PhotoTemplatesGrid> createState() => _PhotoTemplatesGridState();
}

class _PhotoTemplatesGridState extends State<_PhotoTemplatesGrid> {
  bool _loading = true;
  String? _error;
  List<VideoTemplateCardEntity> _items = const [];
  String? _applyingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await vt_di.sl<ListPhotoVideoTemplatesUseCase>()();
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
        _items = const [];
      }),
      (list) => setState(() {
        _loading = false;
        _items = list;
      }),
    );
  }

  Future<void> _select(VideoTemplateCardEntity card) async {
    if (_applyingId != null) return;
    setState(() => _applyingId = card.id);

    var selection = VideoTemplateSelection.fromCard(card);

    final recipeResult = await vt_di.sl<GetVideoTemplateRecipeUseCase>()(
      card.id,
      includeOverlays: true,
    );
    if (!mounted) return;
    recipeResult.fold((_) {}, (recipe) {
      selection = VideoTemplateSelection.fromRecipe(recipe);
    });

    unawaited(vt_di.sl<RecordVideoTemplateUseUseCase>()(card.id));
    // Don't block selection on project create — studio persist owns that.

    if (!mounted) return;
    Navigator.of(context).pop(selection);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(color: Colors.white70)),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No photo templates yet',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return SizedBox(
      height: 360,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final card = _items[index];
          final selected = card.id == widget.selectedTemplateId;
          final busy = _applyingId == card.id;
          return _TemplateTile(
            card: card,
            selected: selected,
            busy: busy,
            onTap: () => _select(card),
          );
        },
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.card,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final VideoTemplateCardEntity card;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white24,
                    width: selected ? 2 : 1,
                  ),
                  color: const Color(0xFF2A2A2A),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (card.coverUrl != null && card.coverUrl!.isNotEmpty)
                        SafeNetworkImage(
                          imageUrl: card.coverUrl!,
                          fit: BoxFit.cover,
                        )
                      else
                        const ColoredBox(
                          color: Color(0xFF333333),
                          child: Icon(
                            LucideIcons.layoutTemplate,
                            color: Colors.white38,
                          ),
                        ),
                      if (busy)
                        const ColoredBox(
                          color: Color(0x66000000),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${card.slotCount} clips',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
