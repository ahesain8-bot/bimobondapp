part of '../video_post_widget.dart';

/// Optimistic like / save / follow / repost / comments for a feed post.
mixin VideoPostEngagementMixin on State<VideoPostWidget> {
  late bool isLiked;
  late int likeCount;
  late int commentCount;
  late bool isSaved;
  late int saveCount;
  late int shareCount;
  late bool isReposted;
  late int repostCount;
  late List<RepostUserEntity> recentReposters;
  String? repostQuote;
  bool pendingRepostToggle = false;
  bool isFollowing = false;
  bool isFollowLoading = false;
  bool followStatusResolved = false;

  AnimationController get likeAnimController;
  GlobalKey get commentActionKey;
  GlobalKey get shareActionKey;
  bool get engagementPlaybackActive;

  void initEngagementState() {
    isLiked = widget.post.isLiked;
    likeCount = widget.post.likeCount;
    commentCount = widget.post.commentCount;
    isSaved = widget.post.isSaved;
    saveCount = widget.post.saveCount;
    shareCount = widget.post.shareCount;
    isReposted = widget.post.isReposted;
    repostCount = widget.post.repostCount;
    recentReposters = List<RepostUserEntity>.from(widget.post.recentReposters);
    repostQuote = initialRepostQuote();
    _syncFollowStateFromPost();
  }

  void syncEngagementFromPost() {
    isLiked = widget.post.isLiked;
    likeCount = widget.post.likeCount;
    commentCount = widget.post.commentCount;
    isSaved = widget.post.isSaved;
    saveCount = widget.post.saveCount;
    shareCount = widget.post.shareCount;
    isReposted = widget.post.isReposted;
    repostCount = widget.post.repostCount;
    recentReposters = List<RepostUserEntity>.from(widget.post.recentReposters);
    repostQuote = initialRepostQuote();
    _syncFollowStateFromPost();
    isFollowLoading = false;
  }

  void _syncFollowStateFromPost() {
    final authorId = postAuthorUserId();
    final fromPost = widget.post.user?.isFollowing;

    if (fromPost != null) {
      isFollowing = fromPost;
      followStatusResolved = true;
      if (authorId != null && authorId.isNotEmpty) {
        FeedAuthorFollowCache.instance.put(authorId, fromPost);
      }
      return;
    }

    if (authorId != null && authorId.isNotEmpty) {
      final cached = FeedAuthorFollowCache.instance.lookup(authorId);
      if (cached != null) {
        isFollowing = cached;
        followStatusResolved = true;
        return;
      }
    }

    isFollowing = false;
    followStatusResolved = false;
  }

  void recordViewIfNeeded() {
    _startViewWatchTracking();
  }

  DateTime? _viewWatchStartedAt;
  int _accumulatedWatchMs = 0;
  bool _viewWatchTracking = false;
  bool? _cachedIsOwner;
  Timer? _viewEligibleTimer;
  bool _viewEligible = false;
  bool _viewRecordedForCurrentOpen = false;

  /// ~1s visible before a view may be sent (duration is measured until leave).
  static const _viewMinVisible = Duration(milliseconds: 1000);

  void _startViewWatchTracking() {
    if (!engagementPlaybackActive || widget.post.isStory) return;
    _cachedIsOwner ??= _safeIsPostOwner();
    if (_cachedIsOwner == true) return;
    if (_viewRecordedForCurrentOpen) return;

    if (!_viewWatchTracking) {
      _viewWatchTracking = true;
      _viewWatchStartedAt = DateTime.now();
    }
    _scheduleViewEligibleTimer();
  }

  void _scheduleViewEligibleTimer() {
    _viewEligibleTimer?.cancel();
    if (_viewEligible || _viewRecordedForCurrentOpen) return;

    final remaining = _viewMinVisible.inMilliseconds - _watchedDurationMs();
    if (remaining <= 0) {
      _viewEligible = true;
      return;
    }
    _viewEligibleTimer = Timer(Duration(milliseconds: remaining), () {
      if (!mounted) return;
      _viewEligible = true;
    });
  }

  void _cancelViewEligibleTimer() {
    _viewEligibleTimer?.cancel();
    _viewEligibleTimer = null;
  }

  void _pauseViewWatchTracking() {
    _cancelViewEligibleTimer();
    if (!_viewWatchTracking) return;
    final started = _viewWatchStartedAt;
    if (started != null) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      if (elapsed > 0) _accumulatedWatchMs += elapsed;
    }
    _viewWatchStartedAt = null;
    _viewWatchTracking = false;
  }

  int _watchedDurationMs() {
    var total = _accumulatedWatchMs;
    final started = _viewWatchStartedAt;
    if (_viewWatchTracking && started != null) {
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      if (elapsed > 0) total += elapsed;
    }
    return total;
  }

  int _watchedDurationSeconds() {
    final ms = _watchedDurationMs();
    if (ms <= 0) return 0;
    final seconds = ms ~/ 1000;
    return seconds > 0 ? seconds : 1;
  }

  bool _safeIsPostOwner() {
    try {
      return isPostOwner();
    } catch (_) {
      return false;
    }
  }

  /// Sends `POST /posts/:id/view` with full [watchedDuration] when leaving.
  void flushPostViewWithWatchDuration({
    String? postId,
    String? trafficSource,
    String? campaignId,
  }) {
    if (widget.post.isStory && postId == null) return;
    _pauseViewWatchTracking();

    final watchedMs = _watchedDurationMs();
    final eligible =
        _viewEligible || watchedMs >= _viewMinVisible.inMilliseconds;
    if (!eligible || _viewRecordedForCurrentOpen) {
      if (!_viewRecordedForCurrentOpen &&
          engagementPlaybackActive &&
          mounted) {
        _startViewWatchTracking();
      }
      return;
    }

    final id = (postId ?? widget.post.id).trim();
    if (id.isEmpty) return;

    final resolvedCampaign = campaignId ??
        ((widget.post.isPromoted || widget.post.isAd)
            ? widget.post.promotion?.id
            : null);

    final owner = postId == null
        ? (_cachedIsOwner ?? _safeIsPostOwner())
        : false;

    final watchedDuration = _watchedDurationSeconds();
    PostViewRecorder.recordIfNeeded(
      postId: id,
      isOwner: owner,
      watchedDuration: watchedDuration,
      campaignId: (resolvedCampaign != null && resolvedCampaign.isNotEmpty)
          ? resolvedCampaign
          : null,
      trafficSource: trafficSource ?? widget.trafficSource,
    );
    _viewRecordedForCurrentOpen = true;
    _viewEligible = false;
    _accumulatedWatchMs = 0;
  }

  void resetViewWatchSession() {
    _cancelViewEligibleTimer();
    _viewWatchTracking = false;
    _viewWatchStartedAt = null;
    _accumulatedWatchMs = 0;
    _viewEligible = false;
    _viewRecordedForCurrentOpen = false;
    _cachedIsOwner = null;
  }

  Future<void> resolveFollowStatusIfNeeded() async {
    if (followStatusResolved || isPostOwner() || !mounted) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    final authorId = postAuthorUserId();
    if (authorId == null || authorId.isEmpty) return;

    final cached = FeedAuthorFollowCache.instance.lookup(authorId);
    if (cached != null) {
      setState(() {
        isFollowing = cached;
        followStatusResolved = true;
      });
      return;
    }

    final pending = FeedAuthorFollowCache.instance.inFlightFor(authorId);
    if (pending != null) {
      final following = await pending;
      if (!mounted || followStatusResolved) return;
      setState(() {
        isFollowing = following;
        followStatusResolved = true;
      });
      return;
    }

    final request = _fetchFollowStatus(
      currentUserId: authState.user.id,
      targetUserId: authorId,
    );
    FeedAuthorFollowCache.instance.trackInFlight(authorId, request);
    final following = await request;
    if (!mounted || followStatusResolved) return;

    FeedAuthorFollowCache.instance.put(authorId, following);
    setState(() {
      isFollowing = following;
      followStatusResolved = true;
    });
  }

  Future<bool> _fetchFollowStatus({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final result = await social_di.sl<CheckIsFollowingUseCase>()(
      CheckIsFollowingParams(
        currentUserId: currentUserId,
        targetUserId: targetUserId,
      ),
    );
    return result.fold((_) => false, (following) => following);
  }

  Future<void> handleFollow() async {
    if (isPostOwner() || isFollowing || isFollowLoading) return;
    if (!checkAuth()) return;

    final userId = postAuthorUserId();
    if (userId == null || userId.isEmpty) return;

    setState(() {
      isFollowLoading = true;
      isFollowing = true;
    });

    final result = await social_di.sl<ToggleFollowUseCase>()(
      ToggleFollowParams(userId),
    );
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          isFollowing = false;
          isFollowLoading = false;
        });
        final authorId = postAuthorUserId();
        if (authorId != null && authorId.isNotEmpty) {
          FeedAuthorFollowCache.instance.put(authorId, false);
        }
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (_) {
        setState(() {
          isFollowing = true;
          isFollowLoading = false;
          followStatusResolved = true;
        });
        final authorId = postAuthorUserId();
        if (authorId != null && authorId.isNotEmpty) {
          FeedAuthorFollowCache.instance.put(authorId, true);
        }
      },
    );
  }

  void handleLike() {
    if (!checkAuth()) return;
    final nextLiked = !isLiked;
    final nextCount = nextLiked ? likeCount + 1 : likeCount - 1;
    setState(() {
      isLiked = nextLiked;
      likeCount = nextCount;
    });
    widget.onFeedPostPatch?.call(
      widget.post.id,
      (post) => post.copyWith(isLiked: nextLiked, likeCount: nextCount),
    );
    likeAnimController.forward(from: 0);
    context.read<PostsBloc>().add(
      ToggleLikePostRequestedEvent(widget.post.id, liked: nextLiked),
    );
  }

  void handleSave() {
    if (!checkAuth()) return;
    final nextSaved = !isSaved;
    final nextCount = nextSaved ? saveCount + 1 : saveCount - 1;
    setState(() {
      isSaved = nextSaved;
      saveCount = nextCount;
    });
    widget.onFeedPostPatch?.call(
      widget.post.id,
      (post) => post.copyWith(isSaved: nextSaved, saveCount: nextCount),
    );
    context.read<PostsBloc>().add(ToggleSavePostRequestedEvent(widget.post.id));

    // TikTok confirms a save with a floating bar; unsaving stays silent there.
    if (!nextSaved) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black.withValues(alpha: 0.88),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: AppSizes.p8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.postSavedToFavorites,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showQuickShare() {
    if (!checkAuth()) return;
    unawaited(
      PostQuickShareBar.showNear(
        context,
        anchorKey: shareActionKey,
        post: widget.post,
      ),
    );
  }

  void handleRepostTap() {
    if (!checkAuth()) return;
    if (isPostOwner()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.cannotRepostOwnPost),
        ),
      );
      return;
    }

    toggleRepost();
  }

  String? initialRepostQuote() {
    final fromFeed = widget.feedItem?.quote?.trim();
    if (fromFeed != null && fromFeed.isNotEmpty) return fromFeed;

    if (widget.post.isReposted) {
      for (final r in widget.post.recentReposters) {
        final q = r.quote?.trim();
        if (q != null && q.isNotEmpty) return q;
      }
    }
    return null;
  }

  RepostUserEntity? currentUserAsReposter() {
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

  void syncRecentRepostersWithState() {
    final me = currentUserAsReposter();
    if (me == null) return;
    recentReposters.removeWhere((r) => r.id == me.id);
    if (isReposted) {
      recentReposters.insert(
        0,
        RepostUserEntity(
          id: me.id,
          username: me.username,
          fullName: me.fullName,
          avatarUrl: me.avatarUrl,
          isVerified: me.isVerified,
          repostedAt: me.repostedAt,
          quote: repostQuote,
        ),
      );
    }
  }

  void toggleRepost({String? quote}) {
    final wasReposted = isReposted;
    final trimmedQuote = quote?.trim();
    setState(() {
      pendingRepostToggle = true;
      isReposted = !wasReposted;
      wasReposted ? repostCount-- : repostCount++;
      if (!wasReposted) {
        repostQuote = trimmedQuote != null && trimmedQuote.isNotEmpty
            ? trimmedQuote
            : null;
      } else {
        repostQuote = null;
      }
      syncRecentRepostersWithState();
    });
    widget.onFeedPostPatch?.call(
      widget.post.id,
      (post) => post.copyWith(
        isReposted: !wasReposted,
        repostCount: !wasReposted
            ? post.repostCount + 1
            : (post.repostCount > 0 ? post.repostCount - 1 : 0),
      ),
    );
    context.read<PostsBloc>().add(
      ToggleRepostPostRequestedEvent(widget.post.id, quote: quote),
    );
  }

  void rollbackRepostToggle() {
    if (!pendingRepostToggle) return;
    setState(() {
      isReposted = !isReposted;
      isReposted ? repostCount++ : repostCount--;
      if (!isReposted) {
        repostQuote = initialRepostQuote();
      }
      syncRecentRepostersWithState();
      pendingRepostToggle = false;
    });
  }

  PostEntity postWithLocalRepostState(PostEntity post) {
    return post.copyWith(
      repostCount: repostCount,
      isReposted: isReposted,
      recentReposters: recentReposters,
    );
  }

  void showComments({int initialTabIndex = 0}) {
    unawaited(openComments(initialTabIndex: initialTabIndex));
  }

  Future<void> openComments({int initialTabIndex = 0}) async {
    final latestCount = await CommentSheetWidget.show(
      context,
      postId: widget.post.id,
      postOwnerId: widget.post.userId,
      likeCount: likeCount,
      commentCount: commentCount,
      viewCount: widget.post.viewCount,
      isPostOwner: isPostOwner(),
      initialTabIndex: initialTabIndex,
    );
    if (!mounted || latestCount == null) return;
    setState(() => commentCount = latestCount);
    widget.onFeedPostPatch?.call(
      widget.post.id,
      (post) => post.copyWith(commentCount: latestCount),
    );
  }

  Future<void> showQuickCommentReactions() async {
    if (!checkAuth()) return;

    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final commentBox =
        commentActionKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || commentBox == null || !commentBox.hasSize) {
      return;
    }

    final commentOffset = commentBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final commentCenter = Offset(
      commentOffset.dx + commentBox.size.width / 2,
      commentOffset.dy + commentBox.size.height / 2,
    );
    final screenSize = overlayBox.size;
    const bubbleGap = 10.0;
    const estimatedBubbleWidth = 292.0;
    const estimatedBubbleHeight = 52.0;

    var left = commentOffset.dx - estimatedBubbleWidth - bubbleGap;
    left = left.clamp(8.0, screenSize.width - estimatedBubbleWidth - 8);
    var top = commentCenter.dy - estimatedBubbleHeight / 2;
    top = top.clamp(8.0, screenSize.height - estimatedBubbleHeight - 8);

    final emoji = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'quick-comment-reactions',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.75, end: 1).animate(curved),
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(22),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final reaction in QuickCommentReactions.emojis)
                            InkWell(
                              onTap: () => Navigator.of(context).pop(reaction),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Text(
                                  reaction,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    height: 1,
                                  ),
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
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );

    if (!mounted || emoji == null || emoji.isEmpty) return;
    postQuickCommentReaction(emoji);
  }

  void postQuickCommentReaction(String emoji) {
    unawaited(
      posts_di.sl<AddCommentUsecase>()(
        AddCommentParams(postId: widget.post.id, content: emoji),
      ),
    );
    setState(() => commentCount++);
    widget.onFeedPostPatch?.call(
      widget.post.id,
      (post) => post.copyWith(commentCount: post.commentCount + 1),
    );
    HapticFeedback.lightImpact();
  }

  bool isPostOwner() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return false;

    final ownerIds = {
      authState.user.id,
      if (authState.user.firebaseUid != null) authState.user.firebaseUid!,
    };
    final postOwnerIds = {
      widget.post.userId,
      if (widget.post.user != null) widget.post.user!.id,
    };
    return ownerIds.any(postOwnerIds.contains);
  }

  String? postAuthorUserId() {
    final user = widget.post.user;
    if (user != null && user.id.isNotEmpty) return user.id;
    if (widget.post.userId.isNotEmpty) return widget.post.userId;
    return null;
  }

  Future<void> openAuthorProfile() async {
    final userId = postAuthorUserId();
    if (userId == null) return;

    final following = await openUserStoryOrProfile(
      context,
      userId: userId,
      username: widget.post.user?.username,
      fullName: widget.post.user?.fullName,
      avatarUrl: widget.post.user?.avatarUrl,
      isFollowing: isFollowing,
    );
    if (!mounted || following == null) return;

    setState(() {
      isFollowing = following;
      followStatusResolved = true;
    });
    FeedAuthorFollowCache.instance.put(userId, following);
  }

  void showMoreOptions() {
    if (!checkAuth()) return;

    PostOptionsSheet.show(
      context,
      post: widget.post,
      isOwner: isPostOwner(),
      onEdit: isPostOwner() ? openEditPost : null,
      onPromote: isPostOwner() && widget.post.canBePromoted
          ? () => context.pushFromFeed('promote_post', extra: widget.post)
          : null,
      onDelete: isPostOwner() ? confirmDeletePost : null,
      onRepost: isPostOwner() ? null : handleRepostTap,
      isReposted: isReposted,
    );
  }

  Future<void> openEditPost() async {
    if (!checkAuth() || !isPostOwner()) return;
    await context.pushFromFeed<PostEntity>('edit_post', extra: widget.post);
  }

  void confirmDeletePost() {
    if (!checkAuth() || !isPostOwner()) return;
    final l10n = AppLocalizations.of(context)!;
    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.deletePostTitle,
      message: l10n.deletePostMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.deleteAction,
      destructive: true,
      onConfirm: () {
        unawaited(deletePostWithLoading(context, postId: widget.post.id));
      },
    );
  }

  bool checkAuth() {
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

  void openPostSound(PostEntity post) {
    final sound = post.sound;
    if (sound == null || sound.id.isEmpty) return;
    unawaited(
      openSoundDetail(
        context,
        soundId: sound.id,
        preferredSegmentId: sound.segmentId,
      ),
    );
  }
}
