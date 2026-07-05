import 'dart:ui';

import 'package:bimobondapp/core/constants/lives_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LivesScreen extends StatefulWidget {
  const LivesScreen({super.key});

  @override
  State<LivesScreen> createState() => _LivesScreenState();
}

class _LivesScreenState extends State<LivesScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilterIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _filters(AppLocalizations l10n) => [
    l10n.liveFilterAll,
    l10n.liveFilterRealEstate,
    l10n.liveFilterAuctions,
    l10n.liveFilterTrending,
    l10n.liveFilterInvestments,
  ];

  String _streamTitle(int index, AppLocalizations l10n) {
    final titles = [
      l10n.liveStreamTitle1,
      l10n.liveStreamTitle2,
      l10n.liveStreamTitle3,
    ];
    return titles[index % titles.length];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final filters = _filters(l10n);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: l10n.liveStreamsTitle,
        showBackButton: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.p16,
              AppSizes.p8,
              AppSizes.p16,
              AppSizes.p8,
            ),
            child: _LiveSearchBar(
              controller: _searchController,
              hintText: l10n.searchLiveStreamsHint,
            ),
          ),
          SizedBox(
            height: LivesLayoutConstants.filterBarHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedFilterIndex == index;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSizes.p10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilterIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.p16,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (theme.brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03)),
                        borderRadius: BorderRadius.circular(AppSizes.p20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        filters[index],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.7),
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppSizes.p16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: LivesLayoutConstants.gridMainSpacing,
                crossAxisSpacing: LivesLayoutConstants.gridCrossSpacing,
                childAspectRatio: LivesLayoutConstants.gridChildAspectRatio,
              ),
              itemCount: LivesLayoutConstants.mockStreamCount,
              itemBuilder: (context, index) {
                return LiveStreamCard(
                  index: index,
                  title: _streamTitle(index, l10n),
                  hostName: l10n.liveHostName(index + 1),
                  viewersLabel: l10n.liveViewersCount((index + 1) * 142),
                  liveBadgeLabel: l10n.liveBadge,
                  onTap: () {
                    context.pushNamed(
                      'live_details',
                      extra: {'index': index},
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSearchBar extends StatelessWidget {
  const _LiveSearchBar({
    required this.controller,
    required this.hintText,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: LivesLayoutConstants.searchBarHeight,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSizes.p16),
          Icon(
            LucideIcons.search,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: AppSizes.p12),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.5,
                  ),
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveStreamCard extends StatefulWidget {
  const LiveStreamCard({
    super.key,
    required this.index,
    required this.title,
    required this.hostName,
    required this.viewersLabel,
    required this.liveBadgeLabel,
    this.onTap,
  });

  final int index;
  final String title;
  final String hostName;
  final String viewersLabel;
  final String liveBadgeLabel;
  final VoidCallback? onTap;

  @override
  State<LiveStreamCard> createState() => _LiveStreamCardState();
}

class _LiveStreamCardState extends State<LiveStreamCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SafeNetworkImage(
                imageUrl:
                    'https://picsum.photos/400/600?random=${widget.index + 200}',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorIcon: LucideIcons.image,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: AppSizes.p12,
                left: AppSizes.p12,
                right: AppSizes.p12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FadeTransition(
                      opacity: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.p6,
                          vertical: AppSizes.p4,
                        ),
                        decoration: BoxDecoration(
                          color: LivesLayoutConstants.liveBadgeColor,
                          borderRadius: BorderRadius.circular(AppSizes.p8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 6,
                            ),
                            const SizedBox(width: AppSizes.p4),
                            Text(
                              widget.liveBadgeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.p10),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.p6,
                            vertical: AppSizes.p4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppSizes.p10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.user,
                                color: Colors.white,
                                size: 10,
                              ),
                              const SizedBox(width: AppSizes.p4),
                              Text(
                                widget.viewersLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: AppSizes.p12,
                left: AppSizes.p12,
                right: AppSizes.p12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black45),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.p8),
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            image: DecorationImage(
                              image: CachedNetworkImageProvider(
                                'https://i.pravatar.cc/100?u=${widget.index + 50}',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.p6),
                        Expanded(
                          child: Text(
                            widget.hostName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(blurRadius: 4, color: Colors.black45),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
