import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/comment_sheet_widget.dart';
import 'package:bimobondapp/core/widgets/custom_video_player.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
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
    with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  late AnimationController _musicController;
  final CarouselSliderController _carouselCtrl = CarouselSliderController();

  // Local state for optimistic UI
  late bool _isLiked;
  late int _likeCount;
  late bool _isSaved;
  late int _saveCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likeCount;
    _isSaved = widget.post.isSaved;
    _saveCount = widget.post.saveCount;
    _musicController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();
  }

  @override
  void didUpdateWidget(VideoPostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id || widget.post != oldWidget.post) {
      _isLiked = widget.post.isLiked;
      _likeCount = widget.post.likeCount;
      _isSaved = widget.post.isSaved;
      _saveCount = widget.post.saveCount;
    }
  }

  void _handleLike() {
    if (!_checkAuth()) return;
    setState(() {
      _isLiked = !_isLiked;
      _isLiked ? _likeCount++ : _likeCount--;
    });

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

  void _showPostOptions() {
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
              leading: Icon(LucideIcons.pencil, color: theme.iconTheme.color),
              title: Text(l10n.editPost),
              onTap: () {
                Navigator.pop(sheetContext);
                _openEditPost();
              },
            ),
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
    if (authState is AuthSuccess) {
      return true;
    }

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottom = widget.bottomPadding ?? 30.0;
    final post = widget.post;
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<PostsBloc, PostsState>(
      listenWhen: (previous, current) =>
          current is DeletePostSuccess && current.postId == post.id,
      listener: (context, state) {
        if (state is DeletePostSuccess && state.postId == post.id) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.postDeletedSuccessfully)));
          if (context.canPop()) {
            context.pop();
          }
        }
      },
      child: _buildPostContent(size, bottom, post),
    );
  }

  Widget _buildPostContent(Size size, double bottom, PostEntity post) {
    return Container(
      height: size.height,
      width: size.width,
      color: Colors.black,
      child: Stack(
        children: [
          // Post Content (Video/Image) - Carousel
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

          // Subtle Gradients for readability (must not block swipe gestures)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                    ],
                    stops: const [0.0, 0.2, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Media count at top center (e.g. 1/3)
          if (_displayMedia.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0,
              right: 0,
              child: Center(child: _buildMediaCountBadge(_displayMedia.length)),
            ),

          // Right Side Actions
          Positioned(
            right: 8,
            bottom: bottom + 20,
            child: Column(
              children: [
                _buildProfilePicture(post.user?.avatarUrl),
                const SizedBox(height: 20),
                _buildActionItem(
                  _isLiked ? Icons.favorite : LucideIcons.heart,
                  _formatCount(_likeCount),
                  _isLiked ? Colors.red : Colors.white,
                  onTap: _handleLike,
                ),
                const SizedBox(height: 16),
                _buildActionItem(
                  LucideIcons.messageCircle,
                  '',
                  Colors.white,
                  onTap: _showComments,
                ),
                const SizedBox(height: 16),
                _buildActionItem(
                  _isSaved ? Icons.bookmark : LucideIcons.bookmark,
                  _formatCount(_saveCount),
                  _isSaved ? Colors.yellow : Colors.white,
                  onTap: _handleSave,
                ),
                if (_isPostOwner()) ...[
                  const SizedBox(height: 16),
                  _buildActionItem(
                    LucideIcons.ellipsis,
                    '',
                    Colors.white,
                    onTap: _showPostOptions,
                  ),
                ],
                const SizedBox(height: 25),
                _buildMusicDisc(),
              ],
            ),
          ),

          // Bottom info: centered dots above user caption
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
                  const SizedBox(height: 12),
                ],
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomText(
                        '@${post.user?.username ?? 'user'}',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      const SizedBox(height: 6),
                      CustomText(
                        post.description ?? '',
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                      ),
                      const SizedBox(height: 10),
                      if (post.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.tag,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              CustomText(
                                post.category!,
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.music,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 20,
                              child: CustomText(
                                'Original Sound - @${post.user?.username ?? 'user'}',
                                color: Colors.white,
                                fontSize: 13,
                              ),
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
        ],
      ),
    );
  }

  Widget _buildMediaCountBadge(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: CustomText(
        '${_currentPage + 1}/$total',
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
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
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _currentPage == index ? 8 : 6,
          height: _currentPage == index ? 8 : 6,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture(String? avatarUrl) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: SafeNetworkAvatar(
            imageUrl: avatarUrl,
            radius: 24,
            fallbackText: widget.post.user?.username,
            backgroundColor: Colors.white24,
          ),
        ),
        Positioned(
          bottom: -10,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildMusicDisc() {
    return AnimatedBuilder(
      animation: _musicController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _musicController.value * 2 * 3.14159,
          child: child,
        );
      },
      child: Container(
        width: 45,
        height: 45,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [Colors.black87, Colors.grey, Colors.black87],
          ),
          border: Border.all(color: Colors.black54, width: 8),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.music, color: Colors.white54, size: 12),
        ),
      ),
    );
  }

  Widget _buildActionItem(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 35),
          const SizedBox(height: 4),
          CustomText(
            label,
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ],
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
