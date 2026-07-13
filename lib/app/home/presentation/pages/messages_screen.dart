import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' as auth_di;
import 'package:bimobondapp/core/data/viewed_stories_store.dart';
import 'package:bimobondapp/app/home/presentation/utils/active_stories_registry.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_bloc.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_event.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_state.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart'
    as chats_di;
import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_my_mentions_usecase.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/chats/presentation/utils/inbox_chat_helper.dart';
import 'package:bimobondapp/app/home/presentation/utils/story_flow.dart';
import 'package:bimobondapp/app/home/presentation/utils/story_grouping.dart';
import 'package:bimobondapp/core/utils/post_story_filter.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_active_users_bar.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_conversation_list.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_inbox_action_tile.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_inbox_app_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_mentions_strip.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/app/notifications/presentation/di/notifications_injector.dart'
    as notifications_di;
import 'package:bimobondapp/app/notifications/presentation/services/notification_unread_badge.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MessagesScreen extends StatefulWidget {
  final bool isTabActive;

  const MessagesScreen({super.key, this.isTabActive = false});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late final InboxBloc _inboxBloc;

  @override
  void initState() {
    super.initState();
    _inboxBloc = chats_di.sl<InboxBloc>();
    if (widget.isTabActive) {
      _loadTabData();
    }
  }

  @override
  void didUpdateWidget(MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      _loadTabData();
    }
  }

  void _loadTabData() {
    _inboxBloc.add(const InboxLoadRequested(refresh: true));
  }

  @override
  void dispose() {
    _inboxBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _inboxBloc,
      child: _MessagesScreenBody(isTabActive: widget.isTabActive),
    );
  }
}

class _MessagesScreenBody extends StatefulWidget {
  const _MessagesScreenBody({required this.isTabActive});

  final bool isTabActive;

  @override
  State<_MessagesScreenBody> createState() => _MessagesScreenBodyState();
}

class _MessagesScreenBodyState extends State<_MessagesScreenBody> {
  List<UserMentionEntity> _mentions = [];
  List<InboxChatItem> _cachedInboxItems = [];
  bool _inboxLoadFinished = false;
  bool _isRefreshing = false;
  bool _isLoadingMentions = false;
  bool _mentionsLoaded = false;
  String? _lastFollowerName;
  List<StoryUserGroup> _storyGroups = [];
  StoryUserGroup? _myStoryGroup;
  late final ViewedStoriesStore _viewedStoriesStore;

  @override
  void initState() {
    super.initState();
    _viewedStoriesStore = auth_di.sl<ViewedStoriesStore>();
    _viewedStoriesStore.addListener(_onViewedStoriesChanged);
    _bindViewedStoriesUser();
    if (widget.isTabActive) {
      _loadRecentMentions();
      _loadLastFollower();
      _loadStories();
    }
  }

  void _onViewedStoriesChanged() {
    if (mounted) setState(() {});
  }

  void _bindViewedStoriesUser() {
    _viewedStoriesStore.bindUser(_currentUserId);
  }

  @override
  void didUpdateWidget(covariant _MessagesScreenBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      _loadRecentMentions();
      _loadLastFollower();
      _loadStories();
      notifications_di.sl<NotificationUnreadBadge>().refresh();
    }
  }

  void _loadStories() {
    context.read<PostsBloc>().add(const FetchStoriesRequestedEvent(isRefresh: true));
  }

  void _applyStoriesFromPosts(List<PostEntity> stories) {
    final me = _currentUserId;
    final groups = groupStoriesByUser(stories);
    StoryUserGroup? mine;
    final others = <StoryUserGroup>[];

    for (final group in groups) {
      if (me != null && group.userId == me) {
        mine = group;
      } else {
        others.add(group);
      }
    }

    auth_di.sl<ActiveStoriesRegistry>().updateFromStories(stories);

    setState(() {
      _myStoryGroup = mine;
      _storyGroups = others;
    });
  }

  void _openStoryGroup(StoryUserGroup group) {
    final active = onlyStoryPosts(group.stories);
    if (active.isEmpty) {
      _loadStories();
      return;
    }

    final me = _currentUserId;
    if (me != null && group.userId == me) {
      context.pushNamed(
        'stories_viewer',
        extra: {
          'stories': active,
          'initialIndex': 0,
        },
      );
      return;
    }

    context.pushNamed(
      'stories_viewer',
      extra: {
        'stories': active,
        'initialIndex': 0,
      },
    );
  }

  @override
  void dispose() {
    _viewedStoriesStore.removeListener(_onViewedStoriesChanged);
    super.dispose();
  }

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return authState.user.id;
    return null;
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    final bloc = context.read<InboxBloc>();
    final priorGeneration = switch (bloc.state) {
      InboxLoadSuccess(:final loadGeneration) => loadGeneration,
      InboxFailure(:final loadGeneration) => loadGeneration,
      _ => 0,
    };
    bloc.add(const InboxLoadRequested(refresh: true));
    unawaited(_loadRecentMentions(refresh: true));
    unawaited(_loadLastFollower());
    _loadStories();
    try {
      await bloc.stream
          .firstWhere(
            (s) =>
                s is InboxFailure && s.loadGeneration > priorGeneration ||
                s is InboxLoadSuccess && s.loadGeneration > priorGeneration,
          )
          .timeout(HomeLayoutConstants.tabRefreshTimeout);
    } catch (_) {
      // Timeout — dismiss refresh indicator.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
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

  Future<void> _loadLastFollower() async {
    final userId = _currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _lastFollowerName = null);
      return;
    }

    final result = await social_di.sl<GetFollowersUseCase>()(
      GetUserListParams(userId, page: 1, limit: 1),
    );

    if (!mounted) return;

    result.fold(
      (_) {},
      (page) {
        final follower = page.users.isNotEmpty ? page.users.first : null;
        setState(() {
          _lastFollowerName = follower?.displayName;
        });
      },
    );
  }

  Future<void> _loadRecentMentions({bool refresh = false}) async {
    if (!_ensureLoggedIn()) {
      if (mounted) {
        setState(() {
          _isLoadingMentions = false;
          _mentionsLoaded = true;
          _mentions = [];
        });
      }
      return;
    }

    if (_isLoadingMentions && !refresh) return;

    setState(() {
      _isLoadingMentions = _mentions.isEmpty || refresh;
      if (refresh) _mentionsLoaded = false;
    });

    final result = await social_di.sl<GetMyMentionsUseCase>()(
      const GetMyMentionsParams(
        page: 1,
        limit: MessagesLayoutConstants.recentMentionsPreviewCount,
      ),
    );

    if (!mounted) return;

    result.fold(
      (_) => setState(() {
        _isLoadingMentions = false;
        _mentionsLoaded = true;
        if (refresh) _mentions = [];
      }),
      (page) => setState(() {
        _isLoadingMentions = false;
        _mentionsLoaded = true;
        _mentions = page.mentions
            .take(MessagesLayoutConstants.recentMentionsPreviewCount)
            .toList(growable: true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final userId = _currentUserId ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: MessagesInboxAppBar(
        onComposeTap: () {
          if (!_ensureLoggedIn()) return;
          context.pushNamed('new_chat');
        },
        onSearchTap: () => context.pushNamed('chat_search'),
        onTitleTap: () => context.pushNamed('all_chats'),
      ),
      body: SafeArea(
        top: false,
        child: MultiBlocListener(
          listeners: [
            BlocListener<AuthBloc, AuthState>(
              listener: (context, state) => _bindViewedStoriesUser(),
            ),
            BlocListener<PostsBloc, PostsState>(
              listenWhen: (_, current) =>
                  current is StoriesLoadSuccess ||
                  current is DeletePostSuccess ||
                  (current is CreatePostSuccess && current.post.isStory),
              listener: (context, state) {
                if (state is StoriesLoadSuccess) {
                  _applyStoriesFromPosts(state.stories);
                } else if (state is DeletePostSuccess ||
                    (state is CreatePostSuccess && state.post.isStory)) {
                  _loadStories();
                }
              },
            ),
            BlocListener<InboxBloc, InboxState>(
              listenWhen: (previous, current) =>
                  current is InboxLoadSuccess || current is InboxFailure,
              listener: (context, state) {
                setState(() => _inboxLoadFinished = true);
                if (state is InboxLoadSuccess) {
                  setState(() {
                    _cachedInboxItems = state.chats
                        .map((c) => inboxChatItemFromEntity(c, userId, l10n))
                        .toList();
                  });
                }
              },
            ),
          ],
          child: BlocBuilder<InboxBloc, InboxState>(
            builder: (context, state) {
              final inboxItems = _cachedInboxItems;
              final isInitialLoading =
                  (state is InboxLoading || state is InboxInitial) &&
                  !_inboxLoadFinished;
              final showInboxSkeleton = isInitialLoading || _isRefreshing;
              return RefreshIndicator(
                onRefresh: _onRefresh,
                edgeOffset: MessagesLayoutConstants.refreshEdgeOffset,
                color: primaryColor,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    if (state is InboxFailure && !showInboxSkeleton)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          state.message,
                          style: TextStyle(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (showInboxSkeleton)
                      const MessagesInboxSkeleton()
                    else ...[
                      MessagesActiveUsersBar(
                        storyGroups: _storyGroups,
                        myStoryGroup: _myStoryGroup,
                        onAddStory: () => StoryFlow.start(context),
                        onOpenStoryGroup: _openStoryGroup,
                        isStoryGroupViewed: (group) =>
                            _viewedStoriesStore.isGroupFullyViewed(
                          group.stories,
                        ),
                      ),
                      ListenableBuilder(
                        listenable:
                            notifications_di.sl<NotificationUnreadBadge>(),
                        builder: (context, _) {
                          final badge = notifications_di
                              .sl<NotificationUnreadBadge>();
                          return Column(
                            children: [
                              MessagesInboxActionTile(
                                icon: LucideIcons.users,
                                iconBackground: MessagesLayoutConstants
                                    .activityFollowersColor,
                                title: l10n.messagesNewFollowers,
                                subtitle: _lastFollowerName == null
                                    ? null
                                    : l10n.notificationBodyNewFollower(
                                        _lastFollowerName!,
                                      ),
                                onTap: () {
                                  context.pushNamed('my_followers').then((_) {
                                    if (mounted) _loadLastFollower();
                                  });
                                },
                              ),
                              MessagesInboxActionTile(
                                icon: LucideIcons.heart,
                                iconBackground:
                                    MessagesLayoutConstants.activityLikesColor,
                                title: l10n.messagesActivityTitle,
                                subtitle: l10n.activityInboxSubtitle,
                                badgeCount:
                                    badge.count > 0 ? badge.count : null,
                                showChevron: false,
                                onTap: () {
                                  context.pushNamed('activity').then(
                                    (_) => badge.refresh(),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      MessagesConversationList(
                        items: inboxItems,
                        emptyMessage: l10n.messagesInboxNoMessagesYet,
                        emptyIcon: Icons.chat_bubble_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingMentions && !_mentionsLoaded)
                        const MessagesMentionsStripSkeleton()
                      else if (_mentions.isNotEmpty)
                        MessagesMentionsStrip(
                          mentions: _mentions,
                          onSeeAll: () => context.pushNamed('user_mentions'),
                        ),
                    ],
                    const SizedBox(
                      height: MessagesLayoutConstants.bottomSpacer,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
