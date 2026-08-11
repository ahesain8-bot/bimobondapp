import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/usecases/video_templates_usecases.dart';
import 'package:bimobondapp/app/video_templates/presentation/di/video_templates_injector.dart'
    as vt_di;
import 'package:bimobondapp/app/video_templates/presentation/pages/video_template_detail_screen.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Phase 19 — TikTok-style template feed / shelves.
class VideoTemplatesBrowserScreen extends StatefulWidget {
  const VideoTemplatesBrowserScreen({
    super.key,
    this.initialKind,
    this.onSelected,
  });

  final String? initialKind;
  final ValueChanged<VideoTemplateSelection>? onSelected;

  @override
  State<VideoTemplatesBrowserScreen> createState() =>
      _VideoTemplatesBrowserScreenState();
}

class _VideoTemplatesBrowserScreenState
    extends State<VideoTemplatesBrowserScreen> {
  bool _loading = true;
  String? _error;
  List<TemplateCategoryEntity> _categories = const [];
  List<VideoTemplateCardEntity> _featured = const [];
  List<VideoTemplateCardEntity> _trending = const [];
  List<VideoTemplateCardEntity> _catalog = const [];
  String? _categoryId;
  String? _kind;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final catsFuture = vt_di.sl<ListVideoTemplateCategoriesUseCase>()(
      forceRefresh: forceRefresh,
    );
    final featuredFuture = vt_di.sl<ListFeaturedVideoTemplatesUseCase>()(
      forceRefresh: forceRefresh,
    );
    final trendingFuture = vt_di.sl<ListTrendingVideoTemplatesUseCase>()(
      forceRefresh: forceRefresh,
    );
    final catalogFuture = vt_di.sl<ListVideoTemplatesUseCase>()(
      templateKind: _kind,
      categoryId: _categoryId,
      forceRefresh: forceRefresh,
    );
    final cats = await catsFuture;
    final featured = await featuredFuture;
    final trending = await trendingFuture;
    final catalog = await catalogFuture;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _categories = cats.fold((_) => const [], (v) => v);
      _featured = featured.fold((_) => const [], (v) => v);
      _trending = trending.fold((_) => const [], (v) => v);
      catalog.fold(
        (f) {
          _error = f.message;
          _catalog = const [];
        },
        (v) => _catalog = v,
      );
    });
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      _load();
      return;
    }
    setState(() => _loading = true);
    final result = await vt_di.sl<SearchVideoTemplatesUseCase>()(query: q);
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (list) => setState(() {
        _loading = false;
        _catalog = list;
        _featured = const [];
        _trending = const [];
      }),
    );
  }

  Future<void> _open(VideoTemplateCardEntity card) async {
    final selection = await Navigator.of(context).push<VideoTemplateSelection>(
      MaterialPageRoute(
        builder: (_) => VideoTemplateDetailScreen(card: card),
      ),
    );
    if (selection != null && mounted) {
      final cb = widget.onSelected;
      if (cb != null) {
        cb(selection);
      } else {
        Navigator.of(context).pop(selection);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Templates'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => _load(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search templates',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                prefixIcon: const Icon(LucideIcons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _search,
            ),
          ),
          if (_categories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _Chip(
                    label: 'All',
                    selected: _categoryId == null,
                    onTap: () {
                      setState(() => _categoryId = null);
                      _load();
                    },
                  ),
                  ..._categories.map(
                    (c) => _Chip(
                      label: c.name,
                      selected: _categoryId == c.id,
                      onTap: () {
                        setState(() => _categoryId = c.id);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  )
                : _error != null && _catalog.isEmpty
                    ? Center(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(forceRefresh: true),
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            if (_featured.isNotEmpty) ...[
                              _sectionTitle('Featured'),
                              _horizontal(cards: _featured),
                            ],
                            if (_trending.isNotEmpty) ...[
                              _sectionTitle('Trending'),
                              _horizontal(cards: _trending),
                            ],
                            _sectionTitle('For you'),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _catalog.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.72,
                                ),
                                itemBuilder: (_, i) => _TemplateCard(
                                  card: _catalog[i],
                                  onTap: () => _open(_catalog[i]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _horizontal({required List<VideoTemplateCardEntity> cards}) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(
          width: 120,
          child: _TemplateCard(card: cards[i], onTap: () => _open(cards[i])),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.white70,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: const Color(0xFF1C1C1E),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.card, required this.onTap});

  final VideoTemplateCardEntity card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: const Color(0xFF1C1C1E),
              child: card.coverUrl != null
                  ? SafeNetworkImage(
                      imageUrl: card.coverUrl,
                      fit: BoxFit.cover,
                    )
                  : const Icon(LucideIcons.clapperboard, color: Colors.white24),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                card.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
            if (card.slotCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${card.slotCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
