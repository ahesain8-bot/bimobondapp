import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_text.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_suggestions_usecase.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/social/presentation/utils/social_follow_toggle.dart';
import 'package:bimobondapp/app/social/presentation/utils/suggestion_follow_toggle.dart';
import 'package:bimobondapp/app/social/presentation/widgets/profile_follow_button.dart';
import 'package:bimobondapp/app/social/presentation/widgets/social_user_list_tile.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
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
  static const int _suggestionsLimit = 20;

  final ScrollController _scrollController = ScrollController();
  final List<SocialUserEntity> _followers = [];
  final List<UserSuggestionEntity> _suggestions = [];
  final Set<String> _followLoadingIds = {};

  int _page = 1;
  bool _hasReachedMax = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingSuggestions = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFollowers(refresh: true);
    _loadSuggestions();
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

  List<SocialUserEntity> _mergeFollowers(
    List<SocialUserEntity> incoming, {
    required bool refresh,
  }) {
    if (!refresh || _followers.isEmpty) return incoming;

    final followingById = {
      for (final user in _followers)
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

        final normalized = _mergeFollowers(
          page.users.map(_normalizeFollower).toList(),
          refresh: refresh,
        );

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

  Future<void> _loadSuggestions() async {
    if (!_ensureLoggedIn()) return;

    setState(() => _isLoadingSuggestions = _suggestions.isEmpty);

    final result = await social_di.sl<GetSuggestionsUseCase>()(
      const GetSuggestionsParams(limit: _suggestionsLimit),
    );

    if (!mounted) return;

    result.fold(
      (_) => setState(() => _isLoadingSuggestions = false),
      (suggestions) => setState(() {
        _isLoadingSuggestions = false;
        _suggestions
          ..clear()
          ..addAll(suggestions.map(UserSuggestionEntity.from));
      }),
    );
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadFollowers(refresh: true),
      _loadSuggestions(),
    ]);
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

    final result = await toggleSocialUserFollow(
      userId: user.id,
      wasFollowing: previousFollowing,
    );
    if (!mounted) return;

    if (result.failure != null) {
      setState(() {
        _followers[index] = _followers[index].copyWith(
          isFollowing: previousFollowing,
        );
        _followLoadingIds.remove(user.id);
      });
      PopupDialogs.showErrorDialog(context, result.failure!.message);
      return;
    }

    setState(() {
      _followers[index] = _followers[index].copyWith(
        isFollowing: result.isFollowing!,
      );
      _followLoadingIds.remove(user.id);
    });
  }

  Future<void> _toggleSuggestionFollow(int index) async {
    if (!_ensureLoggedIn()) return;

    final suggestion = _suggestions[index];
    if (_followLoadingIds.contains(suggestion.id)) return;

    await toggleSuggestionFollow(
      context: context,
      suggestion: suggestion,
      onLoadingChanged: (userId, {required isLoading}) {
        setState(() {
          if (isLoading) {
            _followLoadingIds.add(userId);
          } else {
            _followLoadingIds.remove(userId);
          }
        });
      },
      onUpdate: (updated) {
        setState(() => _suggestions[index] = updated);
      },
    );
  }

  void _onProfileFollowStateChanged(int index, bool isFollowing) {
    setState(() {
      _followers[index] = _followers[index].copyWith(
        isFollowing: isFollowing,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final screenBackground = theme.brightness == Brightness.light
        ? Colors.white
        : theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: screenBackground,
      appBar: CustomAppBar(
        title: l10n.messagesNewFollowers,
        showBackButton: true,
        backgroundColor: screenBackground,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
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

    final showSuggestions =
        _isLoadingSuggestions || _suggestions.isNotEmpty;
    final itemCount = _followers.length +
        (_isLoadingMore ? 1 : 0) +
        (showSuggestions ? 1 + (_isLoadingSuggestions ? 1 : _suggestions.length) : 0);

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: AppSizes.p16),
      itemCount: itemCount == 0 ? 1 : itemCount,
      itemBuilder: (context, index) {
        if (_followers.isEmpty && !showSuggestions) {
          return Padding(
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
          );
        }

        if (index < _followers.length) {
          final user = _followers[index];
          return SocialUserListTile(
            user: user,
            isSelf: _isSelfUser(user),
            isFollowLoading: _followLoadingIds.contains(user.id),
            useActivityCard: true,
            showDivider: index < _followers.length - 1,
            onFollowTap: () => _toggleFollow(index),
            onProfileFollowStateChanged: (isFollowing) =>
                _onProfileFollowStateChanged(index, isFollowing),
          );
        }

        var cursor = _followers.length;
        if (_isLoadingMore) {
          if (index == cursor) {
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
          cursor++;
        }

        if (!showSuggestions) return const SizedBox.shrink();

        if (index == cursor) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              MessagesLayoutConstants.horizontalPadding,
              AppSizes.p20,
              MessagesLayoutConstants.horizontalPadding,
              AppSizes.p8,
            ),
            child: Text(
              l10n.messagesPeopleYouMayKnow,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          );
        }
        cursor++;

        if (_isLoadingSuggestions) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.p24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final suggestionIndex = index - cursor;
        if (suggestionIndex < 0 || suggestionIndex >= _suggestions.length) {
          return const SizedBox.shrink();
        }

        return _SuggestionTile(
          suggestion: _suggestions[suggestionIndex],
          isLoading: _followLoadingIds.contains(
            _suggestions[suggestionIndex].id,
          ),
          showDivider: suggestionIndex < _suggestions.length - 1,
          onFollowTap: () => _toggleSuggestionFollow(suggestionIndex),
          onFollowingChanged: (isFollowing) {
            setState(() {
              _suggestions[suggestionIndex] =
                  _suggestions[suggestionIndex].copyWith(
                isFollowing: isFollowing,
              );
            });
          },
        );
      },
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.isLoading,
    required this.showDivider,
    required this.onFollowTap,
    required this.onFollowingChanged,
  });

  final UserSuggestionEntity suggestion;
  final bool isLoading;
  final bool showDivider;
  final VoidCallback onFollowTap;
  final ValueChanged<bool> onFollowingChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final subtitle = messagesSuggestionReason(
      reason: suggestion.reason,
      mutualCount: suggestion.mutualCount,
      l10n: l10n,
    );

    Future<void> openProfile() async {
      final isFollowing = await openUserStoryOrProfile(
        context,
        userId: suggestion.id,
        username: suggestion.username,
        fullName: suggestion.fullName,
        avatarUrl: suggestion.avatarUrl,
        isFollowing: suggestion.isFollowing,
      );
      if (isFollowing != null) {
        onFollowingChanged(isFollowing);
      }
    }

    return Column(
      children: [
        ListTile(
          onTap: openProfile,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: AppSizes.p4,
          ),
          leading: StoryProfileAvatar(
            userId: suggestion.id,
            imageUrl: suggestion.avatarUrl,
            radius: MessagesLayoutConstants.conversationAvatarRadius,
            fallbackText: suggestion.displayName,
            username: suggestion.username,
            fullName: suggestion.fullName,
            isFollowing: suggestion.isFollowing,
            onTap: openProfile,
          ),
          title: Text(
            suggestion.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: subtitle.isNotEmpty
              ? Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.5,
                    ),
                  ),
                )
              : null,
          trailing: ProfileFollowButton.listTile(
            isFollowing: suggestion.isFollowing,
            isFollowedBy: suggestion.isFollowedBy,
            isLoading: isLoading,
            onPressed: onFollowTap,
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
      ],
    );
  }
}
