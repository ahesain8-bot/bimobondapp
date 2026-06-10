import 'package:bimobondapp/app/posts/data/datasources/posts_remote_data_source.dart';
import 'package:bimobondapp/app/posts/data/repositories/posts_repository_impl.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/app/posts/domain/usecases/add_comment_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/create_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/delete_comment_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_comments_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_hashtags_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_by_id_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_likes_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_views_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/record_post_view_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_replies_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_like_comment_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/delete_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_like_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_my_reposts_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_reposts_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_repost_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_save_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/update_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/upload_media_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initPosts() async {
  // Data sources
  sl.registerLazySingleton<PostsRemoteDataSource>(
    () => PostsRemoteDataSourceImpl(apiClient: sl()),
  );

  // Repository
  sl.registerLazySingleton<PostsRepository>(
    () => PostsRepositoryImpl(
      remoteDataSource: sl(),
      likesLocalDataSource: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => CreatePostUseCase(sl()));
  sl.registerLazySingleton(() => UploadMediaUseCase(sl()));
  sl.registerLazySingleton(() => GetFeedUseCase(sl()));
  sl.registerLazySingleton(() => GetHashtagsUseCase(sl()));
  sl.registerLazySingleton(() => GetPostByIdUseCase(sl()));
  sl.registerLazySingleton(() => ToggleLikePostUsecase(sl()));
  sl.registerLazySingleton(() => GetPostLikesUseCase(sl()));
  sl.registerLazySingleton(() => GetPostViewsUseCase(sl()));
  sl.registerLazySingleton(() => RecordPostViewUseCase(sl()));
  sl.registerLazySingleton(() => ToggleSavePostUsecase(sl()));
  sl.registerLazySingleton(() => ToggleRepostPostUsecase(sl()));
  sl.registerLazySingleton(() => GetPostRepostsUseCase(sl()));
  sl.registerLazySingleton(() => GetMyRepostsUseCase(sl()));
  sl.registerLazySingleton(() => UpdatePostUsecase(sl()));
  sl.registerLazySingleton(() => DeletePostUsecase(sl()));

  // Comments Use Cases
  sl.registerLazySingleton(() => GetCommentsUsecase(sl()));
  sl.registerLazySingleton(() => AddCommentUsecase(sl()));
  sl.registerLazySingleton(() => GetRepliesUsecase(sl()));
  sl.registerLazySingleton(() => DeleteCommentUsecase(sl()));
  sl.registerLazySingleton(() => ToggleLikeCommentUsecase(sl()));

  // Bloc
  sl.registerFactory(
    () => PostsBloc(
      createPostUseCase: sl(),
      uploadMediaUseCase: sl(),
      getFeedUseCase: sl(),
      toggleLikePostUsecase: sl(),
      toggleSavePostUsecase: sl(),
      toggleRepostPostUsecase: sl(),
      getMyRepostsUseCase: sl(),
      updatePostUsecase: sl(),
      deletePostUsecase: sl(),
    ),
  );

  sl.registerFactory(
    () => CommentsBloc(
      getCommentsUsecase: sl(),
      addCommentUsecase: sl(),
      getRepliesUsecase: sl(),
      deleteCommentUsecase: sl(),
      toggleLikeCommentUsecase: sl(),
    ),
  );
}
