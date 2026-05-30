import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/comment_sheet_widget.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart' as social_di;
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:bimobondapp/core/widgets/custom_video_player.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VideoPostWidget extends StatefulWidget {
  final PostEntity post;
  final double? bottomPadding;
  final bool isActive;

  const VideoPostWidget({
    super.key,
    required this.post,
    this.bottomPadding,
    this.isActive = true,
  });

  @override
  State<VideoPostWidget> createState() => _VideoPostWidgetState();
}

class _VideoPostWidgetState extends State<VideoPostWidget>
    with TickerProviderStateMixin {
  int _currentPage = 0;
  late AnimationController _musicController;
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnim;
  final CarouselSliderController _carouselCtrl = CarouselSliderController();

  // Local state for optimistic UI
  late bool _isLiked;
  late int _likeCount;
  late bool _isSaved;
  late int _saveCount;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _followStatusResolved = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likeCount;
    _isSaved = widget.post.isSaved;
    _saveCount = widget.post.saveCount;
    _isFollowing = widget.post.user?.isFollowing ?? false;
    _followStatusResolved = widget.post.user?.isFollowing != null;

    _musicController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _likeAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _likeScaleAnim =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
        ]).animate(
          CurvedAnimation(parent: _likeAnimController, curve: Curves.easeInOut),
        );

    if (widget.isActive) {
      _resolveFollowStatusIfNeeded();
    }
  }

  @override
  void didUpdateWidget(VideoPostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id || widget.post != oldWidget.post) {
      _isLiked = widget.post.isLiked;
      _likeCount = widget.post.likeCount;
      _isSaved = widget.post.isSaved;
      _saveCount = widget.post.saveCount;
      _isFollowing = widget.post.user?.isFollowing ?? false;
      _followStatusResolved = widget.post.user?.isFollowing != null;
      _isFollowLoading = false;
    }

    if (widget.isActive && !oldWidget.isActive) {
      _resolveFollowStatusIfNeeded();
    }
  }

  Future<void> _resolveFollowStatusIfNeeded() async {
    if (_followStatusResolved || _isPostOwner() || !mounted) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    final authorId = _postAuthorUserId();
    if (authorId == null || authorId.isEmpty) return;

    final result = await social_di.sl<CheckIsFollowingUseCase>()(
      CheckIsFollowingParams(
        currentUserId: authState.user.id,
        targetUserId: authorId,
      ),
    );
    if (!mounted) return;

    result.fold((_) {}, (isFollowing) {
      setState(() {
        _isFollowing = isFollowing;
        _followStatusResolved = true;
      });
    });
  }

  Future<void> _handleFollow() async {
    if (_isPostOwner() || _isFollowing || _isFollowLoading) return;
    if (!_checkAuth()) return;

    final userId = _postAuthorUserId();
    if (userId == null || userId.isEmpty) return;

    setState(() {
      _isFollowLoading = true;
      _isFollowing = true;
    });

    final result = await social_di.sl<ToggleFollowUseCase>()(
      ToggleFollowParams(userId),
    );
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isFollowing = false;
          _isFollowLoading = false;
        });
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (_) {
        setState(() {
          _isFollowing = true;
          _isFollowLoading = false;
          _followStatusResolved = true;
        });
      },
    );
  }

  void _handleLike() {
    if (!_checkAuth()) return;
    setState(() {
      _isLiked = !_isLiked;
      _isLiked ? _likeCount++ : _likeCount--;
    });
    _likeAnimController.forward(from: 0);
    context.read<PostsBloc>().add(
      ToggleLikePostRequestedEvent(widget.post.id, liked: _isLiked),
    );
  }

  void _handleSave() {
    if (!_checkAuth()) return;
    setState(() {
      _isSaved = !_isSaved;
      _isSaved ? _saveCount++ : _saveCount--;
    });
    context.read<PostsBloc>().add(ToggleSavePostRequestedEvent(widget.post.id));
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentSheetWidget(
        postId: widget.post.id,
        postOwnerId: widget.post.userId,
      ),
    );
  }

  bool _isPostOwner() {
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

  String? _postAuthorUserId() {
    final user = widget.post.user;
    if (user != null && user.id.isNotEmpty) return user.id;
    if (widget.post.userId.isNotEmpty) return widget.post.userId;
    return null;
  }

  Future<void> _openAuthorProfile() async {
    final userId = _postAuthorUserId();
    if (userId == null) return;

    final isFollowing = await openUserProfile(
      context,
      userId: userId,
      username: widget.post.user?.username,
      avatarUrl: widget.post.user?.avatarUrl,
      isFollowing: _isFollowing,
    );
    if (!mounted || isFollowing == null) return;

    setState(() {
      _isFollowing = isFollowing;
      _followStatusResolved = true;
    });
  }

  void _showPostOptions() {
    if (!_checkAuth() || !_isPostOwner()) return;

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        LucideIcons.pencil,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      l10n.editPost,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openEditPost();
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.trash2,
                        color: Colors.red,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      l10n.deletePost,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmDeletePost();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditPost() async {
    if (!_checkAuth() || !_isPostOwner()) return;
    await context.pushNamed<PostEntity>('edit_post', extra: widget.post);
  }

  void _confirmDeletePost() {
    if (!_checkAuth() || !_isPostOwner()) return;
    final l10n = AppLocalizations.of(context)!;
    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.deletePostTitle,
      message: l10n.deletePostMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.deleteAction,
      destructive: true,
      onConfirm: () {
        context.read<PostsBloc>().add(DeletePostRequestedEvent(widget.post.id));
      },
    );
  }

  List<PostMediaEntity> get _displayMedia {
    if (widget.post.media.isNotEmpty) return widget.post.media;
    final videoUrl = widget.post.videoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      return [PostMediaEntity(url: videoUrl, mediaType: 'VIDEO', order: 0)];
    }
    return [];
  }

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

  Widget _buildMediaItem(PostMediaEntity media, int index) {
    final mediaUrl = MediaUtils.resolveAbsoluteUrl(media.url);
    final isVideo =
        MediaUtils.isVideo(mediaUrl, mediaType: media.mediaType) ||
        widget.post.type == 'VIDEO';
    return SizedBox(
      key: ValueKey('${mediaUrl}_$index'),
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: Center(
        child: isVideo
            ? CustomVideoPlayer(
                url: mediaUrl,
                posterUrl: MediaUtils.resolveVideoPosterUrl(widget.post),
                isActive: widget.isActive,
              )
            : mediaUrl.isEmpty
            ? const Icon(LucideIcons.imageOff, size: 80, color: Colors.white24)
            : SafeNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorIcon: LucideIcons.imageOff,
              ),
      ),
    );
  }

  @override
  void dispose() {
    _musicController.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottom = widget.bottomPadding ?? 30.0;
    final post = widget.post;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocListener<PostsBloc, PostsState>(
      listenWhen: (previous, current) =>
          current is DeletePostSuccess && current.postId == post.id,
      listener: (context, state) {
        if (state is DeletePostSuccess && state.postId == post.id) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.postDeletedSuccessfully)));
          if (context.canPop()) context.pop();
        }
      },
      child: _buildPostContent(size, bottom, post, theme),
    );
  }

  Widget _buildPostContent(
    Size size,
    double bottom,
    PostEntity post,
    ThemeData theme,
  ) {
    return Container(
      height: size.height,
      width: size.width,
      color: Colors.black,
      child: Stack(
        children: [
          // ── Media Carousel ───────────────────────────────────────────────
          CarouselSlider.builder(
            carouselController: _carouselCtrl,
            itemCount: _displayMedia.length,
            options: CarouselOptions(
              height: size.height,
              viewportFraction: 1.0,
              enableInfiniteScroll: false,
              scrollDirection: Axis.horizontal,
              scrollPhysics: _displayMedia.length > 1
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (index, reason) {
                setState(() => _currentPage = index);
              },
            ),
            itemBuilder: (context, index, _) =>
                _buildMediaItem(_displayMedia[index], index),
          ),

          // ── Gradient Overlay ─────────────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.15, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Media Count Badge ─────────────────────────────────────────────
          if (_displayMedia.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(child: _buildMediaCountBadge(_displayMedia.length)),
            ),

          // ── Right Side Actions ────────────────────────────────────────────
          Positioned(
            right: 10,
            bottom: bottom + 20,
            child: Column(
              children: [
                _buildProfileAvatar(post.user?.avatarUrl, theme),
                const SizedBox(height: 24),
                _buildLikeButton(theme),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: LucideIcons.messageCircle,
                  label: '',
                  color: Colors.white,
                  onTap: _showComments,
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  icon: _isSaved ? Icons.bookmark : LucideIcons.bookmark,
                  label: _formatCount(_saveCount),
                  color: _isSaved ? Colors.amberAccent : Colors.white,
                  onTap: _handleSave,
                ),
                if (_isPostOwner()) ...[
                  const SizedBox(height: 20),
                  _buildActionButton(
                    icon: LucideIcons.ellipsis,
                    label: '',
                    color: Colors.white,
                    onTap: _showPostOptions,
                  ),
                ],
                const SizedBox(height: 28),
                _buildMusicDisc(theme),
              ],
            ),
          ),

          // ── Bottom Info ───────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_displayMedia.length > 1) ...[
                  IgnorePointer(
                    child: _buildMediaPageDots(_displayMedia.length),
                  ),
                  const SizedBox(height: 16),
                ],
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 88),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Username
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _openAuthorProfile,
                            child: Text(
                              '@${post.user?.username ?? 'user'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 0.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Description
                      if ((post.description ?? '').isNotEmpty)
                        Text(
                          post.description!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            height: 1.4,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 10),

                      // Category Chip
                      if (post.category != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.tag,
                                    color: Colors.white,
                                    size: 11,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    post.category!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),

                      // Music row
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.music,
                                  color: Colors.white70,
                                  size: 12,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Original Sound · @${post.user?.username ?? 'user'}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCountBadge(int total) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Text(
            '${_currentPage + 1}/$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPageDots(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: List.generate(
        total,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _currentPage == index ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(String? avatarUrl, ThemeData theme) {
    final showFollowBadge = !_isPostOwner();

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _openAuthorProfile,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: SafeNetworkAvatar(
              imageUrl: avatarUrl,
              radius: 24,
              fallbackText: widget.post.user?.username,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
        if (showFollowBadge)
          Positioned(
            bottom: -10,
            child: GestureDetector(
              onTap: _isFollowing ? null : _handleFollow,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  gradient: _isFollowing
                      ? null
                      : LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: _isFollowing ? Colors.white : null,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isFollowing ? Colors.white : Colors.black,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: _isFollowLoading
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        _isFollowing ? Icons.check : Icons.add,
                        color: _isFollowing
                            ? theme.colorScheme.primary
                            : Colors.white,
                        size: 15,
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLikeButton(ThemeData theme) {
    return GestureDetector(
      onTap: _handleLike,
      child: Column(
        children: [
          ScaleTransition(
            scale: _likeScaleAnim,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLiked
                    ? Colors.red.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: _isLiked
                      ? Colors.red.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.2),
                ),
                boxShadow: _isLiked
                    ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _isLiked ? Icons.favorite : LucideIcons.heart,
                color: _isLiked ? Colors.red : Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _formatCount(_likeCount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMusicDisc(ThemeData theme) {
    return AnimatedBuilder(
      animation: _musicController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _musicController.value * 2 * 3.14159,
          child: child,
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.8),
              theme.colorScheme.secondary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.music, color: Colors.white54, size: 12),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
