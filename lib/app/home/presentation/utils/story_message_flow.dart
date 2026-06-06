import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_entity.dart';
import 'package:bimobondapp/app/home/presentation/utils/chat_shared_post_cache.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/chats/domain/usecases/create_or_get_chat_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/send_message_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart' as chats_di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<ChatEntity?> resolveStoryOwnerChat(
  BuildContext context, {
  required String storyOwnerId,
}) async {
  final auth = context.read<AuthBloc>().state;
  if (auth is! AuthSuccess) return null;
  if (storyOwnerId == auth.user.id) return null;

  final result = await chats_di.sl<CreateOrGetChatUseCase>()(
    CreateOrGetChatParams(participantIds: [storyOwnerId]),
  );

  return result.fold((_) => null, (chat) => chat);
}

Future<bool> sendStoryReplyMessage({
  required PostEntity story,
  required String chatId,
  required String text,
}) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;

  ChatSharedPostCache.put(story);

  final result = await chats_di.sl<SendMessageUseCase>()(
    SendMessageParams(
      chatId: chatId,
      content: trimmed,
      sharedPostId: story.id,
    ),
  );

  return result.isRight();
}
