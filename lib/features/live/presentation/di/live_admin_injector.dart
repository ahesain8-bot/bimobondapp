import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../live_viewer/data/services/real_socket_service.dart';
import '../../data/repositories/live_interactive_repository_impl.dart';
import '../../domain/repositories/live_interactive_repository.dart';
import '../../domain/usecases/live_interactive_usecases.dart';
import '../bloc/admin_live/admin_live_bloc.dart';
import '../../data/datasources/live_interactive_remote_datasource.dart';
import '../../../../core/network/live_api_client.dart';

AdminLiveBloc createAdminLiveBloc() {
  final api = LiveApiClient();
  api.idTokenProvider = () async => fb.FirebaseAuth.instance.currentUser?.getIdToken();
  final repository = LiveInteractiveRepositoryImpl(
    remote: LiveInteractiveRemoteDataSource(apiClient: api),
  );
  return AdminLiveBloc(
    useCases: LiveInteractiveUseCases(repository),
    socket: RealSocketService(
      idTokenProvider: () async =>
          fb.FirebaseAuth.instance.currentUser?.getIdToken(),
    ),
    staffUserId: fb.FirebaseAuth.instance.currentUser?.uid,
  );
}
