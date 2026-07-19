import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/chats/domain/usecases/create_or_get_chat_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/send_message_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart'
    as chats_di;
import 'package:bimobondapp/app/home/presentation/utils/chat_shared_post_cache.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_suggestions_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/social/presentation/services/mention_friends_source.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PostSharePeopleLoader {
  PostSharePeopleLoader._();

  static Future<List<SocialUserEntity>> load({int limit = 24}) async {
    final merged = <SocialUserEntity>[];
    final seen = <String>{};

    void addUsers(Iterable<SocialUserEntity> users) {
      for (final user in users) {
        if (seen.add(user.id)) merged.add(user);
      }
    }

    final friends = await MentionFriendsSource.ensureLoaded();
    addUsers(friends);

    final suggestionsResult = await social_di.sl<GetSuggestionsUseCase>()(
      const GetSuggestionsParams(limit: 80),
    );
    suggestionsResult.fold((_) => null, (suggestions) {
      addUsers(
        suggestions.map(
          (UserSuggestionEntity s) => SocialUserEntity(
            id: s.id,
            username: s.username,
            fullName: s.fullName,
            avatarUrl: s.avatarUrl,
            isFollowing: s.isFollowing,
          ),
        ),
      );
    });

    if (merged.length <= limit) return merged;
    return merged.take(limit).toList(growable: false);
  }

  static List<SocialUserEntity> filter(
    List<SocialUserEntity> people,
    String query, {
    int limit = 24,
  }) {
    if (query.trim().isEmpty) {
      return people.take(limit).toList(growable: false);
    }
    return MentionFriendsSource.filter(people, query, limit: limit);
  }
}

class PostShareSender {
  PostShareSender._();

  static bool ensureLoggedIn(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return true;

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

  static Future<bool> shareWithUser({
    required BuildContext context,
    required PostEntity post,
    required SocialUserEntity user,
  }) async {
    if (!ensureLoggedIn(context)) return false;

    ChatSharedPostCache.put(post);

    final chatResult = await chats_di.sl<CreateOrGetChatUseCase>()(
      CreateOrGetChatParams(participantIds: [user.id]),
    );

    if (!context.mounted) return false;
    final l10n = AppLocalizations.of(context)!;

    return chatResult.fold(
      (_) async {
        PopupDialogs.showErrorDialog(context, l10n.postShareSendFailed);
        return false;
      },
      (chat) async {
        final sendResult = await chats_di.sl<SendMessageUseCase>()(
          SendMessageParams(
            chatId: chat.id,
            content: l10n.messagesInboxLastShare,
            type: 'POST_SHARE',
            sharedPostId: post.id,
          ),
        );
        if (!context.mounted) return false;
        return sendResult.fold(
          (_) {
            PopupDialogs.showErrorDialog(context, l10n.postShareSendFailed);
            return false;
          },
          (_) => true,
        );
      },
    );
  }
}
