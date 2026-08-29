import 'dart:async';

import 'package:bimobondapp/app/video_templates/data/datasources/video_templates_local_cache.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/usecases/video_templates_usecases.dart';
import 'package:bimobondapp/app/video_templates/presentation/di/video_templates_injector.dart'
    as vt_di;
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style template carousel that sits on the editor (not a new route).
///
/// Tapping a template calls [onSelected] so the parent can update the live
/// preview behind this panel on the same screen.
class TemplateSelectorBottomPanel extends StatefulWidget {
  const TemplateSelectorBottomPanel({
    super.key,
    this.selectedTemplateId,
    this.initialKind,
    this.applying = false,
    required this.onClose,
    required this.onClear,
    required this.onSelected,
    this.onEdit,
    required this.onYourStory,
    required this.onNext,
    this.avatarUrl,
    this.nextLabel = 'Next',
    this.yourStoryLabel = 'Your Story',
  });

  final String? selectedTemplateId;
  final String? initialKind;
  final bool applying;
  final VoidCallback onClose;
  final VoidCallback onClear;
  final Future<void> Function(VideoTemplateSelection selection) onSelected;
  final VoidCallback? onEdit;
  final VoidCallback onYourStory;
  final VoidCallback onNext;
  final String? avatarUrl;
  final String nextLabel;
  final String yourStoryLabel;

  @override
  State<TemplateSelectorBottomPanel> createState() =>
      _TemplateSelectorBottomPanelState();
}

class _TemplateSelectorBottomPanelState
    extends State<TemplateSelectorBottomPanel> {
  static const _accent = Color(0xFFFF2D55);
  static const _sheet = Color(0xFF121212);

  bool _loading = true;
  String? _error;
  List<VideoTemplateCardEntity> _items = const [];
  String? _busyId;
  /// Optimistic selection so the mark updates before parent finishes apply.
  String? _highlightedId;
  int _gen = 0;
  final ScrollController _scrollController = ScrollController();
  Timer? _selectDebounce;
  VideoTemplateCardEntity? _pendingSelect;

  String? get _effectiveSelectedId =>
      _highlightedId ?? widget.selectedTemplateId;

  @override
  void initState() {
    super.initState();
    _highlightedId = widget.selectedTemplateId;
    _load();
  }

  @override
  void didUpdateWidget(covariant TemplateSelectorBottomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTemplateId != oldWidget.selectedTemplateId) {
      _highlightedId = widget.selectedTemplateId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToSelected();
      });
    }
  }

  @override
  void dispose() {
    _selectDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Same shelves for photos and videos: featured/trending + PHOTO + VIDEO.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSelected();
    });
    // Warm recipe cache so the next tap feels instant.
    unawaited(_prefetchRecipes(_items.take(12)));
  }

  Future<void> _prefetchRecipes(Iterable<VideoTemplateCardEntity> cards) async {
    final getRecipe = vt_di.sl<GetVideoTemplateRecipeUseCase>();
    for (final card in cards) {
      if (!mounted) return;
      final cached = vt_di.sl<VideoTemplatesLocalCache>().getRecipe(
        card.id,
        includeOverlays: true,
        expectedVersion: card.version,
      );
      if (cached != null) continue;
      try {
        await getRecipe(
          card.id,
          includeOverlays: true,
          expectedVersion: card.version,
        );
      } catch (_) {}
    }
  }

  void _scrollToSelected() {
    final id = _effectiveSelectedId;
    if (id == null || id.isEmpty || !_scrollController.hasClients) return;
    final index = _items.indexWhere((c) => c.id == id);
    if (index < 0) return;
    const itemExtent = 76.0; // 68 width + 8 gap
    final offset = (index * itemExtent) - 24;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _select(VideoTemplateCardEntity card) async {
    if (widget.applying) return;
    if (card.id == _effectiveSelectedId && _busyId == null) return;

    // Immediate highlight; debounce expensive apply so rapid taps keep only
    // the latest template.
    setState(() => _highlightedId = card.id);
    _pendingSelect = card;
    _selectDebounce?.cancel();
    _selectDebounce = Timer(const Duration(milliseconds: 90), () {
      final pending = _pendingSelect;
      _pendingSelect = null;
      if (pending == null || !mounted) return;
      unawaited(_selectNow(pending));
    });
  }

  Future<void> _selectNow(VideoTemplateCardEntity card) async {
    if (_busyId != null || widget.applying) return;

    final gen = ++_gen;
    setState(() {
      _busyId = card.id;
      _highlightedId = card.id;
    });

    try {
      var selection = VideoTemplateSelection.fromCard(card);

      // Instant path when recipe is already cached.
      final cached = vt_di.sl<VideoTemplatesLocalCache>().getRecipe(
        card.id,
        includeOverlays: true,
        expectedVersion: card.version,
      );
      if (cached != null) {
        selection = VideoTemplateSelection.fromRecipe(cached).copyWith(
          sound: cached.effectivePreviewSound ?? card.sound,
          soundSegmentId: cached.soundSegmentId ?? card.soundSegmentId,
        );
      } else {
        final recipeResult = await vt_di.sl<GetVideoTemplateRecipeUseCase>()(
          card.id,
          includeOverlays: true,
          expectedVersion: card.version,
        );
        if (!mounted || gen != _gen) return;

        recipeResult.fold((_) {}, (recipe) {
          selection = VideoTemplateSelection.fromRecipe(recipe).copyWith(
            sound: recipe.effectivePreviewSound ?? card.sound,
            soundSegmentId: recipe.soundSegmentId ?? card.soundSegmentId,
          );
        });
      }
      if (!mounted || gen != _gen) return;

      unawaited(vt_di.sl<RecordVideoTemplateUseUseCase>()(card.id));
      // Project create happens in studio persist — don't race a duplicate POST.

      await widget.onSelected(selection);
    } finally {
      if (mounted && gen == _gen) {
        setState(() => _busyId = null);
      }
    }
  }

  void _onClear() {
    setState(() => _highlightedId = null);
    widget.onClear();
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
    final bottom = MediaQuery.paddingOf(context).bottom;
    final avatarUrl = widget.avatarUrl;
    final selectedId = _effectiveSelectedId;
    final noneSelected = selectedId == null || selectedId.isEmpty;

    return Material(
      color: _sheet,
      elevation: 16,
      shadowColor: Colors.black54,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 4, 8, 8 + bottom * 0.25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'No template',
                    onPressed: widget.applying ? null : _onClear,
                    icon: Icon(
                      LucideIcons.circleSlash,
                      color: noneSelected ? Colors.white : Colors.white54,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: noneSelected
                          ? Colors.white24
                          : Colors.transparent,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Select template',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                  ),
                ],
              ),
              if (_error != null && _items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              SizedBox(
                height: 118,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final card = _items[i];
                          final selected = card.id == selectedId;
                          final busy = _busyId == card.id ||
                              (widget.applying && selected);
                          return _PanelThumb(
                            card: card,
                            selected: selected,
                            busy: busy,
                            durationLabel: _formatDuration(card.duration),
                            onTap: () => _select(card),
                            onEdit: selected &&
                                    !busy &&
                                    widget.onEdit != null
                                ? widget.onEdit
                                : null,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: Material(
                        color: Colors.white,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: widget.applying ? null : widget.onYourStory,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black12,
                                  backgroundImage: avatarUrl != null &&
                                          avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: avatarUrl == null || avatarUrl.isEmpty
                                      ? const Icon(
                                          LucideIcons.user,
                                          size: 14,
                                          color: Colors.black54,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.yourStoryLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: widget.applying ? null : widget.onNext,
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _accent.withValues(alpha: 0.35),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          widget.nextLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelThumb extends StatelessWidget {
  const _PanelThumb({
    required this.card,
    required this.selected,
    required this.busy,
    required this.durationLabel,
    required this.onTap,
    this.onEdit,
  });

  final VideoTemplateCardEntity card;
  final bool selected;
  final bool busy;
  final String durationLabel;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? Colors.white : Colors.white24,
                      width: selected ? 2.5 : 1,
                    ),
                    color: const Color(0xFF2A2A2A),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: Color(0x66FFFFFF),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
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
                        if (selected && !busy)
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFFF2D55),
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(3),
                                child: Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if (onEdit != null)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: onEdit,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    LucideIcons.pencil,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
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
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (durationLabel.isNotEmpty)
                Text(
                  durationLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
