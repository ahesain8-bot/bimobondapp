import 'package:bimobondapp/app/chats/data/datasources/chat_socket_service.dart';
import 'package:bimobondapp/app/chats/data/datasources/chats_remote_data_source.dart';
import 'package:bimobondapp/app/chats/data/repositories/chats_repository_impl.dart';
import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/app/chats/domain/usecases/create_or_get_chat_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/get_chat_messages_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/get_chats_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/delete_message_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/delete_chat_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/mark_message_read_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/react_to_message_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/send_message_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_bloc.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_bloc.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initChats() async {
  sl.registerLazySingleton<ChatSocketService>(() => ChatSocketService());

  sl.registerLazySingleton<ChatsRemoteDataSource>(
    () => ChatsRemoteDataSourceImpl(apiClient: sl()),
  );

  sl.registerLazySingleton<ChatsRepository>(
    () => ChatsRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetChatsUseCase(sl()));
  sl.registerLazySingleton(() => CreateOrGetChatUseCase(sl()));
  sl.registerLazySingleton(() => GetChatMessagesUseCase(sl()));
  sl.registerLazySingleton(() => SendMessageUseCase(sl()));
  sl.registerLazySingleton(() => MarkMessageReadUseCase(sl()));
  sl.registerLazySingleton(() => ReactToMessageUseCase(sl()));
  sl.registerLazySingleton(() => DeleteMessageUseCase(sl()));
  sl.registerLazySingleton(() => DeleteChatUseCase(sl()));

  sl.registerFactory(
    () => InboxBloc(
      getChatsUseCase: sl(),
      getSuggestionsUseCase: sl(),
      deleteChatUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => ChatBloc(
      getChatMessagesUseCase: sl(),
      sendMessageUseCase: sl(),
      uploadMediaUseCase: sl(),
      reactToMessageUseCase: sl(),
      markMessageReadUseCase: sl(),
      deleteMessageUseCase: sl(),
      socketService: sl(),
    ),
  );
}
