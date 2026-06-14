import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_page_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/social/presentation/utils/social_follow_toggle.dart';
import 'package:bimobondapp/app/social/presentation/widgets/social_user_list_tile.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum UserConnectionType { following, followers, friends }

class UserConnectionsScreen extends StatefulWidget {
  const UserConnectionsScreen({
    required this.userId,
    required this.type,
    super.key,
  });

  final String userId;
  final UserConnectionType type;

  @override
  State<UserConnectionsScreen> createState() => _UserConnectionsScreenState();
}

class _ConnectionsTabState {
  final List<SocialUserEntity> users = [];
  int page = 1;
  bool hasReachedMax = false;
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasLoaded = false;
  String? errorMessage;
}

class _UserConnectionsScreenState extends State<UserConnectionsScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 20;

  late TabController _tabController;
  late List<_ConnectionsTabState> _tabStates;
  late List<UserConnectionType> _tabTypes;

  final ScrollController _scrollController = ScrollController();
  final Set<String> _followLoadingIds = {};

  @override
  void initState() {
    super.initState();
    _tabTypes = _buildTabTypes();
    _tabStates = List.generate(_tabTypes.length, (_) => _ConnectionsTabState());
    _tabController = TabController(
      length: _tabTypes.length,
      vsync: this,
      initialIndex: _initialTabIndex(),
    );
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadUsers(refresh: true);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  List<UserConnectionType> _buildTabTypes() {
    const baseTabs = [
      UserConnectionType.following,
      UserConnectionType.followers,
    ];
    if (_isOwnProfile) {
      return [...baseTabs, UserConnectionType.friends];
    }
    return baseTabs;
  }

  int _initialTabIndex() {
    final index = _tabTypes.indexOf(widget.type);
    return index >= 0 ? index : 0;
  }

  UserConnectionType get _selectedType => _tabTypes[_tabController.index];

  _ConnectionsTabState get _currentTab => _tabStates[_tabController.index];

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return null;
    return authState.user.id;
  }

  bool get _isOwnProfile {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;
    return currentUserId == widget.userId;
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    final tab = _currentTab;
    if (!tab.hasLoaded && !tab.isLoading) {
      _loadUsers(refresh: true);
    } else {
      setState(() {});
    }
  }

  SocialUserEntity _normalizeUser(SocialUserEntity user) {
    if (!_isOwnProfile) return user;

    switch (_selectedType) {
      case UserConnectionType.followers:
        return user.copyWith(isFollowedBy: true);
      case UserConnectionType.following:
        return user.copyWith(isFollowing: true);
      case UserConnectionType.friends:
        return user.copyWith(isFollowing: true, isFollowedBy: true);
    }
  }

  List<SocialUserEntity> _mergeUsers(
    List<SocialUserEntity> incoming,
    _ConnectionsTabState tab, {
    required bool refresh,
  }) {
    if (!refresh || tab.users.isEmpty) return incoming;

    final followingById = {
      for (final user in tab.users)
        if (user.isFollowing) user.id: true,
    };

    return incoming.map((user) {
      if (followingById[user.id] == true && !user.isFollowing) {
        return user.copyWith(isFollowing: true);
      }
      return user;
    }).toList();
  }

  bool _isSelfUser(SocialUserEntity user) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;
    return user.id == currentUserId;
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

  Future<void> _toggleFollow(int index) async {
    final tab = _currentTab;
    final user = tab.users[index];
    if (_isSelfUser(user) || _followLoadingIds.contains(user.id)) return;
    if (!_ensureLoggedIn()) return;

    final previousFollowing = user.isFollowing;
    setState(() {
      _followLoadingIds.add(user.id);
      tab.users[index] = user.copyWith(isFollowing: !previousFollowing);
    });

    final result = await toggleSocialUserFollow(
      userId: user.id,
      wasFollowing: previousFollowing,
    );
    if (!mounted) return;

    if (result.failure != null) {
      setState(() {
        tab.users[index] = tab.users[index].copyWith(
          isFollowing: previousFollowing,
        );
        _followLoadingIds.remove(user.id);
      });
      PopupDialogs.showErrorDialog(context, result.failure!.message);
      return;
    }

    setState(() {
      tab.users[index] = tab.users[index].copyWith(
        isFollowing: result.isFollowing!,
      );
      _followLoadingIds.remove(user.id);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final tab = _currentTab;
    if (tab.hasReachedMax || tab.isLoadingMore || tab.isLoading) return;

    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent -
            ProfileLayoutConstants.scrollLoadMoreThreshold) {
      _loadUsers(loadMore: true);
    }
  }

  Future<void> _loadUsers({bool refresh = false, bool loadMore = false}) async {
    final tab = _currentTab;

    if (loadMore) {
      if (tab.hasReachedMax || tab.isLoadingMore) return;
      setState(() => tab.isLoadingMore = true);
      tab.page++;
    } else if (refresh) {
      setState(() {
        tab.isLoading = tab.users.isEmpty;
        tab.errorMessage = null;
        tab.page = 1;
        tab.hasReachedMax = false;
      });
    } else {
      setState(() {
        tab.isLoading = true;
        tab.errorMessage = null;
      });
    }

    final result = await _fetchUsersForType(_selectedType, page: tab.page);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          if (loadMore && tab.page > 1) tab.page--;
          tab.isLoading = false;
          tab.isLoadingMore = false;
          if (tab.users.isEmpty) {
            tab.errorMessage = failure.message;
          }
        });
      },
      (pageResult) {
        final normalizedUsers = _mergeUsers(
          pageResult.users.map(_normalizeUser).toList(growable: false),
          tab,
          refresh: tab.page == 1,
        );

        setState(() {
          if (tab.page == 1) {
            tab.users
              ..clear()
              ..addAll(normalizedUsers);
          } else {
            final existingIds = tab.users.map((user) => user.id).toSet();
            tab.users.addAll(
              normalizedUsers.where((user) => !existingIds.contains(user.id)),
            );
          }
          tab.hasReachedMax = pageResult.hasReachedMax;
          tab.isLoading = false;
          tab.isLoadingMore = false;
          tab.hasLoaded = true;
        });
      },
    );
  }

  Future<Either<Failure, SocialUserPageEntity>> _fetchUsersForType(
    UserConnectionType type, {
    required int page,
  }) async {
    switch (type) {
      case UserConnectionType.followers:
        return social_di.sl<GetFollowersUseCase>()(
          GetUserListParams(widget.userId, page: page, limit: _pageSize),
        );
      case UserConnectionType.following:
        return social_di.sl<GetFollowingUseCase>()(
          GetUserListParams(widget.userId, page: page, limit: _pageSize),
        );
      case UserConnectionType.friends:
        return social_di.sl<GetMyFriendsUseCase>()(
          SocialListQuery(page: page, limit: _pageSize),
        );
    }
  }

  String _tabLabel(UserConnectionType type, AppLocalizations l10n) {
    switch (type) {
      case UserConnectionType.following:
        return l10n.following;
      case UserConnectionType.followers:
        return l10n.followers;
      case UserConnectionType.friends:
        return l10n.friendsLabel;
    }
  }

  String _emptyMessage(AppLocalizations l10n) {
    switch (_selectedType) {
      case UserConnectionType.followers:
        return l10n.connectionsEmptyFollowers;
      case UserConnectionType.following:
        return l10n.connectionsEmptyFollowing;
      case UserConnectionType.friends:
        return l10n.connectionsEmptyFriends;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: l10n.connectionsTitle,
        hideBottomDivider: true,
      ),
      body: Column(
        children: [
          Material(
            color: theme.scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.55,
              ),
              indicatorColor: theme.colorScheme.primary,
              dividerColor: theme.dividerColor.withValues(alpha: 0.15),
              tabs: [
                for (final type in _tabTypes) Tab(text: _tabLabel(type, l10n)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadUsers(refresh: true),
              child: _buildBody(l10n, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    final tab = _currentTab;

    if (tab.isLoading && tab.users.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: AppSizes.p16),
          SkeletonWidget(height: 64, borderRadius: AppSizes.radiusMd),
          SizedBox(height: AppSizes.p8),
          SkeletonWidget(height: 64, borderRadius: AppSizes.radiusMd),
          SizedBox(height: AppSizes.p8),
          SkeletonWidget(height: 64, borderRadius: AppSizes.radiusMd),
        ],
      );
    }

    if (tab.errorMessage != null && tab.users.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSizes.p24),
        children: [
          CustomText(
            tab.errorMessage!,
            textAlign: TextAlign.center,
            variant: TextVariant.secondary,
          ),
        ],
      );
    }

    if (tab.users.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSizes.p24),
        children: [
          CustomText(
            _emptyMessage(l10n),
            textAlign: TextAlign.center,
            variant: TextVariant.secondary,
          ),
        ],
      );
    }

    final itemCount =
        tab.users.length + (tab.isLoadingMore && !tab.hasReachedMax ? 1 : 0);

    return ListView.separated(
      key: ValueKey(_selectedType),
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
      itemCount: itemCount,
      separatorBuilder: (context, index) {
        if (index >= tab.users.length - 1) {
          return const SizedBox.shrink();
        }
        return Divider(
          height: 1,
          indent: 72,
          color: theme.dividerColor.withValues(alpha: 0.08),
        );
      },
      itemBuilder: (context, index) {
        if (tab.isLoadingMore &&
            !tab.hasReachedMax &&
            index == tab.users.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.p16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final user = tab.users[index];
        return SocialUserListTile(
          user: user,
          isSelf: _isSelfUser(user),
          isFollowLoading: _followLoadingIds.contains(user.id),
          onFollowTap: () => _toggleFollow(index),
          onProfileFollowStateChanged: (isFollowing) {
            setState(() {
              tab.users[index] = tab.users[index].copyWith(
                isFollowing: isFollowing,
              );
            });
          },
        );
      },
    );
  }
}
