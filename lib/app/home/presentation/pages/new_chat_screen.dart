import 'package:bimobondapp/app/chats/domain/entities/chat_participant_entity.dart';
import 'package:bimobondapp/app/chats/domain/usecases/create_or_get_chat_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/get_friends_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart'
    as chats_di;
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_rounded_search_field.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/new_chat_friend_tile.dart';
import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// TikTok-style "New chat" picker — search + friends list.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ChatParticipantEntity> _friends = [];
  List<ChatParticipantEntity> _filtered = [];
  bool _loading = true;
  bool _openingChat = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await chats_di.sl<GetFriendsUseCase>()(
      const SocialListQuery(page: 1, limit: 100),
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
        _friends = [];
        _filtered = [];
      }),
      (friends) {
        friends.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
        setState(() {
          _loading = false;
          _friends = friends;
          _filtered = friends;
        });
      },
    );
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _friends;
      } else {
        _filtered = _friends
            .where(
              (f) =>
                  f.displayName.toLowerCase().contains(q) ||
                  (f.username?.toLowerCase().contains(q) ?? false),
            )
            .toList();
      }
    });
  }

  Future<void> _openChat(ChatParticipantEntity friend) async {
    if (_openingChat) return;
    setState(() => _openingChat = true);

    final result = await chats_di.sl<CreateOrGetChatUseCase>()(
      CreateOrGetChatParams(participantIds: [friend.id]),
    );

    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() => _openingChat = false);
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (chat) async {
        setState(() => _openingChat = false);
        context.pop();
        await context.pushNamed(
          'chat',
          extra: {
            'chatId': chat.id,
            'username': friend.displayName,
            if (friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty)
              'imageUrl': friend.avatarUrl,
            'peerUserId': friend.id,
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 72,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: Text(
            l10n.closeAction,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          l10n.messagesNewChatTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MessagesRoundedSearchField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MessagesLayoutConstants.horizontalPadding,
                  4,
                  MessagesLayoutConstants.horizontalPadding,
                  8,
                ),
                child: Text(
                  l10n.friendsLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              Expanded(child: _buildBody(l10n, chatTheme)),
            ],
          ),
          if (_openingChat)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CustomLoadingWidget(size: 56)),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ChatTheme chatTheme) {
    if (_loading) {
      return const Center(child: CustomLoadingWidget(size: 56));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadFriends, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Text(
          l10n.connectionsEmptyFriends,
          style: TextStyle(color: chatTheme.inboxSecondaryText),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final friend = _filtered[index];
        return NewChatFriendTile(
          friend: friend,
          onTap: () => _openChat(friend),
        );
      },
    );
  }
}
