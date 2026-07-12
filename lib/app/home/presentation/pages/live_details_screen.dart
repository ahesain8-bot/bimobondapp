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
import 'package:bimobondapp/app/posts/domain/entities/post_auction_display_utils.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/app/social/domain/entities/follow_status.dart';
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
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
import 'package:bimobondapp/core/utils/comment_sort.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/media_page_indicator.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_options_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
  int? _giftContributionOverride;
  int? _startingPriceOverride;
  bool _isAuctionFinished = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isUIHidden = false;
  Timer? _countdownTimer;
  AuctionSocketService? _auctionSocket;
  StreamSubscription<AuctionUpdatedPayload>? _auctionUpdatedSub;
  StreamSubscription<CommentEntity>? _newCommentSub;
  StreamSubscription<bool>? _socketConnectionSub;
  String? _joinedAuctionId;
  String? _joinedPostId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _bidPopController;
  late Animation<double> _bidPopAnimation;

  int get _streamIndex => widget.post != null
      ? widget.post!.id.hashCode.abs() % 1000
      : widget.index;

  List<PostMediaEntity> get _displayMedia {
    final post = widget.post;
    if (post == null) {
      return [
        PostMediaEntity(
          url: 'https://picsum.photos/800/1200?random=${_streamIndex + 200}',
          mediaType: 'IMAGE',
          order: 0,
        ),
      ];
    }
    return resolveAuctionDisplayMedia(post);
  }

  int get _startingPriceCoins {
    if (_startingPriceOverride != null) return _startingPriceOverride!;
    return widget.post?.auction?.startingPriceCoins ?? 0;
  }

  int get _giftContributionCoins {
    if (_giftContributionOverride != null) return _giftContributionOverride!;
    return widget.post?.auction?.giftContributionCoins ?? 0;
  }

  int get _highestBidCoins => _startingPriceCoins + _giftContributionCoins;

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
    _bidPopAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: LiveDetailsLayoutConstants.bidPopScaleEnd,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: LiveDetailsLayoutConstants.bidPopScaleEnd,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_bidPopController);

    final postId = widget.post?.id;
    if (postId != null) {
      _commentsBloc = di.sl<CommentsBloc>();
      _commentsBloc!.add(
        FetchCommentsRequested(
          postId: postId,
          isRefresh: true,
          sort: 'oldest',
        ),
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
    unawaited(_startAuctionRealtime());
  }

  String? get _auctionId => widget.post?.auction?.id ?? widget.post?.id;

  bool get _isAuctionPost => widget.post != null && widget.post!.isAuctionable;

  Future<void> _startAuctionRealtime() async {
    final post = widget.post;
    if (post == null || post.id.isEmpty) return;

    _auctionSocket = auctions_di.sl<AuctionSocketService>();
    await _auctionSocket!.connect();

    await _auctionUpdatedSub?.cancel();
    await _newCommentSub?.cancel();
    await _socketConnectionSub?.cancel();

    // Post room: newComment events (comment list).
    _newCommentSub = _auctionSocket!.onNewComment.listen(_onRealtimeComment);
    // Auction room: auctionUpdated with lastComment / lastGift / totals.
    _auctionUpdatedSub =
        _auctionSocket!.onAuctionUpdated.listen(_onRealtimeAuctionUpdate);
    _socketConnectionSub =
        _auctionSocket!.onConnectionChanged.listen((connected) {
      if (connected && mounted) {
        _joinAuctionRooms();
      }
    });

    _joinAuctionRooms();
  }

  void _joinAuctionRooms() {
    final post = widget.post;
    final socket = _auctionSocket;
    if (post == null || socket == null || post.id.isEmpty) return;

    socket.joinPost(post.id);
    _joinedPostId = post.id;

    final auctionId = _auctionId;
    if (_isAuctionPost && auctionId != null && auctionId.isNotEmpty) {
      socket.joinAuction(auctionId);
      _joinedAuctionId = auctionId;
    }
  }

  void _stopAuctionRealtime() {
    final socket = _auctionSocket;
    if (socket != null) {
      final auctionId = _joinedAuctionId;
      if (auctionId != null && auctionId.isNotEmpty) {
        socket.leaveAuction(auctionId);
      }
      final postId = _joinedPostId;
      if (postId != null && postId.isNotEmpty) {
        socket.leavePost(postId);
      }
    }

    unawaited(_auctionUpdatedSub?.cancel());
    unawaited(_newCommentSub?.cancel());
    unawaited(_socketConnectionSub?.cancel());
    _auctionUpdatedSub = null;
    _newCommentSub = null;
    _socketConnectionSub = null;
    _joinedAuctionId = null;
    _joinedPostId = null;
  }

  void _onRealtimeComment(CommentEntity comment) {
    if (!mounted) return;
    if (!_matchesCommentUpdate(comment)) return;

    _appendCommentIfNew(comment);

    if (comment.isGift) {
      _bidPopController.forward(from: 0);
    }
  }

  bool _matchesCommentUpdate(CommentEntity comment) {
    final postId = widget.post?.id;
    if (postId == null) return false;

    if (comment.postId.isEmpty || comment.postId == postId) {
      return true;
    }

    return false;
  }

  void _appendCommentIfNew(CommentEntity comment) {
    if (comment.parentId != null) return;
    if (_postComments.any((existing) => existing.id == comment.id)) return;

    setState(() {
      // Sort a copy first — clearing `_postComments` before sort wiped the
      // new comment (gifts looked fine because they refetch the list).
      final updated = sortCommentsOldest([..._postComments, comment]);
      _postComments
        ..clear()
        ..addAll(updated);
    });
    _scrollChatToBottom();
  }

  void _onRealtimeAuctionUpdate(AuctionUpdatedPayload payload) {
    if (!mounted) return;
    if (!_matchesAuctionUpdate(payload)) return;

    var shouldAnimateBid = false;

    setState(() {
      if (payload.startingPriceCoins != null) {
        _startingPriceOverride = payload.startingPriceCoins;
      }
      if (payload.currentTotalCoins != null &&
          payload.currentTotalCoins != _giftContributionCoins) {
        _giftContributionOverride = payload.currentTotalCoins;
        shouldAnimateBid = true;
      }
      if (_isFinishedStatus(payload.status)) {
        _isAuctionFinished = true;
        _pulseController.stop();
      }
    });

    if (payload.hasGiftActivity) {
      shouldAnimateBid = true;
      _refreshAuctionComments();
    }

    final target = payload.targetPriceCoins ??
        widget.post?.auction?.targetPriceCoins ??
        0;
    if (target > 0 && _highestBidCoins >= target) {
      if (!_isAuctionFinished) {
        _completeAuction();
      }
      return;
    }

    if (shouldAnimateBid) {
      _bidPopController.forward(from: 0);
    }
  }

  bool _matchesAuctionUpdate(AuctionUpdatedPayload payload) {
    final postId = widget.post?.id;
    final auctionId = _auctionId;

    if (payload.postId != null &&
        postId != null &&
        payload.postId == postId) {
      return true;
    }

    if (payload.auctionId != null) {
      if (auctionId != null && payload.auctionId == auctionId) return true;
      if (postId != null && payload.auctionId == postId) return true;
    }

    return payload.postId == null && payload.auctionId == null;
  }

  bool _isFinishedStatus(String? status) {
    if (status == null) return false;
    switch (status.toUpperCase()) {
      case 'ENDED':
      case 'FINISHED':
      case 'COMPLETED':
      case 'CLOSED':
        return true;
      default:
        return false;
    }
  }

  void _refreshAuctionComments() {
    final postId = widget.post?.id;
    if (postId == null) return;
    _commentsBloc?.add(
      FetchCommentsRequested(
        postId: postId,
        isRefresh: true,
        sort: 'oldest',
      ),
    );
  }

  void _recordPostViewIfNeeded() {
    final post = widget.post;
    if (post == null || post.isStory) return;
    PostViewRecorder.recordIfNeeded(postId: post.id, isOwner: _isPostOwner());
  }

  @override
  void didUpdateWidget(LiveDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prevTotal = oldWidget.post?.auction?.currentTotalCoins;
    final nextTotal = widget.post?.auction?.currentTotalCoins;
    if (prevTotal != nextTotal) {
      _giftContributionOverride = null;
      _startingPriceOverride = null;
      if (nextTotal != null && nextTotal != prevTotal) {
        _bidPopController.forward(from: 0);
      }
      _syncAuctionFinishedFromGiftTotal();
    }
  }

  void _syncAuctionFinishedFromGiftTotal() {
    final auction = widget.post?.auction;
    if (auction == null || _isAuctionFinished) return;
    final targetCoins = auction.targetPriceCoins;
    if (targetCoins > 0 && _highestBidCoins >= targetCoins) {
      _isAuctionFinished = true;
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _stopAuctionRealtime();
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
      ? (_isAuctionPost || _postComments.isNotEmpty)
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

    final post = widget.post;
    if (post == null) return;

    PostOptionsSheet.show(
      context,
      post: post,
      isOwner: true,
      onPromote: post.canBePromoted
          ? () => context.pushNamed('promote_post', extra: post)
          : null,
      onDelete: _confirmDeletePost,
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

  List<CommentEntity> _mergeCommentsById(
    List<CommentEntity> remote,
    List<CommentEntity> local,
  ) {
    final byId = <String, CommentEntity>{
      for (final comment in remote) comment.id: comment,
    };
    for (final comment in local) {
      byId.putIfAbsent(comment.id, () => comment);
    }

    return sortCommentsOldest(byId.values.toList());
  }

  void _onCommentsState(CommentsState state) {
    if (state is CommentsLoadSuccess) {
      setState(() {
        final existing = List<CommentEntity>.from(_postComments);
        _postComments
          ..clear()
          ..addAll(_mergeCommentsById(state.comments, existing));
      });
      _scrollChatToBottom();
    } else if (state is AddCommentSuccess) {
      _chatController.clear();
      FocusScope.of(context).unfocus();
      _appendCommentIfNew(state.comment);
    } else if (state is CommentsFailure) {
      PopupDialogs.showErrorDialog(context, state.message);
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
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

    final target = widget.post?.auction?.targetPriceCoins;
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

  void _showAuctionGiftsSheet() {
    final auctionId = _auctionId;
    if (auctionId == null || auctionId.isEmpty) return;
    AuctionGiftsSheet.show(context, auctionId: auctionId);
  }

  Future<void> _refreshAfterGift() async {
    final postId = widget.post?.id;
    if (postId != null) {
      _commentsBloc?.add(
        FetchCommentsRequested(
          postId: postId,
          isRefresh: true,
          sort: 'oldest',
        ),
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
    } else {
      _bidPopController.forward(from: 0);
    }
  }

  Future<void> _refreshAuctionGiftTotal(String auctionId) async {
    final result = await auctions_di.sl<GetAuctionDetailsUseCase>()(
      GetAuctionDetailsParams(auctionId: auctionId),
    );
    if (!mounted) return;

    result.fold((_) {}, (details) {
      setState(() {
        _giftContributionOverride = details.currentTotalCoins;
        _startingPriceOverride = details.startingPriceCoins;
        final highest = details.displayHighestPriceCoins;
        if (details.targetPriceCoins > 0 &&
            highest >= details.targetPriceCoins) {
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

    final isFollowing = await (_isAuctionPost
        ? openUserProfile(
            context,
            userId: userId,
            username: widget.post?.user?.username,
            fullName: widget.post?.user?.fullName,
            avatarUrl: _avatarUrl(),
            isFollowing: _isFollowing,
          )
        : openUserStoryOrProfile(
            context,
            userId: userId,
            username: widget.post?.user?.username,
            fullName: widget.post?.user?.fullName,
            avatarUrl: _avatarUrl(),
            isFollowing: _isFollowing,
          ));
    if (!mounted || isFollowing == null) return;
    setState(() => _isFollowing = isFollowing);
  }

  String _hostName(AppLocalizations l10n) {
    final fullName = widget.post?.user?.fullName;
    if (fullName != null && fullName.trim().isNotEmpty) return fullName.trim();
    final username = widget.post?.user?.username;
    if (username != null && username.isNotEmpty) return username;
    return l10n.liveHostName(_streamIndex + 1);
  }

  String? _avatarUrl() {
    final avatar = widget.post?.user?.avatarUrl;
    if (avatar == null || avatar.isEmpty || avatar == 'null') return null;
    return avatar;
  }

  String _bidCurrencyLabel(AppLocalizations l10n) {
    if (widget.post?.auction != null) return l10n.coinsUnit;
    return widget.post?.auction?.currencyCode ?? l10n.currencySar;
  }

  String _formatHighestBid(AppLocalizations l10n) {
    final locale = Localizations.localeOf(context);
    final auction = widget.post?.auction;
    if (auction != null) {
      final amount = formatAuctionPricingCoins(_highestBidCoins, locale);
      return l10n.liveHighestBidAmount(amount, l10n.coinsUnit);
    }
    final amount = LocaleFormatUtils.localizeDigits('$_highestBid', locale);
    return l10n.liveHighestBidAmount(amount, _bidCurrencyLabel(l10n));
  }

  String? _auctionTargetPriceLabel(AppLocalizations l10n) {
    final auction = widget.post?.auction;
    if (auction == null) return null;
    final spend = auction.displayBidderSpendCoins;
    if (spend <= 0) return null;
    return l10n.auctionTargetPrice(
      formatAuctionPricingCoins(spend, Localizations.localeOf(context)),
      l10n.coinsUnit,
    );
  }

  int? get _auctionTargetPrice =>
      widget.post?.auction?.displayBidderSpendCoins.round();

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
    final imageUrls = _displayMedia;
    final hasMultipleMedia = imageUrls.length > 1;
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
            mediaItems: imageUrls,
            pageController: _mediaPageController,
            currentIndex: _currentImageIndex,
            posterUrl: widget.post == null
                ? null
                : MediaUtils.resolveVideoPosterUrl(widget.post!),
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
            onHorizontalDragEnd: hasMultipleMedia
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
                      if (hasMultipleMedia) ...[
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
                        showFollowButton:
                            !isPostOwner &&
                            _hostUserId != null &&
                            !_isAuctionPost,
                        onProfileTap: _hostUserId != null
                            ? _openHostProfile
                            : null,
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
                          showCoinIcon: widget.post?.auction != null,
                          targetPrice: targetPrice,
                          targetPriceLabel: _auctionTargetPriceLabel(l10n),
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
