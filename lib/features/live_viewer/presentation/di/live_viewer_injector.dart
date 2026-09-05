import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:get_it/get_it.dart';
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import '../../../../core/network/live_api_client.dart';
import '../../data/datasources/http_live_remote_datasource.dart';
import '../../data/datasources/http_ranking_remote_datasource.dart';
import '../../data/datasources/live_remote_datasource.dart';
import '../../data/datasources/ranking_remote_datasource.dart';
import '../../data/repositories/real_live_repository.dart';
import '../../data/repositories/real_comment_repository.dart';
import '../../data/repositories/real_gift_repository.dart';
import '../../data/repositories/real_guest_repository.dart';
import '../../data/repositories/real_like_repository.dart';
import '../../data/repositories/real_ranking_repository.dart';
import '../../../live/data/datasources/live_interactive_remote_datasource.dart';
import '../../../live/data/repositories/live_interactive_repository_impl.dart';
import '../../data/services/fake_livekit_service.dart';
import '../../data/services/fake_socket_service.dart';
import '../../data/services/real_livekit_service.dart';
import '../../data/services/real_socket_service.dart';
import '../../domain/repositories/comment_repository.dart';
import '../../domain/repositories/gift_repository.dart';
import '../../domain/repositories/guest_repository.dart';
import '../../domain/repositories/like_repository.dart';
import '../../domain/repositories/live_repository.dart';
import '../../domain/repositories/ranking_repository.dart';
import '../../../live/domain/repositories/live_interactive_repository.dart';
import '../../../live/domain/usecases/live_interactive_usecases.dart';
import '../../domain/usecases/ban_viewer_usecase.dart';
import '../../domain/usecases/delete_comment_usecase.dart';
import '../../domain/usecases/pin_comment_usecase.dart';
import '../../domain/usecases/get_hourly_leaderboard_usecase.dart';
import '../../domain/usecases/get_live_feed_usecase.dart';
import '../../domain/usecases/get_live_by_id_usecase.dart';
import '../../domain/usecases/get_live_hourly_rank_usecase.dart';
import '../../domain/usecases/join_live_usecase.dart';
import '../../domain/usecases/leave_live_usecase.dart';
import '../../domain/usecases/like_live_usecase.dart';
import '../../domain/usecases/mute_viewer_chat_usecase.dart';
import '../../domain/usecases/unban_viewer_usecase.dart';
import '../../domain/usecases/unmute_viewer_chat_usecase.dart';
import '../../domain/usecases/watch_live_hourly_rank_usecase.dart';
import '../bloc/hourly_ranking/hourly_ranking_bloc.dart';
import '../bloc/live_feed/live_feed_bloc.dart';
import '../bloc/live_detail/live_detail_bloc.dart';
import '../bloc/live_viewer/live_viewer_bloc.dart';
import '../../../live/presentation/bloc/live_interactive/live_interactive_bloc.dart';

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

  sl.registerLazySingleton<RankingRemoteDataSource>(
    () => HttpRankingRemoteDataSource(apiClient: sl()),
  );

  sl.registerLazySingleton<SocketService>(
    () => RealSocketService(idTokenProvider: _firebaseIdToken),
  );

  sl.registerLazySingleton<LiveKitService>(() => RealLiveKitService());

  sl.registerLazySingleton<LiveRepository>(() => RealLiveRepository(sl()));

  sl.registerLazySingleton<LiveInteractiveRemoteDataSource>(
    () => LiveInteractiveRemoteDataSource(apiClient: sl()),
  );
  sl.registerLazySingleton<LiveInteractiveRepository>(
    () => LiveInteractiveRepositoryImpl(remote: sl()),
  );
  sl.registerLazySingleton(() => LiveInteractiveUseCases(sl<LiveInteractiveRepository>()));

  sl.registerLazySingleton<GuestRepository>(
    () => RealGuestRepository(apiClient: sl()),
  );

  sl.registerLazySingleton<CommentRepository>(
    () => RealCommentRepository(apiClient: sl(), socket: sl()),
  );

  sl.registerLazySingleton<LikeRepository>(
    () => RealLikeRepository(apiClient: sl(), socket: sl()),
  );

  sl.registerLazySingleton<GiftRepository>(
    () => RealGiftRepository(
      apiClient: sl(),
      socket: sl(),
      catalogRepository: sl<GiftsRepository>(),
    ),
  );

  sl.registerLazySingleton<RankingRepository>(
    () => RealRankingRepository(remote: sl(), socket: sl()),
  );

  sl.registerLazySingleton(() => GetLiveFeedUseCase(sl()));
  sl.registerLazySingleton(() => GetLiveByIdUseCase(sl()));
  sl.registerLazySingleton(() => JoinLiveUseCase(sl()));
  sl.registerLazySingleton(() => LeaveLiveUseCase(sl()));
  sl.registerLazySingleton(() => LikeLiveUseCase(sl()));
  sl.registerLazySingleton(() => BanViewerUseCase(sl()));
  sl.registerLazySingleton(() => UnbanViewerUseCase(sl()));
  sl.registerLazySingleton(() => MuteViewerChatUseCase(sl()));
  sl.registerLazySingleton(() => UnmuteViewerChatUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCommentUseCase(sl()));
  sl.registerLazySingleton(() => PinCommentUseCase(sl()));
  sl.registerLazySingleton(() => GetHourlyLeaderboardUseCase(sl()));
  sl.registerLazySingleton(() => GetLiveHourlyRankUseCase(sl()));
  sl.registerLazySingleton(() => WatchLiveHourlyRankUseCase(sl()));

  sl.registerFactory(() => LiveFeedBloc(getLiveFeedUseCase: sl()));
  sl.registerFactory(() => LiveDetailBloc(getLiveById: sl()));
  sl.registerFactory(
    () => LiveInteractiveBloc(
      useCases: sl<LiveInteractiveUseCases>(),
      socketEvents: sl<SocketService>().events,
    ),
  );

  sl.registerFactory(
    () => HourlyRankingBloc(
      getHourlyLeaderboardUseCase: sl(),
      getLiveHourlyRankUseCase: sl(),
      watchLiveHourlyRankUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => LiveViewerBloc(
      joinLiveUseCase: sl(),
      leaveLiveUseCase: sl(),
      likeLiveUseCase: sl(),
      giftSocketService: sl<AuctionSocketService>(),
      banViewerUseCase: sl(),
      unbanViewerUseCase: sl(),
      muteViewerChatUseCase: sl(),
      unmuteViewerChatUseCase: sl(),
      deleteCommentUseCase: sl(),
      pinCommentUseCase: sl(),
      liveRepository: sl(),
      commentRepository: sl(),
      giftRepository: sl(),
      likeRepository: sl(),
      socketService: sl(),
      liveKitService: sl(),
      guestRepository: sl(),
      apiClient: sl(),
    ),
  );
}
