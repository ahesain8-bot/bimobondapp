import 'dart:async';

import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/domain/usecases/get_profile_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/get_user_by_id_usecase.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart'
    as auth_di;
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/data/models/post_model.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_auction_query.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/chats/domain/usecases/create_or_get_chat_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart'
    as chats_di;
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/social/presentation/utils/social_follow_toggle.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_connections_screen.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/create_highlight_sheet.dart';
import 'package:bimobondapp/app/social/presentation/widgets/profile_follow_button.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_grid_tile.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_header_section.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_posts_sort.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_format_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_avatar_tap_handler.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_icon_tab_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_posts_load_more.dart';
import 'package:bimobondapp/core/navigation/profile_posts_navigation.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/profile_bio_text.dart';
import 'package:bimobondapp/app/auth/data/datasources/profile_remote_data_source.dart';
import 'package:bimobondapp/app/auth/domain/entities/profile_enums.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/profile/close_friends_sheet.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/profile/user_profile_header_details.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/profile/user_profile_highlights_section.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/profile/user_profile_posts_grid.dart';
import 'package:bimobondapp/app/stories/domain/entities/highlight_entity.dart';
import 'package:bimobondapp/app/home/presentation/pages/stories_viewer_screen.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    required this.userId,
    this.initialUsername,
    this.initialFullName,
    this.initialAvatarUrl,
    this.initialIsFollowing,
    super.key,
  });

  final String userId;
  final String? initialUsername;
  final String? initialFullName;
  final String? initialAvatarUrl;
  final bool? initialIsFollowing;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}



class _UserProfileScreenState extends State<UserProfileScreen> {
  final ProfileRemoteDataSource _profileRemoteDS =
      ProfileRemoteDataSourceImpl();
  List<HighlightEntity> _highlights = [];
  static String? _cachedMyUserId;

  UserEntity? _user;
  String? _errorMessage;
  bool _isLoadingUser = true;
  bool _isFollowing = false;
  bool _isFollowedBy = false;
  bool _isFollowLoading = false;
  bool _isMessageLoading = false;
  int _profileLoadKey = 0;
  int? _fetchingLoadKey;
  Completer<void>? _pullRefreshCompleter;
  final ScrollController _scrollController = ScrollController();
  final _postsState = UserProfilePostsState();
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialIsFollowing ?? false;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfile());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isSelf {
    final rawTarget = widget.userId.trim();
    if (rawTarget == 'me' || rawTarget.isEmpty) return true;

    final target = rawTarget.toLowerCase();
    if (_cachedMyUserId != null && target == _cachedMyUserId!.toLowerCase()) {
      return true;
    }

    // 1. Check against FirebaseAuth logged-in user
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final fUid = firebaseUser.uid.toLowerCase();
      final email = (firebaseUser.email ?? '').toLowerCase();
      if ((fUid.isNotEmpty && target == fUid) || (email.isNotEmpty && target == email)) {
        return true;
      }
    }

    // 2. Check against AuthBloc logged-in user
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      final myId = authState.user.id.toLowerCase();
      final myFUid = (authState.user.firebaseUid ?? '').toLowerCase();
      final myUName = (authState.user.username ?? '').toLowerCase();
      if (myId.isNotEmpty) _cachedMyUserId = authState.user.id;
      if ((myId.isNotEmpty && target == myId) ||
          (myFUid.isNotEmpty && target == myFUid) ||
          (myUName.isNotEmpty && target == myUName)) {
        return true;
      }
    }

    return false;
  }

  String get _effectiveUserId {
    if (_isSelf) return 'me';
    if (widget.userId.isNotEmpty) return widget.userId;
    if (_user != null && _user!.id.isNotEmpty) return _user!.id;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess && authState.user.id.isNotEmpty) {
      return authState.user.id;
    }
    return '';
  }

  List<String> _pinnedPostIds = [];
  List<PostEntity> _pinnedPostsList = [];

  bool _isLoadingHighlights = false;

  Future<void> _loadHighlights() async {
    final isMe = _isSelf;
    final targetUserId = _effectiveUserId;
    if (!isMe && targetUserId.isEmpty) return;

    if (mounted) setState(() => _isLoadingHighlights = true);
    try {
      final highlights = await _profileRemoteDS.getHighlights(
        isMe ? 'me' : targetUserId,
        isMe: isMe,
      );
      if (mounted) {
        final sorted = List<HighlightEntity>.from(highlights);
        sorted.sort((a, b) {
          final aDate = a.createdAt;
          final bDate = b.createdAt;
          if (aDate != null && bDate != null) {
            return bDate.compareTo(aDate);
          }
          return 0;
        });
        setState(() => _highlights = sorted);
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] getHighlights error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHighlights = false);
    }
  }

  Future<void> _loadPinnedPosts() async {
    final isMe = _isSelf;
    final targetUserId = _effectiveUserId;
    if (!isMe && targetUserId.isEmpty) return;

    try {
      final list = await _profileRemoteDS.getPinnedPosts(
        isMe ? 'me' : targetUserId,
        isMe: isMe,
      );
      if (mounted) {
        final posts = <PostEntity>[];
        final ids = <String>[];
        for (final m in list) {
          final id = (m['postId'] ??
                  m['post_id'] ??
                  m['targetId'] ??
                  m['entityId'] ??
                  (m['post'] is Map ? m['post']['id'] : null) ??
                  m['id'])
              ?.toString();
          if (id != null && id.isNotEmpty) ids.add(id);
          if (m['post'] is Map) {
            try {
              posts.add(PostModel.fromJson(Map<String, dynamic>.from(m['post'] as Map)).copyWith(isPinned: true));
            } catch (_) {}
          } else if (m['videoUrl'] != null || m['type'] != null) {
            try {
              posts.add(PostModel.fromJson(Map<String, dynamic>.from(m)).copyWith(isPinned: true));
            } catch (_) {}
          }
        }
        setState(() {
          _pinnedPostIds = ids;
          _pinnedPostsList = posts;
        });
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] getPinnedPosts error: $e');
    }
  }

  Future<void> _togglePinPost(PostEntity post) async {
    final isCurrentlyPinned = _pinnedPostIds.contains(post.id) || post.isPinned;
    PopupDialogs.showLoadingDialog(context);
    try {
      if (isCurrentlyPinned) {
        await _profileRemoteDS.unpinPost(post.id);
      } else {
        await _profileRemoteDS.pinPost(post.id, _pinnedPostIds.length);
      }

      await _loadPinnedPosts();

      if (mounted) {
        setState(() {
          if (isCurrentlyPinned) {
            _pinnedPostIds.remove(post.id);
            _pinnedPostsList.removeWhere((p) => p.id == post.id);
          } else {
            if (!_pinnedPostIds.contains(post.id)) {
              _pinnedPostIds.insert(0, post.id);
            }
            _pinnedPostsList.removeWhere((p) => p.id == post.id);
            _pinnedPostsList.insert(0, post.copyWith(isPinned: true));
          }

          for (var i = 0; i < _postsState.posts.length; i++) {
            final id = _postsState.posts[i].id;
            final isPinned = _pinnedPostIds.contains(id) ||
                (id == post.id
                    ? !isCurrentlyPinned
                    : _postsState.posts[i].isPinned);
            _postsState.posts[i] =
                _postsState.posts[i].copyWith(isPinned: isPinned);
          }
          sortProfilePostsNewestFirst(_postsState.posts);
        });

        final l10n = AppLocalizations.of(context)!;
        PopupDialogs.hideLoadingDialog(context);
        PopupDialogs.showSuccessDialog(
          context,
          isCurrentlyPinned ? l10n.unpinnedSuccess : l10n.pinnedToTopSuccess,
        );
      }
      _fetchPosts(refresh: true);
    } catch (e) {
      if (mounted) {
        PopupDialogs.hideLoadingDialog(context);
        PopupDialogs.showErrorDialog(context, 'Failed to update pin: $e');
      }
    }
  }

  void _showCreateHighlightDialog() {
    CreateHighlightSheet.show(
      context,
      initialStories: _postsState.posts.where((p) => p.isStory).toList(),
      onCreated: (newHighlight) {
        if (mounted) {
          setState(() {
            _highlights.removeWhere((item) => item.id == newHighlight.id);
            _highlights.insert(0, newHighlight);
          });
        }
      },
      onSaved: _loadHighlights,
    );
  }

  void _showHighlightOptions(HighlightEntity h) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_rounded, color: cs.onSurface),
              title: Text(
                l10n.editHighlight,
                style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                CreateHighlightSheet.show(
                  context,
                  existingHighlight: h,
                  onSaved: _loadHighlights,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: Text(
                l10n.deleteHighlight,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await _profileRemoteDS.deleteHighlight(h.id);
                  if (mounted) {
                    PopupDialogs.showSuccessDialog(context, l10n.highlightDeleted);
                    _loadHighlights();
                  }
                } catch (e) {
                  if (mounted) {
                    PopupDialogs.showErrorDialog(context, 'Failed to delete: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onTabSelected(int index) {
    if (_selectedTabIndex == index) return;
    setState(() => _selectedTabIndex = index);
    _fetchPosts(refresh: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_postsState.hasReachedMax ||
        _postsState.isLoadingMore ||
        _postsState.isRefreshing) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent -
            ProfileLayoutConstants.scrollLoadMoreThreshold) {
      _fetchPosts(loadMore: true);
    }
  }

  void _refreshProfile() {
    setState(() {
      _postsState.isRefreshing = true;
    });
    unawaited(_loadUser(showLoadingShell: _user == null));
    _loadHighlights();
    _loadPinnedPosts();
    _fetchPosts(refresh: true);
  }

  Future<void> _refreshProfileAfterNavigation(
    Future<Object?> navigation,
  ) async {
    await navigation;
    if (!mounted) return;
    _refreshProfile();
  }

  Future<void> _loadUser({bool showLoadingShell = true}) async {
    final isInitialLoad = _user == null;
    if (showLoadingShell && isInitialLoad) {
      setState(() {
        _isLoadingUser = true;
        _errorMessage = null;
      });
    }

    if (!_isSelf) {
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        final dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': ApiConstants.apiKey,
              if (token != null) 'Authorization': 'Bearer $token',
            },
          ),
        );
        final relRes = await dio.get(
          ApiConstants.userRelationship(widget.userId),
        );
        if (relRes.statusCode == 200 && relRes.data is Map) {
          final rData = Map<String, dynamic>.from(relRes.data as Map);
          final isBlocked =
              rData['isBlocked'] == true ||
              rData['isBlockedByYou'] == true ||
              rData['isBlockedByThem'] == true;
          if (isBlocked && mounted) {
            setState(() {
              _user = null;
              _isLoadingUser = false;
              _errorMessage = 'user_not_found';
            });
            return;
          }
        }
      } catch (e) {
        debugPrint('UserProfileScreen: Error checking relationship: $e');
      }
    }

    final result = _isSelf
        ? await auth_di.sl<GetProfileUseCase>()(NoParams())
        : await auth_di.sl<GetUserByIdUseCase>()(
            GetUserByIdParams(widget.userId),
          );
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoadingUser = false;
          if (isInitialLoad) {
            _errorMessage = failure.message;
          }
        });
      },
      (user) {
        if (_isSelf && user.id.isNotEmpty) {
          _cachedMyUserId = user.id;
        }
        setState(() {
          _user = user;
          _isLoadingUser = false;
          if (user.isFollowing != null) {
            _isFollowing = user.isFollowing!;
          }
          if (user.isFollowedBy != null) {
            _isFollowedBy = user.isFollowedBy!;
          }
        });
        _loadHighlights();
        if (!_isSelf && user.isFollowing == null) {
          unawaited(_resolveFollowStatus());
        }
      },
    );
  }

  void _fetchPosts({bool refresh = false, bool loadMore = false}) {
    if (loadMore) {
      if (_postsState.hasReachedMax || _postsState.isLoadingMore) return;
      setState(() {
        _postsState.isLoadingMore = true;
        _postsState.page++;
      });
    } else if (refresh) {
      setState(() {
        _postsState.page = 1;
        _postsState.hasReachedMax = false;
        _postsState.isInitialLoading = _postsState.posts.isEmpty;
      });
    } else if (_postsState.posts.isNotEmpty) {
      return;
    } else {
      setState(() {
        _postsState.page = 1;
        _postsState.hasReachedMax = false;
        _postsState.isInitialLoading = true;
      });
    }

    final loadKey = ++_profileLoadKey;
    _postsState.pendingLoadKey = loadKey;
    _fetchingLoadKey = loadKey;

    final bool isRepostsTab =
        _selectedTabIndex == ProfileLayoutConstants.repostsTabIndex;
    final bool isAuctionsTab =
        _selectedTabIndex == ProfileLayoutConstants.auctionsTabIndex;
    final bool isPostsTab =
        _selectedTabIndex == ProfileLayoutConstants.postsTabIndex;

    if (isRepostsTab) {
      if (_isSelf) {
        context.read<PostsBloc>().add(
          FetchMyRepostsRequestedEvent(
            page: _postsState.page,
            limit: UserProfilePostsState.pageSize,
            isRefresh: refresh || _postsState.page == 1,
            profileLoadKey: loadKey,
          ),
        );
      } else {
        context.read<PostsBloc>().add(
          FetchFeedRequestedEvent(
            page: _postsState.page,
            limit: UserProfilePostsState.pageSize,
            userId: widget.userId,
            contentType: FeedContentType.reposts,
            sort: ProfileLayoutConstants.postsSortNewestFirst,
            isRefresh: refresh || _postsState.page == 1,
            isStory: false,
            profileLoadKey: loadKey,
          ),
        );
      }
      return;
    }

    context.read<PostsBloc>().add(
      FetchFeedRequestedEvent(
        page: _postsState.page,
        limit: UserProfilePostsState.pageSize,
        userId: widget.userId,
        sort: ProfileLayoutConstants.postsSortNewestFirst,
        isRefresh: refresh || _postsState.page == 1,
        auctionQuery: isAuctionsTab
            ? const FeedAuctionQuery(isAuctionable: true)
            : isPostsTab
                ? const FeedAuctionQuery(isAuctionable: false)
                : null,
        contentType: isPostsTab ? FeedContentType.all : null,
        isStory: false,
        profileLoadKey: loadKey,
      ),
    );
  }

  Future<void> _onPullToRefresh() async {
    _pullRefreshCompleter = Completer<void>();
    setState(() => _postsState.isRefreshing = true);
    await _loadUser(showLoadingShell: false);
    _loadHighlights();
    _fetchPosts(refresh: true);

    try {
      await _pullRefreshCompleter!.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _postsState.isRefreshing = false;
          _postsState.isInitialLoading = false;
        });
      }
    } finally {
      _pullRefreshCompleter = null;
    }
  }

  Future<void> _resolveFollowStatus() async {
    if (_isSelf || !mounted) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    final result = await social_di.sl<CheckIsFollowingUseCase>()(
      CheckIsFollowingParams(
        currentUserId: authState.user.id,
        targetUserId: widget.userId,
      ),
    );
    if (!mounted) return;

    result.fold((_) {}, (isFollowing) {
      setState(() => _isFollowing = isFollowing);
    });
  }

  bool _ensureLoggedIn() {
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

  Future<void> _toggleFollow() async {
    if (_isSelf || _isFollowLoading) return;
    if (!_ensureLoggedIn()) return;

    final previousFollowing = _isFollowing;
    setState(() {
      _isFollowLoading = true;
      _isFollowing = !previousFollowing;
    });

    final result = await toggleSocialUserFollow(
      userId: widget.userId,
      wasFollowing: previousFollowing,
    );
    if (!mounted) return;

    if (result.failure != null) {
      setState(() {
        _isFollowing = previousFollowing;
        _isFollowLoading = false;
      });
      PopupDialogs.showErrorDialog(context, result.failure!.message);
      return;
    }

    setState(() {
      _isFollowing = result.isFollowing!;
      _isFollowLoading = false;
    });
    unawaited(_loadUser(showLoadingShell: false));
  }

  Future<void> _openMessage() async {
    if (_isSelf || _isMessageLoading) return;
    if (!_ensureLoggedIn()) return;

    setState(() => _isMessageLoading = true);

    final result = await chats_di.sl<CreateOrGetChatUseCase>()(
      CreateOrGetChatParams(participantIds: [widget.userId]),
    );

    if (!mounted) return;

    setState(() => _isMessageLoading = false);

    await result.fold(
      (failure) async {
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (chat) async {
        final user = _displayUser;
        final displayName = user?.fullName?.trim().isNotEmpty == true
            ? user!.fullName!.trim()
            : user?.username ?? widget.initialUsername ?? 'User';
        final avatarUrl = user?.avatarUrl ?? widget.initialAvatarUrl;

        await _refreshProfileAfterNavigation(
          context.pushNamed(
            'chat',
            extra: {
              'chatId': chat.id,
              'username': displayName,
              if (avatarUrl != null && avatarUrl.isNotEmpty)
                'imageUrl': avatarUrl,
              'peerUserId': widget.userId,
            },
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  UserEntity? get _displayUser {
    if (_user != null) return _user;
    if (widget.initialUsername == null &&
        widget.initialFullName == null &&
        widget.initialAvatarUrl == null) {
      return null;
    }
    return UserEntity(
      id: widget.userId,
      username: widget.initialUsername,
      fullName: widget.initialFullName,
      avatarUrl: widget.initialAvatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = _displayUser;
    final username = user?.username ?? widget.initialUsername ?? 'user';
    final displayPostCount = resolveProfilePostsCount(
      apiPostCount: user?.postCount,
      loadedPostsCount: _postsState.posts.length,
      hasLoadedAllPosts:
          _postsState.hasReachedMax && !_postsState.isInitialLoading,
    );

    return BlocListener<PostsBloc, PostsState>(
      listener: (context, state) {
        if (state is ProfilePostsLoadSuccess || state is MyRepostsLoadSuccess) {
          final posts = state is ProfilePostsLoadSuccess
              ? state.posts
              : (state as MyRepostsLoadSuccess).posts;
          final hasReachedMax = state is ProfilePostsLoadSuccess
              ? state.hasReachedMax
              : (state as MyRepostsLoadSuccess).hasReachedMax;
          final loadKey = state is ProfilePostsLoadSuccess
              ? state.profileLoadKey
              : (state as MyRepostsLoadSuccess).profileLoadKey;

          if (_postsState.pendingLoadKey != loadKey) return;

          setState(() {
            if (_postsState.page == 1) {
              _postsState.posts
                ..clear()
                ..addAll(posts);
            } else {
              final existingIds = _postsState.posts.map((p) => p.id).toSet();
              _postsState.posts.addAll(
                posts.where((p) => !existingIds.contains(p.id)),
              );
            }
            for (var i = 0; i < _postsState.posts.length; i++) {
              if (_pinnedPostIds.contains(_postsState.posts[i].id)) {
                _postsState.posts[i] =
                    _postsState.posts[i].copyWith(isPinned: true);
              }
            }
            sortProfilePostsNewestFirst(_postsState.posts);
            _postsState.hasReachedMax = hasReachedMax;
            _postsState.isLoadingMore = false;
            _postsState.isInitialLoading = false;
            _postsState.isRefreshing = false;
          });

          final completer = _pullRefreshCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
        } else if (state is PostsFailure &&
            state.profileLoadKey == _fetchingLoadKey) {
          setState(() {
            if (_postsState.isLoadingMore && _postsState.page > 1) {
              _postsState.page--;
            }
            _postsState.isLoadingMore = false;
            _postsState.isInitialLoading = false;
            _postsState.isRefreshing = false;
          });

          final completer = _pullRefreshCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.pop(_isFollowing);
        },
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: '@$username',
            onBackPressed: () => context.pop(_isFollowing),
            hideBottomDivider: true,
            actions: _isSelf
                ? [
                    IconButton(
                      icon: const Icon(Icons.star_rounded, color: Color(0xFF10B981), size: 20),
                      tooltip: 'Close Friends',
                      onPressed: () => CloseFriendsSheet.show(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.menu_rounded, size: 20),
                      tooltip: 'Settings',
                      onPressed: () => context.pushNamed('settings'),
                    ),
                  ]
                : null,
          ),
          body: (_errorMessage != null || user == null) && !_isLoadingUser
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.p24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        CustomText(
                          l10n.userNotFound,
                          textAlign: TextAlign.center,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          variant: TextVariant.secondary,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onPullToRefresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal:
                                ProfileLayoutConstants.headerHorizontalPadding,
                          ),
                          child: Column(
                            children: [
                              UserProfileHeaderDetails(
                                user: user,
                                userId: widget.userId,
                                username: username,
                                isSelf: _isSelf,
                                isLoadingUser: _isLoadingUser,
                                isFollowing: _isFollowing,
                                isFollowedBy: _isFollowedBy,
                                isFollowLoading: _isFollowLoading,
                                isMessageLoading: _isMessageLoading,
                                displayPostCount: displayPostCount,
                                onToggleFollow: _toggleFollow,
                                onOpenMessage: _openMessage,
                                onNavigateFollowers: () =>
                                    _refreshProfileAfterNavigation(
                                      context.pushNamed(
                                        'user_connections',
                                        extra: {
                                          'userId': widget.userId,
                                          'type':
                                              UserConnectionType.followers,
                                        },
                                      ),
                                    ),
                                onNavigateFollowing: () =>
                                    _refreshProfileAfterNavigation(
                                      context.pushNamed(
                                        'user_connections',
                                        extra: {
                                          'userId': widget.userId,
                                          'type':
                                              UserConnectionType.following,
                                        },
                                      ),
                                    ),
                              ),
                              UserProfileHighlightsSection(
                                highlights: _highlights,
                                isLoading: _isLoadingHighlights,
                                isSelf: _isSelf,
                                onCreateHighlight: _showCreateHighlightDialog,
                                onLongPressHighlight: _showHighlightOptions,
                                onRefreshHighlights: _loadHighlights,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _isSelf
                            ? ProfileIconTabBar(
                                selectedIndex: _selectedTabIndex,
                                onSelected: _onTabSelected,
                                backgroundColor: theme.scaffoldBackgroundColor,
                              )
                            : ProfileUserPostsTabBar(
                                selectedIndex: _selectedTabIndex,
                                onSelected: _onTabSelected,
                                backgroundColor: theme.scaffoldBackgroundColor,
                              ),
                      ),
                      UserProfilePostsGrid(
                        state: _postsState,
                        emptyMessage:
                            _selectedTabIndex == ProfileLayoutConstants.auctionsTabIndex
                                ? 'لا يوجد مزادات حالياً'
                                : l10n.noPostsYet,
                        userId: widget.userId,
                        pinnedPostIds: _pinnedPostIds,
                        pinnedPostsList: _pinnedPostsList,
                        onTogglePin: _isSelf ? _togglePinPost : null,
                        onNavigationReturn: _refreshProfile,
                        isSelf: _isSelf,
                        tabIndex: _selectedTabIndex,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
