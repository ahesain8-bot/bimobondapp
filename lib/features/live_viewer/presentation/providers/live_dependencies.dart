import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../domain/usecases/get_live_feed_usecase.dart';
import '../../domain/usecases/join_live_usecase.dart';
import '../../domain/usecases/leave_live_usecase.dart';
import '../../domain/usecases/like_live_usecase.dart';
import '../../domain/usecases/send_gift_usecase.dart';

/// Central DI for the live viewer feature.
///
/// Defaults to **real** backend implementations (REST + Socket.IO + LiveKit).
/// Override any provider below with fakes for tests / staging.

/// Shared [LiveApiClient] wired to the Firebase ID token — same contract as the
/// root app's ApiClient but self-contained for this feature.
final apiClientProvider = Provider<LiveApiClient>((ref) {
  final client = LiveApiClient();
  client.idTokenProvider = _firebaseIdToken;
  return client;
});

Future<String?> _firebaseIdToken() async {
  try {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  } catch (_) {
    return null;
  }
}

final liveRemoteDataSourceProvider = Provider<LiveRemoteDataSource>((ref) {
  return HttpLiveRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});

/// Shared socket proxy that [ActiveLiveNotifier] points at the current
/// active (or preloaded) delegate. Repositories and widgets stay subscribed
/// to this single provider while the backing socket changes per live.
final socketServiceProvider = Provider<SocketService>((ref) {
  final proxy = SocketServiceProxy();
  ref.onDispose(proxy.dispose);
  return proxy;
});

/// Shared LiveKit proxy that [ActiveLiveNotifier] points at the current
/// active (or preloaded) delegate. [LiveVideoPlayer] subscribes to this
/// provider once and follows whichever room is currently active.
final liveKitServiceProvider = Provider<LiveKitService>((ref) {
  final proxy = LiveKitServiceProxy();
  ref.onDispose(proxy.dispose);
  return proxy;
});

/// Factory for creating a fresh [SocketService] per live (active or preload).
final socketServiceFactoryProvider = Provider<SocketService Function()>(
  (ref) => () => RealSocketService(idTokenProvider: _firebaseIdToken),
);

/// Factory for creating a fresh [LiveKitService] per live (active or preload).
final liveKitServiceFactoryProvider = Provider<LiveKitService Function()>(
  (ref) => () => RealLiveKitService(),
);

final liveRepositoryProvider = Provider<LiveRepository>((ref) {
  return FakeLiveRepository(ref.watch(liveRemoteDataSourceProvider));
});

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return RealCommentRepository(
    apiClient: ref.watch(apiClientProvider),
    socket: ref.watch(socketServiceProvider),
  );
});

final likeRepositoryProvider = Provider<LikeRepository>((ref) {
  return RealLikeRepository(
    apiClient: ref.watch(apiClientProvider),
    socket: ref.watch(socketServiceProvider),
  );
});

final giftRepositoryProvider = Provider<GiftRepository>((ref) {
  return RealGiftRepository(
    apiClient: ref.watch(apiClientProvider),
    socket: ref.watch(socketServiceProvider),
  );
});

final getLiveFeedUseCaseProvider = Provider<GetLiveFeedUseCase>((ref) {
  return GetLiveFeedUseCase(ref.watch(liveRepositoryProvider));
});

final joinLiveUseCaseProvider = Provider<JoinLiveUseCase>((ref) {
  return JoinLiveUseCase(ref.watch(liveRepositoryProvider));
});

final leaveLiveUseCaseProvider = Provider<LeaveLiveUseCase>((ref) {
  return LeaveLiveUseCase(ref.watch(liveRepositoryProvider));
});

final likeLiveUseCaseProvider = Provider<LikeLiveUseCase>((ref) {
  return LikeLiveUseCase(ref.watch(likeRepositoryProvider));
});

final sendGiftUseCaseProvider = Provider<SendGiftUseCase>((ref) {
  return SendGiftUseCase(ref.watch(giftRepositoryProvider));
});
