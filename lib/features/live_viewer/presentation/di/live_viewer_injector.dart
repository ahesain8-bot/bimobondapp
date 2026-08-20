import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:get_it/get_it.dart';
import '../../../../core/network/live_api_client.dart';
import '../../data/datasources/http_live_remote_datasource.dart';
import '../../data/datasources/live_remote_datasource.dart';
import '../../data/repositories/fake_live_repository.dart';
import '../../data/repositories/real_comment_repository.dart';
import '../../data/repositories/real_gift_repository.dart';
import '../../data/repositories/real_like_repository.dart';
import '../../data/services/fake_livekit_service.dart';
import '../../data/services/fake_socket_service.dart';
import '../../data/services/real_livekit_service.dart';
import '../../data/services/real_socket_service.dart';
import '../../domain/repositories/comment_repository.dart';
import '../../domain/repositories/gift_repository.dart';
import '../../domain/repositories/like_repository.dart';
import '../../domain/repositories/live_repository.dart';
import '../../domain/usecases/ban_viewer_usecase.dart';
import '../../domain/usecases/delete_comment_usecase.dart';
import '../../domain/usecases/get_live_feed_usecase.dart';
import '../../domain/usecases/join_live_usecase.dart';
import '../../domain/usecases/leave_live_usecase.dart';
import '../../domain/usecases/like_live_usecase.dart';
import '../../domain/usecases/mute_viewer_chat_usecase.dart';
import '../../domain/usecases/send_gift_usecase.dart';
import '../../domain/usecases/unban_viewer_usecase.dart';
import '../../domain/usecases/unmute_viewer_chat_usecase.dart';
import '../bloc/live_feed/live_feed_bloc.dart';
import '../bloc/live_viewer/live_viewer_bloc.dart';

final sl = GetIt.instance;

Future<String?> _firebaseIdToken() async {
  final user = fb.FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  try {
    return await user.getIdToken();
  } catch (_) {
    return null;
  }
}

Future<void> initLiveViewer() async {
  sl.registerLazySingleton<LiveApiClient>(() {
    final client = LiveApiClient();
    client.idTokenProvider = _firebaseIdToken;
    return client;
  });

  sl.registerLazySingleton<LiveRemoteDataSource>(
    () => HttpLiveRemoteDataSource(apiClient: sl()),
  );

  sl.registerLazySingleton<SocketService>(
    () => RealSocketService(idTokenProvider: _firebaseIdToken),
  );

  sl.registerLazySingleton<LiveKitService>(() => RealLiveKitService());

  sl.registerLazySingleton<LiveRepository>(() => FakeLiveRepository(sl()));

  sl.registerLazySingleton<CommentRepository>(
    () => RealCommentRepository(apiClient: sl(), socket: sl()),
  );

  sl.registerLazySingleton<LikeRepository>(
    () => RealLikeRepository(apiClient: sl(), socket: sl()),
  );

  sl.registerLazySingleton<GiftRepository>(
    () => RealGiftRepository(apiClient: sl(), socket: sl()),
  );

  sl.registerLazySingleton(() => GetLiveFeedUseCase(sl()));
  sl.registerLazySingleton(() => JoinLiveUseCase(sl()));
  sl.registerLazySingleton(() => LeaveLiveUseCase(sl()));
  sl.registerLazySingleton(() => LikeLiveUseCase(sl()));
  sl.registerLazySingleton(() => SendGiftUseCase(sl()));
  sl.registerLazySingleton(() => BanViewerUseCase(sl()));
  sl.registerLazySingleton(() => UnbanViewerUseCase(sl()));
  sl.registerLazySingleton(() => MuteViewerChatUseCase(sl()));
  sl.registerLazySingleton(() => UnmuteViewerChatUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCommentUseCase(sl()));

  sl.registerFactory(() => LiveFeedBloc(getLiveFeedUseCase: sl()));

  sl.registerFactory(
    () => LiveViewerBloc(
      joinLiveUseCase: sl(),
      leaveLiveUseCase: sl(),
      likeLiveUseCase: sl(),
      sendGiftUseCase: sl(),
      banViewerUseCase: sl(),
      unbanViewerUseCase: sl(),
      muteViewerChatUseCase: sl(),
      unmuteViewerChatUseCase: sl(),
      deleteCommentUseCase: sl(),
      liveRepository: sl(),
      commentRepository: sl(),
      giftRepository: sl(),
      likeRepository: sl(),
      socketService: sl(),
      liveKitService: sl(),
      apiClient: sl(),
    ),
  );
}
