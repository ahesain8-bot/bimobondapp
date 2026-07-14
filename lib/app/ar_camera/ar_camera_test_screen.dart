import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_preview.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ArCameraTestScreen extends StatefulWidget {
  const ArCameraTestScreen({super.key});

  @override
  State<ArCameraTestScreen> createState() => _ArCameraTestScreenState();
}

class _ArCameraTestScreenState extends State<ArCameraTestScreen> {
  int _selected = 0;
  double _swipeDrag = 0;
  late final ScrollController _carouselController;
  bool _ignoreCarouselScrollEnd = false;

  static const _inactiveSize = 52.0;
  static const _activeSize = 78.0;
  static const _itemGap = 12.0;
  static const _itemStride = _activeSize + _itemGap;

  final _filters = const [
    _ArFilterItem(id: 'none', label: 'Original', emoji: '✨'),
    _ArFilterItem(id: 'glasses', label: 'Glasses', emoji: '😎'),
    _ArFilterItem(id: 'dog', label: 'Dog', emoji: '🐶'),
    _ArFilterItem(id: 'moustache', label: 'Moustache', emoji: '🥸'),
    _ArFilterItem(id: 'big_eyes', label: 'Big Eyes', emoji: '👀'),
    _ArFilterItem(id: 'big_lips', label: 'Big Lips', emoji: '👄'),
    _ArFilterItem(id: 'long_nose', label: 'Nose', emoji: '👃'),
    _ArFilterItem(id: 'whitening', label: 'Beauty', emoji: '🌟'),
    _ArFilterItem(id: 'clarendon', label: 'Clarendon', emoji: '📸'),
    _ArFilterItem(id: 'valencia', label: 'Valencia', emoji: '☀️'),
    _ArFilterItem(id: 'ludwig', label: 'Ludwig', emoji: '✨'),
    _ArFilterItem(id: 'rosy', label: 'Rosy', emoji: '🌸'),
    _ArFilterItem(id: 'warm', label: 'Peach Warm', emoji: '🍑'),
    _ArFilterItem(id: 'cool', label: 'Cool', emoji: '❄️'),
    _ArFilterItem(id: 'vintage', label: 'Vintage', emoji: '🎞️'),
    _ArFilterItem(id: 'mono', label: 'B & W', emoji: '🖤'),
  ];

  @override
  void initState() {
    super.initState();
    _carouselController = ScrollController();
    ArCameraBridge.warmup();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected(animated: false);
    });
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _scrollToSelected({bool animated = true}) async {
    if (!_carouselController.hasClients) return;
    final target = _selected * _itemStride;
    _ignoreCarouselScrollEnd = true;
    if (animated) {
      await _carouselController.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    } else {
      _carouselController.jumpTo(target);
    }
    _ignoreCarouselScrollEnd = false;
  }

  void _select(int index, {bool fromCarousel = false}) {
    final clamped = index.clamp(0, _filters.length - 1);
    if (clamped == _selected && fromCarousel) {
      _scrollToSelected(animated: true);
      return;
    }
    if (clamped == _selected) return;

    setState(() => _selected = clamped);
    // Instant carousel jump on camera swipe; animate only for carousel interaction.
    _scrollToSelected(animated: fromCarousel);
    ArCameraBridge.setFilter(_filters[clamped].id);
  }

  void _nextFilter() {
    if (_selected < _filters.length - 1) {
      _select(_selected + 1);
    }
  }

  void _previousFilter() {
    if (_selected > 0) {
      _select(_selected - 1);
    }
  }

  void _onPreviewSwipeEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -80 || _swipeDrag < -36) {
      _nextFilter();
    } else if (velocity > 80 || _swipeDrag > 36) {
      _previousFilter();
    }
    _swipeDrag = 0;
  }

  void _onCarouselScrollEnd() {
    if (_ignoreCarouselScrollEnd || !_carouselController.hasClients) return;
    final index =
        (_carouselController.offset / _itemStride).round().clamp(0, _filters.length - 1);
    _select(index, fromCarousel: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidePadding = (screenWidth - _itemStride) / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                _swipeDrag += details.delta.dx;
              },
              onHorizontalDragEnd: _onPreviewSwipeEnd,
              child: const ArCameraPreview(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 230 + bottomInset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    LucideIcons.x,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18 + bottomInset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _filters[_selected].label,
                    key: ValueKey(_filters[_selected].id),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: _activeSize + 10,
                  child: NotificationListener<ScrollEndNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.axis == Axis.horizontal) {
                        _onCarouselScrollEnd();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _carouselController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: sidePadding),
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final item = _filters[index];
                        final isActive = index == _selected;
                        final size = isActive ? _activeSize : _inactiveSize;

                        return SizedBox(
                          width: _itemStride,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => _select(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOut,
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(
                                    alpha: isActive ? 0.16 : 0.08,
                                  ),
                                  border: Border.all(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.35),
                                    width: isActive ? 2.5 : 1.5,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: Colors.white.withValues(
                                              alpha: 0.22,
                                            ),
                                            blurRadius: 14,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    item.emoji,
                                    style: TextStyle(
                                      fontSize: isActive ? 30 : 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.settingsArCameraTest,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
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

class _ArFilterItem {
  const _ArFilterItem({
    required this.id,
    required this.label,
    required this.emoji,
  });

  final String id;
  final String label;
  final String emoji;
}
