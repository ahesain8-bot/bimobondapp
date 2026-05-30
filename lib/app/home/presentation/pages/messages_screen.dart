import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_bloc.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_event.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_state.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart'
    as chats_di;
import 'package:bimobondapp/app/social/domain/entities/follow_status.dart';
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/chats/presentation/utils/inbox_chat_helper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_active_users_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_activity_section.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_tab_app_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_conversation_list.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_mentions_strip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_search_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_seed_data.dart';
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
      ..add(const InboxFriendsLoadRequested());
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
      child: const _MessagesScreenBody(),
    );
  }
}

class _MessagesScreenBody extends StatefulWidget {
  const _MessagesScreenBody();

  @override
  State<_MessagesScreenBody> createState() => _MessagesScreenBodyState();
}

class _MessagesScreenBodyState extends State<_MessagesScreenBody> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final _mentions = messagesSeedMentions();
  final _suggestions = messagesSeedSuggestions();
  List<InboxChatItem> _cachedInboxItems = [];
  final Set<int> _followLoadingIndexes = {};

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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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

  Future<void> _toggleSuggestionFollow(int index) async {
    if (!_ensureLoggedIn() || _followLoadingIndexes.contains(index)) return;

    final userId = _suggestions[index]['userId'] as String?;
    if (userId == null || userId.isEmpty) return;

    setState(() => _followLoadingIndexes.add(index));
    final result = await social_di.sl<ToggleFollowUseCase>()(
      ToggleFollowParams(userId),
    );
    if (!mounted) return;

    setState(() => _followLoadingIndexes.remove(index));
    result.fold(
      (failure) => _showSnackBar(failure.message),
      (status) {
        setState(() {
          _suggestions[index]['isFollowing'] =
              status == FollowStatus.followed;
        });
      },
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
      appBar: HomeTabAppBar(title: l10n.navChat),
      body: SafeArea(
        top: false,
        child: BlocListener<InboxBloc, InboxState>(
          listenWhen: (previous, current) => current is InboxLoadSuccess,
          listener: (context, state) {
            if (state is! InboxLoadSuccess) return;
            setState(() {
              _cachedInboxItems = state.chats
                  .map((c) => inboxChatItemFromEntity(c, userId, l10n))
                  .toList();
            });
          },
          child: BlocBuilder<InboxBloc, InboxState>(
            builder: (context, state) {
              final inboxItems = _cachedInboxItems;
              final filtered = filterInboxChats(inboxItems, _searchQuery);
              final isLoadingChats =
                  (state is InboxLoading || state is InboxInitial) &&
                  inboxItems.isEmpty;
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
                        onActivityTap: () =>
                            _showSnackBar(l10n.settingsComingSoon),
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
                          : Text(
                              l10n.messagesRecentMessages,
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                                fontSize: MessagesLayoutConstants
                                    .sectionHeaderFontSize,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                    ),
                    if (isLoadingChats)
                      const MessagesChatListSkeleton()
                    else
                      MessagesConversationList(items: filtered),
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
                      MessagesSuggestionsStrip(
                        suggestions: _suggestions,
                        loadingIndexes: _followLoadingIndexes,
                        onFollowToggle: _toggleSuggestionFollow,
                      ),
                      const SizedBox(height: 8),
                      MessagesMentionsStrip(mentions: _mentions),
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
