import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_bloc.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_event.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_state.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart'
    as chats_di;
import 'package:bimobondapp/app/chats/presentation/utils/inbox_chat_helper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_conversation_list.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_search_bar.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AllChatsScreen extends StatefulWidget {
  const AllChatsScreen({super.key, this.autofocusSearch = false});

  /// When true, opens as a search-focused screen with the keyboard ready.
  final bool autofocusSearch;

  @override
  State<AllChatsScreen> createState() => _AllChatsScreenState();
}

class _AllChatsScreenState extends State<AllChatsScreen> {
  late final InboxBloc _inboxBloc;

  @override
  void initState() {
    super.initState();
    _inboxBloc = chats_di.sl<InboxBloc>()
      ..add(const InboxLoadRequested(refresh: true));
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
      child: _AllChatsBody(autofocusSearch: widget.autofocusSearch),
    );
  }
}

class _AllChatsBody extends StatefulWidget {
  const _AllChatsBody({required this.autofocusSearch});

  final bool autofocusSearch;

  @override
  State<_AllChatsBody> createState() => _AllChatsBodyState();
}

class _AllChatsBodyState extends State<_AllChatsBody> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<InboxChatItem> _cachedInboxItems = [];
  bool _inboxLoadFinished = false;

  @override
  void initState() {
    super.initState();
    if (widget.autofocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final userId = _currentUserId ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: widget.autofocusSearch
            ? l10n.messagesSearchHint
            : l10n.messagesAllChats,
      ),
      body: BlocListener<InboxBloc, InboxState>(
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
        child: BlocBuilder<InboxBloc, InboxState>(
          builder: (context, state) {
            final inboxItems = _cachedInboxItems;
            final filtered = filterInboxChats(inboxItems, _searchQuery);
            final isLoadingChats =
                (state is InboxLoading || state is InboxInitial) &&
                !_inboxLoadFinished;

            return Column(
              children: [
                MessagesSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: widget.autofocusSearch,
                  searchQuery: _searchQuery,
                  onChanged: (value) => setState(() => _searchQuery = value),
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
                Expanded(
                  child: isLoadingChats
                      ? const MessagesChatListSkeleton()
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: theme.colorScheme.primary,
                          child: filtered.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  children: [
                                    SizedBox(
                                      height:
                                          MessagesLayoutConstants
                                              .emptyStateHeight,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _searchQuery.isEmpty
                                                ? Icons.chat_bubble_outline_rounded
                                                : Icons.search_off_rounded,
                                            size: 48,
                                            color: theme.dividerColor
                                                .withValues(alpha: 0.2),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _searchQuery.isEmpty
                                                ? l10n.messagesInboxNoMessagesYet
                                                : l10n.messagesNoResults,
                                            style: TextStyle(
                                              color: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color
                                                  ?.withValues(alpha: 0.4),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : MessagesConversationList(
                                  items: filtered,
                                  scrollable: true,
                                ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
