import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/http_live_remote_datasource.dart';
import '../data/datasources/live_remote_datasource.dart';
import '../data/repositories/fake_live_repository.dart';
import '../data/repositories/real_comment_repository.dart';
import '../data/repositories/real_gift_repository.dart';
import '../data/repositories/real_like_repository.dart';
import '../data/services/fake_livekit_service.dart';
import '../data/services/fake_socket_service.dart';
import '../data/services/real_livekit_service.dart';
import '../data/services/real_socket_service.dart';
import '../presentation/providers/live_dependencies.dart';

/// Bootstrap hook for app start. Currently a no-op because Riverpod
/// providers auto-wire the real backend services.
Future<void> initializeDependencies() async {
  // e.g. await Firebase.initializeApp();
}

/// Example override list for tests / staging with alternate implementations.
List<Override> mockLiveOverrides({
  LiveRemoteDataSource? remote,
  SocketService? socket,
  LiveKitService? liveKit,
}) {
  return [
    if (remote != null) liveRemoteDataSourceProvider.overrideWithValue(remote),
    if (socket != null) socketServiceProvider.overrideWithValue(socket),
    if (liveKit != null) liveKitServiceProvider.overrideWithValue(liveKit),
  ];
}

/// Production wiring — real REST + Socket.IO + LiveKit services.
typedef LiveRepositoryImpl = FakeLiveRepository;
typedef CommentRepositoryImpl = RealCommentRepository;
typedef LikeRepositoryImpl = RealLikeRepository;
typedef GiftRepositoryImpl = RealGiftRepository;
typedef LiveRemoteDataSourceImpl = HttpLiveRemoteDataSource;
typedef SocketServiceImpl = RealSocketService;
typedef LiveKitServiceImpl = RealLiveKitService;
