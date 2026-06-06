import 'dart:async';
import 'dart:ui';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_state.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as di;
import 'package:bimobondapp/app/posts/presentation/utils/post_view_recorder.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/app/social/domain/entities/follow_status.dart';
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/auctions/domain/usecases/get_auction_details_usecase.dart';
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/auctions/presentation/widgets/auction_gifts_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/live_gift_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/auction_countdown_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/auction_countdown_parts.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/compact_highest_bid.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_bidding_input.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_chat_message.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_details_header.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_media_background.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_mock_chat_area.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_post_comments_area.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/media_page_indicator.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LiveDetailsScreen extends StatefulWidget {
  final int index;
  final PostEntity? post;
  final bool embeddedInFeed;

  const LiveDetailsScreen({
    super.key,
    this.index = 0,
    this.post,
    this.embeddedInFeed = false,
  });

  @override
  State<LiveDetailsScreen> createState() => _LiveDetailsScreenState();
}

class _LiveDetailsScreenState extends State<LiveDetailsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<LiveChatMessage> _mockChatMessages = [];
  final List<CommentEntity> _postComments = [];
  CommentsBloc? _commentsBloc;
  final PageController _mediaPageController = PageController();
  int _currentImageIndex = 0;
  int _highestBid = LiveDetailsLayoutConstants.initialHighestBid;
  double? _giftTotalUsdOverride;
  bool _isAuctionFinished = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isUIHidden = false;
  Timer? _countdownTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _bidPopController;
  late Animation<double> _bidPopAnimation;

  int get _streamIndex => widget.post != null
      ? widget.post!.id.hashCode.abs() % 1000
      : widget.index;

  List<String> get _backgroundImageUrls {
    final post = widget.post;
    if (post == null) {
      return ['https://picsum.photos/800/1200?random=${_streamIndex + 200}'];
    }

    final urls = <String>[];
    void addUrl(String? raw) {
      if (raw == null || raw.isEmpty || raw == 'null') return;
      final resolved = MediaUtils.resolveAbsoluteUrl(raw);
      if (!urls.contains(resolved)) urls.add(resolved);
    }

    addUrl(post.auction?.itemImageUrl);
    final sortedMedia = [...post.media]
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    for (final item in sortedMedia) {
      if (item.mediaType == 'IMAGE') {
        addUrl(item.url);
      }
    }
    if (urls.isEmpty) {
      addUrl(post.thumbnailUrl);
    }
    return urls;
  }

  double get _giftTotalUsd {
    if (_giftTotalUsdOverride != null) return _giftTotalUsdOverride!;
    final auction = widget.post?.auction;
    if (auction != null) return auction.currentTotalUsd;
    return _highestBid.toDouble();
  }

  bool get _usesGiftTotal => widget.post?.auction != null;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: LiveDetailsLayoutConstants.pulseDuration,
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(
          begin: LiveDetailsLayoutConstants.pulseOpacityMin,
          end: LiveDetailsLayoutConstants.pulseOpacityMax,
        ).animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        );

    _bidPopController = AnimationController(
      vsync: this,
      duration: LiveDetailsLayoutConstants.bidPopDuration,
    );
    _bidPopAnimation =
        Tween<double>(
          begin: 1.0,
          end: LiveDetailsLayoutConstants.bidPopScaleEnd,
        ).animate(
          CurvedAnimation(parent: _bidPopController, curve: Curves.elasticOut),
        );

    final postId = widget.post?.id;
    if (postId != null) {
      _commentsBloc = di.sl<CommentsBloc>();
      _commentsBloc!.add(
        FetchCommentsRequested(postId: postId, isRefresh: true),
      );
    }

    if (widget.post?.auction != null) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
      });
    }

    _syncAuctionFinishedFromGiftTotal();
    _recordPostViewIfNeeded();
  }

  void _recordPostViewIfNeeded() {
    final post = widget.post;
    if (post == null || post.isStory) return;
    PostViewRecorder.recordIfNeeded(
      postId: post.id,
      isOwner: _isPostOwner(),
    );
  }

  @override
  void didUpdateWidget(LiveDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prevTotal = oldWidget.post?.auction?.currentTotalUsd;
    final nextTotal = widget.post?.auction?.currentTotalUsd;
    if (prevTotal != nextTotal) {
      _giftTotalUsdOverride = null;
      if (nextTotal != null && nextTotal != prevTotal) {
        _bidPopController.forward(from: 0);
      }
      _syncAuctionFinishedFromGiftTotal();
    }
  }

  void _syncAuctionFinishedFromGiftTotal() {
    final auction = widget.post?.auction;
    if (auction == null || _isAuctionFinished) return;
    final target = auction.targetPriceUsd;
    if (target > 0 && _giftTotalUsd >= target) {
      _isAuctionFinished = true;
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _mediaPageController.dispose();
    _commentsBloc?.close();
    _pulseController.dispose();
    _bidPopController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool get _usesPostComments => widget.post != null;

  bool get _showCommentsArea => _usesPostComments
      ? _postComments.isNotEmpty
      : _mockChatMessages.isNotEmpty;

  List<CommentEntity> get _visiblePostComments =>
      _postComments.where((comment) => comment.parentId == null).toList();

  bool _checkAuth() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return true;

    final l10n = AppLocalizations.of(context)!;
    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.loginRequired,
      message: l10n.loginRequiredMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.login,
      onConfirm: () => context.pushNamed('login'),
    );
    return false;
  }

  bool _isPostOwner() {
    final post = widget.post;
    if (post == null) return false;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return false;

    final ownerIds = {
      authState.user.id,
      if (authState.user.firebaseUid != null) authState.user.firebaseUid!,
    };
    final postOwnerIds = {post.userId, if (post.user != null) post.user!.id};
    return ownerIds.any(postOwnerIds.contains);
  }

  String? get _hostUserId {
    final post = widget.post;
    if (post == null) return null;
    if (post.user?.id.isNotEmpty == true) return post.user!.id;
    if (post.userId.isNotEmpty) return post.userId;
    return null;
  }

  Future<void> _toggleFollow() async {
    if (!_checkAuth() || _isPostOwner() || _isFollowLoading) return;

    final userId = _hostUserId;
    if (userId == null || userId.isEmpty) return;

    setState(() => _isFollowLoading = true);
    final result = await social_di.sl<ToggleFollowUseCase>()(
      ToggleFollowParams(userId),
    );
    if (!mounted) return;

    result.fold(
      (failure) {
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (status) {
        setState(() => _isFollowing = status == FollowStatus.followed);
      },
    );
    setState(() => _isFollowLoading = false);
  }

  void _showOwnerOptions() {
    if (!_checkAuth() || !_isPostOwner()) return;

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.red),
              title: Text(
                l10n.deletePost,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDeletePost();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePost() {
    final post = widget.post;
    if (!_checkAuth() || !_isPostOwner() || post == null) return;

    final l10n = AppLocalizations.of(context)!;

    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.deletePostTitle,
      message: l10n.deletePostMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.deleteAction,
      destructive: true,
      onConfirm: () {
        context.read<PostsBloc>().add(DeletePostRequestedEvent(post.id));
      },
    );
  }

  void _onCommentsState(CommentsState state) {
    if (state is CommentsLoadSuccess) {
      setState(
        () => _postComments
          ..clear()
          ..addAll(state.comments),
      );
      _scrollChatToBottom();
    } else if (state is AddCommentSuccess) {
      _chatController.clear();
      FocusScope.of(context).unfocus();
      final postId = widget.post?.id;
      if (postId != null) {
        _commentsBloc?.add(
          FetchCommentsRequested(postId: postId, isRefresh: true),
        );
      }
    } else if (state is CommentsFailure) {
      PopupDialogs.showErrorDialog(context, state.message);
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          0,
          duration: LiveDetailsLayoutConstants.uiHideDuration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  String _viewersLabel(AppLocalizations l10n) {
    const count = LiveDetailsLayoutConstants.mockViewerCount;
    final formatted = count >= 1000
        ? '${(count / 1000).toStringAsFixed(1)}k'
        : '$count';
    return l10n.liveViewersShort(formatted);
  }

  int? get _auctionTargetPrice => widget.post?.auction?.targetPriceUsd.round();

  bool get _biddingEnabled {
    final auction = widget.post?.auction;
    if (auction == null) return true;
    if (_isAuctionFinished) return false;
    return _isAuctionInPeriod;
  }

  void _completeAuction() {
    if (_isAuctionFinished || !mounted) return;
    setState(() => _isAuctionFinished = true);
    _pulseController.stop();
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.auctionTargetReachedMessage),
        backgroundColor: LiveDetailsLayoutConstants.auctionActiveBadgeDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.p16),
        ),
      ),
    );
  }

  void _addBid(int amount) {
    if (!_biddingEnabled) return;

    final target = _auctionTargetPrice;
    if (target != null && target > 0) {
      final nextBid = _highestBid + amount;
      if (nextBid >= target) {
        setState(() => _highestBid = target);
        _bidPopController.forward(from: 0);
        _completeAuction();
        return;
      }
    }

    setState(() => _highestBid += amount);
    _bidPopController.forward(from: 0);
  }

  void _placeBidOrComment() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final postId = widget.post?.id;
    if (postId != null) {
      if (!_checkAuth()) return;
      _commentsBloc?.add(AddCommentRequested(postId: postId, content: text));
      return;
    }

    setState(() => _mockChatMessages.add(LiveChatMessage(text: text)));
    _chatController.clear();
    FocusScope.of(context).unfocus();
    _scrollChatToBottom();
  }

  String? get _auctionId => widget.post?.auction?.id ?? widget.post?.id;

  bool get _isAuctionPost => widget.post != null && widget.post!.isAuctionable;

  void _showAuctionGiftsSheet() {
    final auctionId = _auctionId;
    if (auctionId == null || auctionId.isEmpty) return;
    AuctionGiftsSheet.show(context, auctionId: auctionId);
  }

  Future<void> _refreshAfterGift() async {
    final postId = widget.post?.id;
    if (postId != null) {
      _commentsBloc?.add(
        FetchCommentsRequested(postId: postId, isRefresh: true),
      );
    }
    context.read<PostsBloc>().add(
      FetchFeedRequestedEvent(
        page: 1,
        limit: HomeLayoutConstants.feedPageSize,
        isRefresh: true,
        isStory: false,
      ),
    );

    final auctionId = _auctionId;
    if (_isAuctionPost && auctionId != null && auctionId.isNotEmpty) {
      await _refreshAuctionGiftTotal(auctionId);
    }
  }

  Future<void> _refreshAuctionGiftTotal(String auctionId) async {
    final result = await auctions_di.sl<GetAuctionDetailsUseCase>()(
      GetAuctionDetailsParams(auctionId: auctionId),
    );
    if (!mounted) return;

    result.fold((_) {}, (details) {
      setState(() {
        _giftTotalUsdOverride = details.currentTotalUsd;
        if (details.targetPriceUsd > 0 &&
            details.currentTotalUsd >= details.targetPriceUsd) {
          if (!_isAuctionFinished) {
            _completeAuction();
          }
        } else {
          _bidPopController.forward(from: 0);
        }
      });
    });
  }

  bool get _canSendGiftToHost => widget.post == null || !_isPostOwner();

  void _showGiftSheet() {
    if (!_canSendGiftToHost) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.liveGiftCannotSendToSelf)));
      return;
    }

    final post = widget.post;
    LiveGiftSheet.show(
      context,
      postId: post?.id,
      receiverId: post?.userId,
      auctionId: _isAuctionPost ? _auctionId : null,
      canSendToHost: _canSendGiftToHost,
      onGiftSent: _refreshAfterGift,
    );
  }

  Future<void> _openHostProfile() async {
    final userId = _hostUserId;
    if (userId == null || userId.isEmpty) return;

    final isFollowing = await openUserStoryOrProfile(
      context,
      userId: userId,
      username: widget.post?.user?.username,
      avatarUrl: _avatarUrl(),
      isFollowing: _isFollowing,
    );
    if (!mounted || isFollowing == null) return;
    setState(() => _isFollowing = isFollowing);
  }

  String _hostName(AppLocalizations l10n) {
    final username = widget.post?.user?.username;
    if (username != null && username.isNotEmpty) return username;
    return l10n.liveHostName(_streamIndex + 1);
  }

  String? _avatarUrl() {
    final avatar = widget.post?.user?.avatarUrl;
    if (avatar == null || avatar.isEmpty || avatar == 'null') return null;
    return avatar;
  }

  String _bidCurrencyLabel(AppLocalizations l10n) =>
      widget.post?.auction != null ? l10n.currencyUsd : l10n.currencySar;

  String _formatHighestBid(AppLocalizations l10n) {
    final locale = Localizations.localeOf(context);
    final total = _giftTotalUsd;
    final text = total == total.roundToDouble()
        ? total.round().toString()
        : total.toStringAsFixed(2);
    final amount = LocaleFormatUtils.localizeDigits(text, locale);
    return l10n.liveHighestBidAmount(amount, _bidCurrencyLabel(l10n));
  }

  bool get _isAuctionInPeriod {
    final auction = widget.post?.auction;
    if (auction == null) return false;
    final now = DateTime.now().toUtc();
    final start = auction.startedAt.toUtc();
    final end = auction.endedAt.toUtc();
    return !now.isBefore(start) && now.isBefore(end);
  }

  AuctionCountdownParts _auctionCountdownParts() {
    if (_isAuctionFinished) {
      return const AuctionCountdownParts.finished();
    }

    final auction = widget.post?.auction;
    if (auction == null) {
      return const AuctionCountdownParts.finished();
    }

    final now = DateTime.now().toUtc();
    final start = auction.startedAt.toUtc();
    final end = auction.endedAt.toUtc();

    if (end.isBefore(now) || end.isAtSameMomentAs(now)) {
      return const AuctionCountdownParts.finished();
    }

    final isUpcoming = start.isAfter(now);
    final diff = (isUpcoming ? start : end).difference(now);
    return AuctionCountdownParts(
      days: diff.inDays,
      hours: diff.inHours.remainder(24),
      minutes: diff.inMinutes.remainder(60),
      seconds: diff.inSeconds.remainder(60),
      isUpcoming: isUpcoming,
      isActive: !isUpcoming && !_isAuctionFinished,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hostName = _hostName(l10n);
    final imageUrls = _backgroundImageUrls;
    final hasMultipleImages = imageUrls.length > 1;
    final isAuctionActive = _isAuctionInPeriod && !_isAuctionFinished;
    final isAuctionFinishedBadge = _isAuctionFinished;
    final targetPrice = _auctionTargetPrice;
    final isPostOwner = _isPostOwner();

    final scaffold = Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          LiveMediaBackground(
            imageUrls: imageUrls,
            pageController: _mediaPageController,
            onPageChanged: (index) =>
                setState(() => _currentImageIndex = index),
          ),
          AnimatedOpacity(
            duration: LiveDetailsLayoutConstants.uiHideDuration,
            opacity: _isUIHidden ? 0 : 1,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.2, 0.45, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isUIHidden = !_isUIHidden),
            onHorizontalDragEnd: hasMultipleImages
                ? null
                : (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity >
                        LiveDetailsLayoutConstants.swipeVelocityThreshold) {
                      setState(() => _isUIHidden = _isRtl ? false : true);
                    } else if (velocity <
                        -LiveDetailsLayoutConstants.swipeVelocityThreshold) {
                      setState(() => _isUIHidden = _isRtl ? true : false);
                    }
                  },
            behavior: HitTestBehavior.translucent,
            child: AnimatedSlide(
              duration: LiveDetailsLayoutConstants.uiHideDuration,
              offset: _isUIHidden
                  ? Offset(
                      _isRtl
                          ? -LiveDetailsLayoutConstants.uiSlideOffset
                          : LiveDetailsLayoutConstants.uiSlideOffset,
                      0,
                    )
                  : Offset.zero,
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                duration: LiveDetailsLayoutConstants.uiHideDuration,
                opacity: _isUIHidden ? 0 : 1,
                child: SafeArea(
                  child: Column(
                    children: [
                      if (hasMultipleImages) ...[
                        const SizedBox(
                          height: LiveDetailsLayoutConstants
                              .mediaPageIndicatorTopPadding,
                        ),
                        MediaPageIndicator(
                          count: imageUrls.length,
                          currentIndex: _currentImageIndex,
                        ),
                        const SizedBox(height: AppSizes.p8),
                      ],
                      LiveDetailsHeader(
                        hostName: hostName,
                        subtitle: widget.post?.auction?.itemName,
                        viewersLabel: _viewersLabel(l10n),
                        avatarUrl: _avatarUrl(),
                        hostUserId: _hostUserId,
                        isFollowing: _isFollowing,
                        followLabel: l10n.liveFollow,
                        followingLabel: l10n.liveFollowing,
                        liveBadgeLabel: isAuctionFinishedBadge
                            ? l10n.auctionFinishedBadge
                            : isAuctionActive
                            ? l10n.auctionActiveBadge
                            : l10n.liveBadge,
                        isAuctionActiveBadge: isAuctionActive,
                        isAuctionFinishedBadge: isAuctionFinishedBadge,
                        pulseAnimation: _pulseAnimation,
                        showCloseButton: !widget.embeddedInFeed,
                        showAuctionGifts: _isAuctionPost,
                        onAuctionGifts: _showAuctionGiftsSheet,
                        showOwnerMenu: isPostOwner,
                        showFollowButton: !isPostOwner && _hostUserId != null,
                        onProfileTap: _hostUserId != null ? _openHostProfile : null,
                        onOwnerMenu: _showOwnerOptions,
                        onClose: () => context.pop(),
                        onFollowTap: _isFollowLoading ? () {} : _toggleFollow,
                        countdownBelowProfile: widget.post?.auction != null
                            ? AuctionCountdownBar(
                                parts: _auctionCountdownParts(),
                              )
                            : null,
                      ),
                      const Expanded(
                        child: IgnorePointer(child: SizedBox.expand()),
                      ),
                      Align(
                        alignment: _isRtl
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: CompactHighestBid(
                          topBidLabel: l10n.liveTopBid,
                          bidAmountText: _formatHighestBid(l10n),
                          showGiftIcon: _usesGiftTotal,
                          targetPrice: targetPrice,
                          targetPriceLabel: targetPrice != null
                              ? l10n.auctionTargetPrice(
                                  LocaleFormatUtils.localizeDigits(
                                    '$targetPrice',
                                    Localizations.localeOf(context),
                                  ),
                                  _bidCurrencyLabel(l10n),
                                )
                              : null,
                          isFinished: _isAuctionFinished,
                          popAnimation: _bidPopAnimation,
                          theme: theme,
                        ),
                      ),
                      if (_showCommentsArea) ...[
                        const SizedBox(height: AppSizes.p12),
                        if (_usesPostComments)
                          LivePostCommentsArea(
                            isRtl: _isRtl,
                            comments: _visiblePostComments,
                            scrollController: _chatScrollController,
                          )
                        else
                          LiveMockChatArea(
                            isRtl: _isRtl,
                            messages: _mockChatMessages,
                            authorLabel: l10n.liveChatYou,
                            scrollController: _chatScrollController,
                          ),
                      ],
                      LiveBiddingInput(
                        controller: _chatController,
                        hintText: _biddingEnabled
                            ? l10n.addCommentHint
                            : l10n.auctionBiddingClosed,
                        enabled: _biddingEnabled,
                        showGiftButton: _canSendGiftToHost,
                        quickBidAmounts: widget.post != null
                            ? const <int>[]
                            : _biddingEnabled
                            ? LiveDetailsLayoutConstants.quickBidAmounts
                            : const <int>[],
                        quickBidLabelBuilder: (amount) =>
                            l10n.liveQuickBid(amount),
                        theme: theme,
                        onSend: _placeBidOrComment,
                        onGift: _biddingEnabled ? _showGiftSheet : () {},
                        onQuickBid: _addBid,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Widget content = scaffold;

    if (widget.post != null) {
      final postId = widget.post!.id;
      content = BlocListener<PostsBloc, PostsState>(
        listenWhen: (previous, current) =>
            current is DeletePostSuccess && current.postId == postId,
        listener: (context, state) {
          if (state is DeletePostSuccess && state.postId == postId) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.postDeletedSuccessfully)),
            );
            if (!widget.embeddedInFeed && context.canPop()) {
              context.pop();
            }
          }
        },
        child: content,
      );
    }

    if (_commentsBloc == null) return content;

    return BlocProvider.value(
      value: _commentsBloc!,
      child: BlocListener<CommentsBloc, CommentsState>(
        listener: (context, state) => _onCommentsState(state),
        child: content,
      ),
    );
  }
}
