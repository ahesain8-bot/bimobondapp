import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_bloc.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_event.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_state.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart'
    as chats_di;
import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_my_mentions_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/presentation/utils/suggestion_follow_toggle.dart';
import 'package:bimobondapp/app/chats/presentation/utils/inbox_chat_helper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_active_users_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_activity_section.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_tab_app_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_conversation_list.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_mentions_strip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_search_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_suggestions_strip.dart';
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
    _inboxBloc
      ..add(const InboxLoadRequested(refresh: true))
      ..add(const InboxSuggestionsLoadRequested());
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<UserMentionEntity> _mentions = [];
  List<UserSuggestionEntity> _suggestions = [];
  List<InboxChatItem> _cachedInboxItems = [];
  bool _inboxLoadFinished = false;
  bool _isLoadingMentions = false;
  bool _mentionsLoaded = false;
  final Set<String> _followLoadingIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.isTabActive) {
      _loadRecentMentions();
    }
  }

  @override
  void didUpdateWidget(covariant _MessagesScreenBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      _loadRecentMentions();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return authState.user.id;
    return null;
  }

  Future<void> _onRefresh() async {
    final bloc = context.read<InboxBloc>();
    final priorGeneration = switch (bloc.state) {
      InboxLoadSuccess(:final loadGeneration) => loadGeneration,
      InboxFailure(:final loadGeneration) => loadGeneration,
      _ => 0,
    };
    bloc.add(const InboxLoadRequested(refresh: true));
    bloc.add(const InboxSuggestionsLoadRequested());
    unawaited(_loadRecentMentions(refresh: true));
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

  void _onSuggestionFollowStateChanged(int index, bool isFollowing) {
    setState(() {
      _suggestions[index] = _suggestions[index].copyWith(
        isFollowing: isFollowing,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final userId = _currentUserId ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: HomeTabAppBar(title: l10n.navChat),
      body: SafeArea(
        top: false,
        child: BlocListener<InboxBloc, InboxState>(
          listenWhen: (previous, current) =>
              current is InboxLoadSuccess || current is InboxFailure,
          listener: (context, state) {
            setState(() => _inboxLoadFinished = true);
            if (state is InboxLoadSuccess) {
              setState(() {
                _cachedInboxItems = state.chats
                    .map((c) => inboxChatItemFromEntity(c, userId, l10n))
                    .toList();
                _suggestions = state.suggestions
                    .map(UserSuggestionEntity.from)
                    .toList(growable: true);
              });
            }
          },
          child: BlocBuilder<InboxBloc, InboxState>(
            builder: (context, state) {
              final inboxItems = _cachedInboxItems.isNotEmpty
                  ? _cachedInboxItems
                  : (_inboxLoadFinished
                        ? messagesMockInboxItems(l10n)
                        : <InboxChatItem>[]);
              final filtered = filterInboxChats(inboxItems, _searchQuery);
              final recentPreview = filtered
                  .take(MessagesLayoutConstants.recentMessagesPreviewCount)
                  .toList();
              final isLoadingChats =
                  (state is InboxLoading || state is InboxInitial) &&
                  !_inboxLoadFinished;
              final isLoadingSuggestions = state is InboxLoadSuccess
                  ? !state.suggestionsLoaded
                  : !_inboxLoadFinished;
              final activeBarData = inboxItems
                  .map(
                    (e) => {
                      'name': e.name,
                      'image': e.imageUrl,
                      'active': e.active,
                    },
                  )
                  .toList();

              return RefreshIndicator(
                onRefresh: _onRefresh,
                edgeOffset: MessagesLayoutConstants.refreshEdgeOffset,
                color: primaryColor,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    MessagesSearchBar(
                      controller: _searchController,
                      searchQuery: _searchQuery,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                    if (state is InboxFailure)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          state.message,
                          style: TextStyle(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (!isLoadingChats) ...[
                      if (activeBarData.isNotEmpty)
                        MessagesActiveUsersBar(chats: activeBarData),
                      MessagesActivitySection(
                        onActivityTap: (type) {
                          switch (type) {
                            case MessagesActivityType.followers:
                              context.pushNamed('my_followers');
                            case MessagesActivityType.comments:
                              context.pushNamed('user_comments');
                            case MessagesActivityType.activities:
                              context.pushNamed('user_likes');
                            case MessagesActivityType.mentions:
                              context.pushNamed('user_mentions');
                          }
                        },
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal:
                            MessagesLayoutConstants.sectionHorizontalPadding,
                        vertical: 8,
                      ),
                      child: isLoadingChats
                          ? const SkeletonWidget(height: 18, width: 160)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.messagesRecentMessages,
                                  style: TextStyle(
                                    color: theme.textTheme.bodyLarge?.color,
                                    fontSize: MessagesLayoutConstants
                                        .sectionHeaderFontSize,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => context.pushNamed('all_chats'),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      l10n.messagesSeeAll,
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: MessagesLayoutConstants
                                            .sectionLinkFontSize,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (isLoadingChats)
                      const MessagesChatListSkeleton()
                    else
                      MessagesConversationList(items: recentPreview),
                    if (!isLoadingChats) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MessagesLayoutConstants.horizontalPadding,
                        ),
                        child: Divider(
                          height: 1,
                          color: theme.dividerColor.withValues(
                            alpha: MessagesLayoutConstants.dividerAlpha,
                          ),
                        ),
                      ),
                      if (isLoadingSuggestions)
                        const MessagesSuggestionsStripSkeleton()
                      else if (_suggestions.isNotEmpty)
                        MessagesSuggestionsStrip(
                          suggestions: _suggestions,
                          loadingUserIds: _followLoadingIds,
                          onFollowToggle: _toggleSuggestionFollow,
                          onFollowStateChanged: _onSuggestionFollowStateChanged,
                          onSeeAll: () =>
                              context.pushNamed('follow_suggestions'),
                        ),
                      const SizedBox(height: 8),
                      if (_isLoadingMentions && !_mentionsLoaded)
                        const MessagesMentionsStripSkeleton()
                      else if (_mentions.isNotEmpty)
                        MessagesMentionsStrip(
                          mentions: _mentions,
                          onSeeAll: () =>
                              context.pushNamed('user_mentions'),
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
