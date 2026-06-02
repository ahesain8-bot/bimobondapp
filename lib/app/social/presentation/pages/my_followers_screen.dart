import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/social/presentation/widgets/user_follower_list_tile.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MyFollowersScreen extends StatefulWidget {
  const MyFollowersScreen({super.key});

  @override
  State<MyFollowersScreen> createState() => _MyFollowersScreenState();
}

class _MyFollowersScreenState extends State<MyFollowersScreen> {
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  final List<SocialUserEntity> _followers = [];
  final Set<String> _followLoadingIds = {};

  int _page = 1;
  bool _hasReachedMax = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFollowers(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return authState.user.id;
    return null;
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

  SocialUserEntity _normalizeFollower(SocialUserEntity user) {
    return user.copyWith(isFollowedBy: true);
  }

  bool _isSelfUser(SocialUserEntity user) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;
    return user.id == currentUserId;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_hasReachedMax || _isLoading || _isLoadingMore) return;

    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent -
            ProfileLayoutConstants.scrollLoadMoreThreshold) {
      _loadFollowers(loadMore: true);
    }
  }

  Future<void> _loadFollowers({
    bool refresh = false,
    bool loadMore = false,
  }) async {
    final userId = _currentUserId;
    if (!_ensureLoggedIn() || userId == null) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    if (loadMore) {
      if (_hasReachedMax || _isLoadingMore) return;
      setState(() => _isLoadingMore = true);
      _page++;
    } else if (refresh) {
      setState(() {
        _isLoading = _followers.isEmpty;
        _errorMessage = null;
        _page = 1;
        _hasReachedMax = false;
      });
    } else if (_hasLoaded) {
      return;
    } else {
      setState(() => _isLoading = true);
    }

    final result = await social_di.sl<GetFollowersUseCase>()(
      GetUserListParams(userId, page: _page, limit: _pageSize),
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasLoaded = true;
        _errorMessage = failure.message;
        if (loadMore) _page--;
      }),
      (page) => setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasLoaded = true;
        _errorMessage = null;
        _hasReachedMax = page.hasReachedMax;

        final normalized = page.users.map(_normalizeFollower).toList();

        if (refresh) {
          _followers
            ..clear()
            ..addAll(normalized);
        } else {
          final existingIds = _followers.map((user) => user.id).toSet();
          _followers.addAll(
            normalized.where((user) => !existingIds.contains(user.id)),
          );
        }
      }),
    );
  }

  Future<void> _toggleFollow(int index) async {
    final user = _followers[index];
    if (_isSelfUser(user) || _followLoadingIds.contains(user.id)) return;
    if (!_ensureLoggedIn()) return;

    final previousFollowing = user.isFollowing;
    setState(() {
      _followLoadingIds.add(user.id);
      _followers[index] = user.copyWith(isFollowing: !previousFollowing);
    });

    final result = await social_di.sl<ToggleFollowUseCase>()(
      ToggleFollowParams(user.id),
    );
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _followers[index] = user.copyWith(isFollowing: previousFollowing);
          _followLoadingIds.remove(user.id);
        });
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (_) {
        setState(() => _followLoadingIds.remove(user.id));
      },
    );
  }

  void _onProfileFollowStateChanged(int index, bool isFollowing) {
    setState(() {
      _followers[index] = _followers[index].copyWith(isFollowing: isFollowing);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(title: l10n.userFollowersTitle),
      body: RefreshIndicator(
        onRefresh: () => _loadFollowers(refresh: true),
        color: theme.colorScheme.primary,
        child: _buildBody(l10n, theme),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_isLoading) {
      return const UserFollowersListSkeleton();
    }

    if (_errorMessage != null && _followers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    if (_followers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l10n.connectionsEmptyFollowers,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.5,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: _followers.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (context, _) =>
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.08)),
      itemBuilder: (context, index) {
        if (index >= _followers.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final user = _followers[index];
        return UserFollowerListTile(
          user: user,
          isSelf: _isSelfUser(user),
          isFollowLoading: _followLoadingIds.contains(user.id),
          onFollowTap: () => _toggleFollow(index),
          onProfileFollowStateChanged: (isFollowing) =>
              _onProfileFollowStateChanged(index, isFollowing),
        );
      },
    );
  }
}
