import 'package:bimobondapp/app/calls/data/datasources/call_socket_service.dart';
import 'package:bimobondapp/app/calls/data/datasources/calls_remote_data_source.dart';
import 'package:bimobondapp/app/calls/data/repositories/calls_repository_impl.dart';
import 'package:bimobondapp/app/calls/domain/repositories/calls_repository.dart';
import 'package:bimobondapp/app/calls/domain/usecases/accept_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/end_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/get_active_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/get_call_history_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/get_call_by_id_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/invite_to_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/leave_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/reject_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/start_call_usecase.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/services/call_ringtone_service.dart';
import 'package:bimobondapp/app/calls/services/callkit_service.dart';
import 'package:bimobondapp/app/calls/services/livekit_call_service.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initCalls() async {
  sl.registerLazySingleton<CallSocketService>(() => CallSocketService());
  sl.registerLazySingleton<LiveKitCallService>(() => LiveKitCallService());
  sl.registerLazySingleton<CallRingtoneService>(() => CallRingtoneService());
  sl.registerLazySingleton<CallkitService>(() => CallkitService.instance);

  sl.registerLazySingleton<CallsRemoteDataSource>(
    () => CallsRemoteDataSourceImpl(apiClient: sl()),
  );

  sl.registerLazySingleton<CallsRepository>(
    () => CallsRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => StartCallUseCase(sl()));
  sl.registerLazySingleton(() => GetActiveCallUseCase(sl()));
  sl.registerLazySingleton(() => GetCallByIdUseCase(sl()));
  sl.registerLazySingleton(() => AcceptCallUseCase(sl()));
  sl.registerLazySingleton(() => RejectCallUseCase(sl()));
  sl.registerLazySingleton(() => EndCallUseCase(sl()));
  sl.registerLazySingleton(() => LeaveCallUseCase(sl()));
  sl.registerLazySingleton(() => InviteToCallUseCase(sl()));
  sl.registerLazySingleton(() => GetCallHistoryUseCase(sl()));

  sl.registerLazySingleton<CallBloc>(
    () => CallBloc(
      startCallUseCase: sl(),
      getActiveCallUseCase: sl(),
      getCallByIdUseCase: sl(),
      acceptCallUseCase: sl(),
      rejectCallUseCase: sl(),
      endCallUseCase: sl(),
      leaveCallUseCase: sl(),
      inviteToCallUseCase: sl(),
      socketService: sl(),
      livekitService: sl(),
      ringtoneService: sl(),
    ),
  );
}
