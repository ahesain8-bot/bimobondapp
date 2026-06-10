import 'dart:async';
import 'dart:ui';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_reposters_sheet.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/repost_entity.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _repostAccent = Color(0xFF2ECC71);
const _avatarRadius = 9.0;
const _quoteAvatarRadius = 12.0;
const _avatarDiameter = _avatarRadius * 2;
const _avatarOverlap = 8.0;
const _cardRadius = 7.0;
const _quoteBoxRadius = 18.0;
const _quoteRotateInterval = Duration(seconds: 3);
const _quoteSlideDuration = Duration(milliseconds: 680);
const _quoteSlideCurve = Cubic(0.22, 1, 0.36, 1);
const _quoteFontSize = 13.0;
const _quoteBubbleHeight = AppSizes.p6 * 2 + _quoteFontSize * 1.2;
const _quoteRowHeight =
    (_quoteAvatarRadius * 2 > _quoteBubbleHeight
        ? _quoteAvatarRadius * 2
        : _quoteBubbleHeight) +
    14;
const _glassBlurSigma = 22.0;

/// TikTok-style repost row shown above the post author username.
class FeedRepostBanner extends StatelessWidget {
  const FeedRepostBanner({
    required this.post,
    this.feedItem,
    this.repostQuote,
    super.key,
  });

  final PostEntity post;
  final FeedItemEntity? feedItem;
  final String? repostQuote;

  bool get _hasRepostContext =>
      feedItem?.isRepost == true ||
      post.repostCount > 0 ||
      post.recentReposters.isNotEmpty ||
      post.isReposted ||
      repostQuote?.trim().isNotEmpty == true ||
      feedItem?.quote?.trim().isNotEmpty == true;

  List<RepostUserEntity> _resolveReposters(BuildContext context) {
    if (feedItem?.isRepost == true && feedItem?.repostedBy != null) {
      final user = _enrichReposter(feedItem!.repostedBy!, post.recentReposters);
      final feedQuote = feedItem!.quote?.trim();
      if (feedQuote != null &&
          feedQuote.isNotEmpty &&
          user.quote?.trim().isEmpty != false) {
        return [
          RepostUserEntity(
            id: user.id,
            username: user.username,
            fullName: user.fullName,
            avatarUrl: user.avatarUrl,
            isVerified: user.isVerified,
            repostedAt: user.repostedAt,
            quote: feedQuote,
          ),
        ];
      }
      return [user];
    }

    final reposters = List<RepostUserEntity>.from(post.recentReposters);

    if (post.isReposted) {
      final me = _currentUserAsReposter(context);
      if (me != null) {
        final existing = reposters.where((r) => r.id == me.id).firstOrNull;
        reposters.removeWhere((r) => r.id == me.id);
        reposters.insert(
          0,
          RepostUserEntity(
            id: me.id,
            username: me.username,
            fullName: me.fullName,
            avatarUrl: me.avatarUrl,
            isVerified: me.isVerified,
            repostedAt: me.repostedAt,
            quote: repostQuote?.trim().isNotEmpty == true
                ? repostQuote!.trim()
                : existing?.quote,
          ),
        );
      }
    }

    return reposters
        .where((r) => r.id.isNotEmpty || r.username.isNotEmpty)
        .toList();
  }

  List<RepostUserEntity> _repostersWithQuotes(
    BuildContext context,
    List<RepostUserEntity> reposters,
  ) {
    final quoted = reposters
        .where((r) => r.quote?.trim().isNotEmpty == true)
        .toList();
    if (quoted.isNotEmpty) return quoted;

    final local = repostQuote?.trim();
    if (local != null && local.isNotEmpty && reposters.isNotEmpty) {
      final first = reposters.first;
      return [
        RepostUserEntity(
          id: first.id,
          username: first.username,
          fullName: first.fullName,
          avatarUrl: first.avatarUrl,
          isVerified: first.isVerified,
          repostedAt: first.repostedAt,
          quote: local,
        ),
      ];
    }

    final fromFeed = feedItem?.quote?.trim();
    if (fromFeed != null && fromFeed.isNotEmpty && reposters.isNotEmpty) {
      final first = reposters.first;
      return [
        RepostUserEntity(
          id: first.id,
          username: first.username,
          fullName: first.fullName,
          avatarUrl: first.avatarUrl,
          isVerified: first.isVerified,
          repostedAt: first.repostedAt,
          quote: fromFeed,
        ),
      ];
    }

    return const [];
  }

  RepostUserEntity _enrichReposter(
    RepostUserEntity user,
    List<RepostUserEntity> recent,
  ) {
    RepostUserEntity enriched = user;
    if (user.avatarUrl?.trim().isNotEmpty != true) {
      for (final r in recent) {
        if (r.id == user.id && r.avatarUrl?.trim().isNotEmpty == true) {
          enriched = RepostUserEntity(
            id: user.id,
            username: user.username,
            fullName: user.fullName,
            avatarUrl: r.avatarUrl,
            isVerified: user.isVerified,
            repostedAt: user.repostedAt,
            quote: user.quote ?? r.quote,
          );
          break;
        }
      }
    }

    if (enriched.quote?.trim().isNotEmpty == true) return enriched;

    for (final r in recent) {
      if (r.id == user.id && r.quote?.trim().isNotEmpty == true) {
        return RepostUserEntity(
          id: enriched.id,
          username: enriched.username,
          fullName: enriched.fullName,
          avatarUrl: enriched.avatarUrl,
          isVerified: enriched.isVerified,
          repostedAt: enriched.repostedAt,
          quote: r.quote,
        );
      }
    }
    return enriched;
  }

  RepostUserEntity? _currentUserAsReposter(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return null;

    final user = authState.user;
    return RepostUserEntity(
      id: user.id,
      username: user.username ?? 'user',
      fullName: user.fullName,
      avatarUrl: user.avatarUrl,
      isVerified: user.isVerified ?? false,
      repostedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasRepostContext) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final reposters = _resolveReposters(context);
    final quotedReposters = _repostersWithQuotes(context, reposters);

    if (feedItem?.isRepost == true) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.p4),
        child: _RepostActivityHeader(
          repostedBy: reposters.isNotEmpty ? reposters.first : feedItem!.repostedBy,
          quotedReposters: quotedReposters,
          postId: post.id,
          repostCount: post.repostCount,
          l10n: l10n,
        ),
      );
    }

    if (post.repostCount <= 0 &&
        reposters.isEmpty &&
        quotedReposters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p4),
      child: _RecentRepostersRow(
        reposters: reposters,
        quotedReposters: quotedReposters,
        repostCount: post.repostCount,
        postId: post.id,
        l10n: l10n,
      ),
    );
  }
}

/// Instagram-style vertical loop: current reply slides up, next rises from below.
class _AnimatedRepostQuotesCarousel extends StatefulWidget {
  const _AnimatedRepostQuotesCarousel({
    required this.reposters,
    this.interval = _quoteRotateInterval,
  });

  final List<RepostUserEntity> reposters;
  final Duration interval;

  @override
  State<_AnimatedRepostQuotesCarousel> createState() =>
      _AnimatedRepostQuotesCarouselState();
}

class _AnimatedRepostQuotesCarouselState
    extends State<_AnimatedRepostQuotesCarousel>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  Timer? _timer;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: _quoteSlideDuration,
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: _quoteSlideCurve,
    );
    _slideController.addStatusListener(_onSlideStatus);
    _startTimer();
  }

  @override
  void didUpdateWidget(_AnimatedRepostQuotesCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reposters.length != widget.reposters.length) {
      _index = 0;
      _slideController.reset();
    }
    if (oldWidget.interval != widget.interval ||
        oldWidget.reposters.length != widget.reposters.length) {
      _restartTimer();
    }
  }

  void _onSlideStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _index = (_index + 1) % widget.reposters.length;
    });
    _slideController.reset();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.reposters.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || _slideController.isAnimating) return;
      _slideController.forward();
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  Widget _quoteLayer(RepostUserEntity user) {
    return SizedBox(
      height: _quoteRowHeight,
      width: double.infinity,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _RepostQuoteReplyCard(user: user),
      ),
    );
  }

  Widget _transitionLayer({
    required RepostUserEntity user,
    required double translateY,
    required double opacity,
    required double scale,
  }) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.scale(
          scale: scale,
          alignment: AlignmentDirectional.centerStart,
          child: _quoteLayer(user),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reposters.isEmpty) return const SizedBox.shrink();

    if (widget.reposters.length == 1) {
      return SizedBox(
        height: _quoteRowHeight,
        width: double.infinity,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: _RepostQuoteReplyCard(user: widget.reposters.first),
        ),
      );
    }

    final current = widget.reposters[_index];
    final next = widget.reposters[(_index + 1) % widget.reposters.length];

    return SizedBox(
      height: _quoteRowHeight,
      width: double.infinity,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, _) {
            final t = _slideAnimation.value;
            final fadeOut = Curves.easeIn.transform(t);
            final fadeIn = Curves.easeOut.transform(t);

            return Stack(
              clipBehavior: Clip.hardEdge,
              alignment: AlignmentDirectional.centerStart,
              children: [
                _transitionLayer(
                  user: next,
                  translateY: (1 - t) * 14,
                  opacity: fadeIn,
                  scale: 0.93 + t * 0.07,
                ),
                _transitionLayer(
                  user: current,
                  translateY: -t * 18,
                  opacity: 1 - fadeOut,
                  scale: 1 - t * 0.05,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Avatar + glass message box for a single repost quote (one line).
class _RepostQuoteReplyCard extends StatelessWidget {
  const _RepostQuoteReplyCard({required this.user, super.key});

  final RepostUserEntity user;

  @override
  Widget build(BuildContext context) {
    final quote = user.quote?.trim() ?? '';
    if (quote.isEmpty) return const SizedBox.shrink();

    final avatarSize = _quoteAvatarRadius * 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - avatarSize - AppSizes.p8)
                .clamp(0.0, double.infinity)
            : double.infinity;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: SafeNetworkAvatar(
                      imageUrl: user.avatarUrl,
                      radius: _quoteAvatarRadius,
                      fallbackText: user.username,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.p8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: _ModernGlassSurface(
                radius: _quoteBoxRadius,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.p8,
                  vertical: AppSizes.p6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.repeat2,
                      size: 13,
                      color: _repostAccent,
                      shadows: [
                        Shadow(color: Colors.black45, blurRadius: 4),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        quote,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: _quoteFontSize,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          letterSpacing: 0.1,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _SurfaceStyle { blur, solidWhite }

class _ModernGlassSurface extends StatelessWidget {
  const _ModernGlassSurface({
    required this.child,
    this.padding,
    this.radius = _cardRadius,
    this.style = _SurfaceStyle.blur,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final _SurfaceStyle style;

  @override
  Widget build(BuildContext context) {
    final decoration = style == _SurfaceStyle.solidWhite
        ? BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          );

    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    if (style == _SurfaceStyle.solidWhite) {
      return DecoratedBox(
        decoration: decoration,
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _glassBlurSigma,
          sigmaY: _glassBlurSigma,
        ),
        child: DecoratedBox(
          decoration: decoration,
          child: content,
        ),
      ),
    );
  }
}

/// Frosted card with reposter avatars + label; repost icon sits outside the card.
class _RepostWhiteCard extends StatelessWidget {
  const _RepostWhiteCard({
    required this.reposters,
    required this.onTap,
    this.label,
    this.maxAvatars = 3,
  });

  final List<RepostUserEntity> reposters;
  final VoidCallback onTap;
  final String? label;
  final int maxAvatars;

  double get _stackWidth {
    final count = reposters.isEmpty ? 1 : reposters.take(maxAvatars).length;
    if (count <= 1) return _avatarDiameter;
    return _avatarDiameter + (count - 1) * _avatarOverlap;
  }

  @override
  Widget build(BuildContext context) {
    final visible = reposters.take(maxAvatars).toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_cardRadius + 6),
        splashColor: _repostAccent.withValues(alpha: 0.12),
        highlightColor: Colors.black.withValues(alpha: 0.04),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ModernGlassSurface(
              padding: const EdgeInsets.fromLTRB(5, 4, 7, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AvatarStack(visible: visible, stackWidth: _stackWidth),
                  if (label != null && label!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          height: 1.1,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              LucideIcons.repeat2,
              size: 20,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.visible, required this.stackWidth});

  final List<RepostUserEntity> visible;
  final double stackWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: stackWidth,
      height: _avatarDiameter,
      child: visible.isEmpty
          ? _ReposterAvatar(user: null)
          : Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < visible.length; i++)
                  PositionedDirectional(
                    start: i * _avatarOverlap,
                    child: _ReposterAvatar(user: visible[i]),
                  ),
              ],
            ),
    );
  }
}

class _ReposterAvatar extends StatelessWidget {
  const _ReposterAvatar({required this.user});

  final RepostUserEntity? user;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: SafeNetworkAvatar(
          imageUrl: user?.avatarUrl,
          radius: _avatarRadius,
          fallbackText: user?.username ?? user?.fullName,
          backgroundColor: Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

class _RepostActivityHeader extends StatelessWidget {
  const _RepostActivityHeader({
    required this.repostedBy,
    required this.quotedReposters,
    required this.postId,
    required this.repostCount,
    required this.l10n,
  });

  final RepostUserEntity? repostedBy;
  final List<RepostUserEntity> quotedReposters;
  final String postId;
  final int repostCount;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final user = repostedBy;
    if (user == null) return const SizedBox.shrink();

    final name = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!
        : user.username;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quotedReposters.isNotEmpty) ...[
            _AnimatedRepostQuotesCarousel(reposters: quotedReposters),
            const SizedBox(height: AppSizes.p8),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _RepostWhiteCard(
              reposters: [user],
              maxAvatars: 1,
              label: l10n.repostedByUser(name),
              onTap: () => PostRepostersSheet.show(
                context: context,
                postId: postId,
                repostCount: repostCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRepostersRow extends StatelessWidget {
  const _RecentRepostersRow({
    required this.reposters,
    required this.quotedReposters,
    required this.repostCount,
    required this.postId,
    required this.l10n,
  });

  final List<RepostUserEntity> reposters;
  final List<RepostUserEntity> quotedReposters;
  final int repostCount;
  final String postId;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quotedReposters.isNotEmpty) ...[
            _AnimatedRepostQuotesCarousel(reposters: quotedReposters),
            const SizedBox(height: AppSizes.p8),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _RepostWhiteCard(
              reposters: reposters,
              label: l10n.repostSuccess,
              onTap: () => PostRepostersSheet.show(
                context: context,
                postId: postId,
                repostCount: repostCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
