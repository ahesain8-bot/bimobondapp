import 'dart:async';

import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class MarketplaceHeroBanner extends StatefulWidget {
  const MarketplaceHeroBanner({required this.onExplore, super.key});

  final VoidCallback onExplore;

  static const _phoneAsset = 'assets/images/marketplace/hero_phone.png';
  static const _watchAsset = 'assets/images/marketplace/hero_watch.png';
  static const _buildingAsset = 'assets/images/marketplace/hero_building.png';

  @override
  State<MarketplaceHeroBanner> createState() => _MarketplaceHeroBannerState();
}

class _MarketplaceHeroBannerState extends State<MarketplaceHeroBanner> {
  static const _slideCount = 3;
  static const _autoPlayInterval = Duration(seconds: 4);

  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(
        const AssetImage(MarketplaceHeroBanner._phoneAsset),
        context,
      );
      precacheImage(
        const AssetImage(MarketplaceHeroBanner._watchAsset),
        context,
      );
      precacheImage(
        const AssetImage(MarketplaceHeroBanner._buildingAsset),
        context,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(_autoPlayInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _slideCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _startAutoPlay();
  }

  double _bannerHeight(BuildContext context) =>
      MarketplaceTheme.heroCarouselHeight(context);

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final height = _bannerHeight(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: height,
        child: PageView.builder(
          controller: _pageController,
          itemCount: _slideCount,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final imageAssets = [
              MarketplaceHeroBanner._phoneAsset,
              MarketplaceHeroBanner._watchAsset,
              MarketplaceHeroBanner._buildingAsset,
            ];
            return _HeroSlide(
              theme: theme,
              title: l10n.marketplaceHeroTitle,
              subtitle: l10n.marketplaceHeroSubtitle,
              ctaLabel: l10n.marketplaceExploreCta,
              onExplore: widget.onExplore,
              imageAsset: imageAssets[index],
              pageIndex: index,
              pageCount: _slideCount,
            );
          },
        ),
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onExplore,
    required this.imageAsset,
    required this.pageIndex,
    required this.pageCount,
  });

  final MarketplaceTheme theme;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onExplore;
  final String imageAsset;
  final int pageIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: theme.heroCarouselGradient,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
        boxShadow: MarketplaceTheme.softShadow,
        border: Border.all(color: theme.shop.border.withValues(alpha: 0.12)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        _HeroTitle(title: title, onSurface: theme.onSurface),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.mutedText,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Material(
                          color: theme.primary,
                          borderRadius:
                              BorderRadius.circular(MarketplaceTheme.radiusSm),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onExplore,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      ctaLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.shop.onAccent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  DirectionalChevronIcon(
                                    color: theme.shop.onAccent,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: _HeroProductImage(assetPath: imageAsset),
                    ),
                  ),
                ),
              ],
            ),
          ),
            Positioned(
              right: 12,
              bottom: 10,
              child: _CarouselDots(
                count: pageCount,
                index: pageIndex,
                activeColor: theme.primary,
                inactiveColor: theme.shop.border.withValues(alpha: 0.45),
                borderColor: theme.shop.border,
              ),
            ),
          ],
        ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({required this.title, required this.onSurface});

  final String title;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final parts = title.split('.');
    final trimmed = parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

    if (trimmed.length >= 3) {
      final lead = trimmed.sublist(0, trimmed.length - 1).join('. ');
      final highlight = trimmed.last;
      return RichText(
        text: TextSpan(
          style: TextStyle(
            color: onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
          children: [
            TextSpan(text: '$lead.\n'),
            TextSpan(
              text: '$highlight.',
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      title,
      style: TextStyle(
        color: onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        height: 1.05,
      ),
    );
  }
}

class _HeroProductImage extends StatelessWidget {
  const _HeroProductImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.centerLeft,
          child: Image.asset(
            assetPath,
            width: w * 0.98,
            height: h * 0.98,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => SizedBox(
              width: w * 0.96,
              height: h * 0.96,
              child: Icon(
                Icons.image_not_supported_outlined,
                size: w * 0.35,
                color: theme.mutedText,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({
    required this.count,
    required this.index,
    required this.activeColor,
    required this.inactiveColor,
    required this.borderColor,
  });

  final int count;
  final int index;
  final Color activeColor;
  final Color inactiveColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(left: 4),
          width: active ? 8 : 6,
          height: active ? 8 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? activeColor : inactiveColor,
            border: active
                ? null
                : Border.all(color: borderColor.withValues(alpha: 0.5)),
          ),
        );
      }),
    );
  }
}

class MarketplaceSectionHeader extends StatelessWidget {
  const MarketplaceSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
