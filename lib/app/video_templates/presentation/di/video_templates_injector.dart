import 'package:bimobondapp/app/video_templates/composition/template_composition_engine.dart';
import 'package:bimobondapp/app/video_templates/data/datasources/video_template_asset_loader.dart';
import 'package:bimobondapp/app/video_templates/data/datasources/video_templates_local_cache.dart';
import 'package:bimobondapp/app/video_templates/data/datasources/video_templates_remote_data_source.dart';
import 'package:bimobondapp/app/video_templates/data/repositories/video_templates_repository_impl.dart';
import 'package:bimobondapp/app/video_templates/domain/repositories/video_templates_repository.dart';
import 'package:bimobondapp/app/video_templates/domain/usecases/template_engine_usecases.dart';
import 'package:bimobondapp/app/video_templates/domain/usecases/video_templates_usecases.dart';
import 'package:bimobondapp/app/video_templates/engine/template_engine.dart';
import 'package:bimobondapp/app/video_templates/project/local_project_store.dart';
import 'package:bimobondapp/app/video_templates/project/project_media_manager.dart';
import 'package:bimobondapp/app/video_templates/project/template_project_controller.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initVideoTemplates() async {
  sl.registerLazySingleton<ProjectMediaManager>(() => ProjectMediaManager());
  sl.registerLazySingleton<LocalProjectStore>(
    () => LocalProjectStore(mediaManager: sl()),
  );
  // Session-scoped — create a new controller per editor open.
  sl.registerFactory<TemplateProjectController>(
    () => TemplateProjectController(
      store: sl(),
      mediaManager: sl(),
    ),
  );

  sl.registerLazySingleton<VideoTemplatesLocalCache>(
    () => VideoTemplatesLocalCache(),
  );
  sl.registerLazySingleton<VideoTemplateAssetLoader>(
    () => VideoTemplateAssetLoader(),
  );
  sl.registerLazySingleton<VideoTemplatesRemoteDataSource>(
    () => VideoTemplatesRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<VideoTemplatesRepository>(
    () => VideoTemplatesRepositoryImpl(
      remoteDataSource: sl(),
      localCache: sl(),
      assetLoader: sl(),
    ),
  );
  sl.registerLazySingleton<TemplateEngine>(() => TemplateEngine());
  sl.registerLazySingleton<TemplateCompositionEngine>(
    () => TemplateCompositionEngine(templateEngine: sl()),
  );

  sl.registerLazySingleton(() => ListPhotoVideoTemplatesUseCase(sl()));
  sl.registerLazySingleton(() => ListVideoTemplatesUseCase(sl()));
  sl.registerLazySingleton(() => ListFeaturedVideoTemplatesUseCase(sl()));
  sl.registerLazySingleton(() => ListTrendingVideoTemplatesUseCase(sl()));
  sl.registerLazySingleton(() => SearchVideoTemplatesUseCase(sl()));
  sl.registerLazySingleton(() => ListVideoTemplatesBySoundUseCase(sl()));
  sl.registerLazySingleton(() => ListVideoTemplateCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetVideoTemplateUseCase(sl()));
  sl.registerLazySingleton(() => GetVideoTemplateRecipeUseCase(sl()));
  sl.registerLazySingleton(() => PrepareVideoTemplateEditorUseCase(sl()));
  sl.registerLazySingleton(() => RecordVideoTemplateUseUseCase(sl()));
  sl.registerLazySingleton(() => CreateVideoTemplateProjectUseCase(sl()));
  sl.registerLazySingleton(() => CreateProjectFromMediaUseCase(sl()));
  sl.registerLazySingleton(() => CompleteVideoTemplateProjectUseCase(sl()));
  sl.registerLazySingleton(
    () => ExportTemplateCompositionUseCase(
      engine: sl(),
      repository: sl(),
    ),
  );
  sl.registerLazySingleton(() => QueueAndWatchTemplateExportUseCase(sl()));
  sl.registerLazySingleton(
    () => ApplyVideoTemplateUseCase(
      repository: sl(),
      uploadMedia: sl(),
      engine: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => OneShotRenderVideoTemplateUseCase(
      repository: sl(),
      uploadMedia: sl(),
    ),
  );
}
