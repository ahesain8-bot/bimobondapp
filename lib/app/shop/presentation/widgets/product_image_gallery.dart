import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

class ProductImageGallery extends StatefulWidget {
  const ProductImageGallery({
    required this.product,
    this.height = 320,
    this.heroTag,
    this.showThumbnails = true,
    super.key,
  });

  final ProductEntity product;
  final double height;
  final String? heroTag;
  final bool showThumbnails;

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late final PageController _pageController;
  int _currentPage = 0;
  VideoPlayerController? _videoController;
  String? _activeVideoUrl;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncVideoForPage(0);
    });
  }

  @override
  void didUpdateWidget(covariant ProductImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _disposeVideo();
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _syncVideoForPage(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeVideo();
    super.dispose();
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
    _activeVideoUrl = null;
  }

  List<_GalleryPage> _pages(ProductEntity product) {
    final pages = <_GalleryPage>[];
    final seen = <String>{};

    void addPage(_GalleryPage page) {
      final key = '${page.isVideo ? 'v' : 'i'}:${page.url}';
      if (page.url.isEmpty || seen.contains(key)) return;
      seen.add(key);
      pages.add(page);
    }

    final sortedMedia = [...product.media]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final media in sortedMedia) {
      if (media.mediaType == ProductMediaType.video ||
          MediaUtils.isVideo(media.url)) {
        addPage(_GalleryPage.video(media.hlsUrl ?? media.url));
      } else if (media.url.isNotEmpty) {
        addPage(_GalleryPage.image(media.url));
      }
    }

    final topVideo = product.hlsUrl ?? product.videoUrl;
    if (topVideo != null && topVideo.isNotEmpty) {
      addPage(_GalleryPage.video(topVideo));
    }

    if (product.coverImageUrl != null && product.coverImageUrl!.isNotEmpty) {
      addPage(_GalleryPage.image(product.coverImageUrl!));
    }
    if (product.thumbnailUrl != null && product.thumbnailUrl!.isNotEmpty) {
      addPage(_GalleryPage.image(product.thumbnailUrl!));
    }

    if (pages.isEmpty && product.displayImageUrl != null) {
      addPage(_GalleryPage.image(product.displayImageUrl!));
    }

    return pages;
  }

  String? _thumbUrl(_GalleryPage page) {
    if (!page.isVideo) return MediaUtils.resolveAbsoluteUrl(page.url);
    return widget.product.displayImageUrl;
  }

  Future<void> _syncVideoForPage(int index) async {
    final pages = _pages(widget.product);
    if (index < 0 || index >= pages.length) {
      _disposeVideo();
      if (mounted) setState(() {});
      return;
    }

    final page = pages[index];
    if (!page.isVideo) {
      _disposeVideo();
      if (mounted) setState(() {});
      return;
    }

    final url = MediaUtils.resolveAbsoluteUrl(page.url);
    if (url == _activeVideoUrl &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      await _videoController!.play();
      return;
    }

    _disposeVideo();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    _activeVideoUrl = url;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      await controller.dispose();
      if (_videoController == controller) {
        _videoController = null;
        _activeVideoUrl = null;
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _togglePlay() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final pages = _pages(widget.product);

    if (pages.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: ColoredBox(
          color: theme.card,
          child: Icon(LucideIcons.imageOff, color: theme.mutedText, size: 48),
        ),
      );
    }

    final mainImage = SizedBox(
      height: widget.height,
      child: PageView.builder(
        controller: _pageController,
        itemCount: pages.length,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
          _syncVideoForPage(index);
        },
        itemBuilder: (context, index) {
          final page = pages[index];
          if (page.isVideo) {
            final controller = _videoController;
            final ready = index == _currentPage &&
                controller != null &&
                controller.value.isInitialized &&
                _activeVideoUrl == MediaUtils.resolveAbsoluteUrl(page.url);

            if (ready) {
              return GestureDetector(
                onTap: _togglePlay,
                child: ColoredBox(
                  color: theme.card,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio == 0
                              ? 9 / 16
                              : controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                      if (!controller.value.isPlaying)
                        Center(
                          child: Icon(
                            LucideIcons.play,
                            color: theme.onSurface.withValues(alpha: 0.7),
                            size: 48,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }

            return _VideoFallback(
              coverUrl: widget.product.displayImageUrl,
              theme: theme,
            );
          }

          return ColoredBox(
            color: theme.card,
            child: SafeNetworkImage(
              imageUrl: MediaUtils.resolveAbsoluteUrl(page.url),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          );
        },
      ),
    );

    final heroWrapped = widget.heroTag != null
        ? Hero(tag: widget.heroTag!, child: mainImage)
        : mainImage;

    return Column(
      children: [
        heroWrapped,
        if (pages.length > 1) ...[
          const SizedBox(height: AppSizes.p12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _currentPage == index ? 8 : 6,
                height: _currentPage == index ? 8 : 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? theme.primary
                      : theme.onSurface.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ],
        if (widget.showThumbnails && pages.length > 1) ...[
          const SizedBox(height: AppSizes.p12),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
              itemCount: pages.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.p10),
              itemBuilder: (context, index) {
                final selected = index == _currentPage;
                return GestureDetector(
                  onTap: () => _goToPage(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 64,
                    decoration: BoxDecoration(
                      color: theme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? theme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SafeNetworkImage(
                            imageUrl: _thumbUrl(pages[index]),
                            fit: BoxFit.cover,
                          ),
                          if (pages[index].isVideo)
                            ColoredBox(
                              color: theme.onSurface.withValues(alpha: 0.26),
                              child: Icon(
                                LucideIcons.play,
                                size: 16,
                                color: theme.background,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _GalleryPage {
  const _GalleryPage._({required this.url, required this.isVideo});

  factory _GalleryPage.image(String url) =>
      _GalleryPage._(url: url, isVideo: false);

  factory _GalleryPage.video(String url) =>
      _GalleryPage._(url: url, isVideo: true);

  final String url;
  final bool isVideo;
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback({required this.coverUrl, required this.theme});

  final String? coverUrl;
  final ShopTheme theme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: theme.card,
          child: SafeNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
