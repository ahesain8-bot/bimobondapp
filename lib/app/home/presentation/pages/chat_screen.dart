import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_bloc.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_event.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart' as chats_di;
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.username,
    required this.imageUrl,
  });

  final String chatId;
  final String username;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId =
        authState is AuthSuccess ? authState.user.id : '';

    return BlocProvider(
      create: (_) => chats_di.sl<ChatBloc>()
        ..add(ChatStarted(chatId: chatId, currentUserId: currentUserId)),
      child: ChatView(
        chatId: chatId,
        username: username,
        imageUrl: imageUrl,
        currentUserId: currentUserId,
      ),
    );
  }
}
