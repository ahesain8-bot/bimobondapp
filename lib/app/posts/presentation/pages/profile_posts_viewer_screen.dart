import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/pages/live_details_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/video_post_widget.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_posts_sort.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_tab_posts_state.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/profile_posts_navigation.dart';
import 'package:bimobondapp/core/utils/one_page_scroll_physics.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ProfilePostsViewerScreen extends StatefulWidget {
  const ProfilePostsViewerScreen({
    required this.args,
    super.key,
  });

  final ProfilePostsOpenArgs args;

  @override
  State<ProfilePostsViewerScreen> createState() =>
      _ProfilePostsViewerScreenState();
}

class _ProfilePostsViewerScreenState extends State<ProfilePostsViewerScreen> {
  late final PageController _pageController;
  late List<PostEntity> _posts;
  late int _currentIndex;
  late int _page;
  late bool _hasReachedMax;

  bool _isLoadingMore = false;
  int? _pendingLoadKey;

  @override
  void initState() {
    super.initState();
    _posts = List<PostEntity>.from(widget.args.posts);
    _currentIndex = widget.args.initialIndex.clamp(0, _posts.length - 1);
    _page = widget.args.page;
    _hasReachedMax = widget.args.hasReachedMax;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadMore(_currentIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _maybeLoadMore(index);
  }

  void _maybeLoadMore(int index) {
    if (_hasReachedMax || _isLoadingMore) return;
    if (index < _posts.length - 2) return;
    _fetchNextPage();
  }

  void _fetchNextPage() {
    if (_hasReachedMax || _isLoadingMore) return;

    final authState = context.read<AuthBloc>().state;
    if (widget.args.source == ProfilePostsViewerSource.userPosts) {
      // userPosts handled below.
    } else if (authState is! AuthSuccess) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _page++;
    });

    final loadKey = DateTime.now().microsecondsSinceEpoch;
    _pendingLoadKey = loadKey;
    final nextPage = _page;
    final currentUserId =
        authState is AuthSuccess ? authState.user.id : null;

    switch (widget.args.source) {
      case ProfilePostsViewerSource.ownReposts:
        context.read<PostsBloc>().add(
          FetchMyRepostsRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            profileLoadKey: loadKey,
          ),
        );
        return;
      case ProfilePostsViewerSource.ownPosts:
        context.read<PostsBloc>().add(
          FetchFeedRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            userId: widget.args.userId ?? currentUserId,
            sort: ProfileLayoutConstants.postsSortNewestFirst,
            contentType: FeedContentType.all,
            isStory: false,
            profileLoadKey: loadKey,
          ),
        );
        return;
      case ProfilePostsViewerSource.ownOnlyMe:
        context.read<PostsBloc>().add(
          FetchFeedRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            userId: widget.args.userId ?? currentUserId,
            sort: ProfileLayoutConstants.postsSortNewestFirst,
            privacyStatus: ProfileLayoutConstants.onlyMePrivacyStatus,
            isStory: false,
            profileLoadKey: loadKey,
          ),
        );
        return;
      case ProfilePostsViewerSource.ownLiked:
        context.read<PostsBloc>().add(
          FetchFeedRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            sort: ProfileLayoutConstants.postsSortNewestFirst,
            isLiked: true,
            isStory: false,
            profileLoadKey: loadKey,
          ),
        );
        return;
      case ProfilePostsViewerSource.ownSaved:
        context.read<PostsBloc>().add(
          FetchFeedRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            sort: ProfileLayoutConstants.postsSortNewestFirst,
            isSaved: true,
            isStory: false,
            profileLoadKey: loadKey,
          ),
        );
        return;
      case ProfilePostsViewerSource.userPosts:
        final userId = widget.args.userId;
        if (userId == null || userId.isEmpty) {
          setState(() {
            _isLoadingMore = false;
            _page--;
          });
          return;
        }
        context.read<PostsBloc>().add(
          FetchFeedRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            userId: userId,
            sort: ProfileLayoutConstants.postsSortNewestFirst,
            isStory: false,
            profileLoadKey: loadKey,
          ),
        );
    }
  }

  void _mergeIncoming(List<PostEntity> incoming, bool hasReachedMax) {
    if (!mounted || _pendingLoadKey == null) return;

    var merged = incoming;
    if (widget.args.source == ProfilePostsViewerSource.ownPosts) {
      merged = incoming
          .where(
            (post) =>
                post.privacyStatus !=
                ProfileLayoutConstants.onlyMePrivacyStatus,
          )
          .toList();
    }

    final existingIds = _posts.map((p) => p.id).toSet();
    _posts.addAll(merged.where((p) => !existingIds.contains(p.id)));
    sortProfilePostsNewestFirst(_posts);

    setState(() {
      _hasReachedMax = hasReachedMax;
      _isLoadingMore = false;
      _pendingLoadKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PostsBloc, PostsState>(
      listener: (context, state) {
        if (state is ProfilePostsLoadSuccess &&
            state.profileLoadKey == _pendingLoadKey) {
          _mergeIncoming(state.posts, state.hasReachedMax);
          return;
        }
        if (state is MyRepostsLoadSuccess &&
            state.profileLoadKey == _pendingLoadKey) {
          _mergeIncoming(state.posts, state.hasReachedMax);
          return;
        }
        if (state is PostsFailure && state.profileLoadKey == _pendingLoadKey) {
          setState(() {
            if (_page > widget.args.page) _page--;
            _isLoadingMore = false;
            _pendingLoadKey = null;
          });
          return;
        }
        if (state is DeletePostSuccess) {
          final deletedId = state.postId;
          if (!_posts.any((p) => p.id == deletedId)) return;
          setState(() {
            _posts.removeWhere((p) => p.id == deletedId);
            if (_currentIndex >= _posts.length) {
              _currentIndex = _posts.length - 1;
            }
          });
          if (_posts.isEmpty && mounted) {
            context.pop();
          }
        } else if (state is UpdatePostSuccess) {
          final index = _posts.indexWhere((p) => p.id == state.post.id);
          if (index != -1) {
            setState(() => _posts[index] = state.post);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: CustomAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const DirectionalBackIcon(color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const OnePageScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: _posts.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final post = _posts[index];
            if (post.isAuctionable) {
              return LiveDetailsScreen(post: post, embeddedInFeed: true);
            }
            return VideoPostWidget(
              key: ValueKey(post.id),
              post: post,
              isActive: index == _currentIndex,
              respectFeedPlaybackGate: false,
              bottomPadding: HomeLayoutConstants.feedPostBottomPadding,
            );
          },
        ),
      ),
    );
  }
}
