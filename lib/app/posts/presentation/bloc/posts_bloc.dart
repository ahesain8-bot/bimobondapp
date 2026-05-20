import 'package:bimobondapp/app/posts/domain/entities/post_auction_input.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/create_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:bimobondapp/app/posts/domain/entities/toggle_like_params.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_like_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/entities/update_post_params.dart';
import 'package:bimobondapp/app/posts/domain/usecases/delete_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_save_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/update_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/upload_media_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PostsBloc extends Bloc<PostsEvent, PostsState> {
  final CreatePostUseCase createPostUseCase;
  final UploadMediaUseCase uploadMediaUseCase;
  final GetFeedUseCase getFeedUseCase;
  final ToggleLikePostUsecase toggleLikePostUsecase;
  final ToggleSavePostUsecase toggleSavePostUsecase;
  final UpdatePostUsecase updatePostUsecase;
  final DeletePostUsecase deletePostUsecase;

  PostsBloc({
    required this.createPostUseCase,
    required this.uploadMediaUseCase,
    required this.getFeedUseCase,
    required this.toggleLikePostUsecase,
    required this.toggleSavePostUsecase,
    required this.updatePostUsecase,
    required this.deletePostUsecase,
  }) : super(PostsInitial()) {
    on<UploadMediaRequestedEvent>(_onUploadMediaRequested);
    on<CreatePostRequestedEvent>(_onCreatePostRequested);
    on<CreatePostWithMediaRequestedEvent>(_onCreatePostWithMediaRequested);
    on<FetchFeedRequestedEvent>(_onFetchFeedRequested);
    on<ToggleLikePostRequestedEvent>(_onToggleLikePostRequested);
    on<ToggleSavePostRequestedEvent>(_onToggleSavePostRequested);
    on<UpdatePostRequestedEvent>(_onUpdatePostRequested);
    on<DeletePostRequestedEvent>(_onDeletePostRequested);
  }

  Future<void> _onUpdatePostRequested(
    UpdatePostRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final result = await updatePostUsecase(
      UpdatePostParams(
        postId: event.postId,
        description: event.description,
        category: event.category,
        privacyStatus: event.privacyStatus,
      ),
    );
    result.fold(
      (failure) => emit(PostsFailure(failure.message)),
      (post) => emit(UpdatePostSuccess(post)),
    );
  }

  Future<void> _onDeletePostRequested(
    DeletePostRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final result = await deletePostUsecase(event.postId);
    result.fold(
      (failure) => emit(PostsFailure(failure.message)),
      (_) => emit(DeletePostSuccess(event.postId)),
    );
  }

  Future<void> _onToggleSavePostRequested(
    ToggleSavePostRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final result = await toggleSavePostUsecase(event.postId);
    result.fold(
      (failure) => emit(PostsFailure(failure.message)),
      (_) => emit(SavePostSuccess(event.postId)),
    );
  }

  Future<void> _onToggleLikePostRequested(
    ToggleLikePostRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final result = await toggleLikePostUsecase(
      ToggleLikeParams(id: event.postId, liked: event.liked),
    );
    result.fold(
      (failure) => emit(PostsFailure(failure.message)),
      (_) => emit(LikePostSuccess(event.postId)),
    );
  }

  Future<void> _onCreatePostWithMediaRequested(
    CreatePostWithMediaRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    emit(PostsLoading());

    try {
      final List<PostMediaEntity> mediaEntities = [];
      String? videoUrl;
      String? thumbnailUrl;

      for (int i = 0; i < event.files.length; i++) {
        final result = await uploadMediaUseCase(event.files[i]);
        final url = result.fold(
          (failure) => throw Exception(failure.message),
          (url) => url,
        );

        if (event.type == 'VIDEO') {
          videoUrl = url;
          // In a real app, you'd generate a thumbnail too
          thumbnailUrl = url;
          mediaEntities.add(
            PostMediaEntity(url: url, mediaType: 'VIDEO', order: i),
          );
        } else {
          mediaEntities.add(
            PostMediaEntity(url: url, mediaType: 'IMAGE', order: i),
          );
        }
      }

      PostAuctionInput? auction = event.auction;
      if (event.isAuctionable && auction != null) {
        final coverUrl =
            thumbnailUrl ??
            (mediaEntities.isNotEmpty ? mediaEntities.first.url : null);
        auction = auction.copyWith(itemImageUrl: coverUrl);
      }

      final result = await createPostUseCase(
        CreatePostParams(
          type: event.type,
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          description: event.description,
          category: event.category,
          status: event.status,
          privacyStatus: event.privacyStatus,
          allowComments: event.allowComments,
          allowDuets: event.allowDuets,
          allowStitch: event.allowStitch,
          isAuctionable: event.isAuctionable,
          auction: event.isAuctionable ? auction : null,
          media: mediaEntities,
        ),
      );

      result.fold(
        (failure) => emit(PostsFailure(failure.message)),
        (post) => emit(CreatePostSuccess(post)),
      );
    } catch (e) {
      emit(PostsFailure(e.toString()));
    }
  }

  Future<void> _onFetchFeedRequested(
    FetchFeedRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    if (event.page == 1) {
      emit(PostsLoading());
    }

    final result = await getFeedUseCase(
      GetFeedParams(
        page: event.page,
        limit: event.limit,
        category: event.category,
        type: event.type,
        hashtag: event.hashtag,
        search: event.search,
        sort: event.sort,
        userId: event.userId,
        isLiked: event.isLiked,
        isSaved: event.isSaved,
      ),
    );

    result.fold(
      (failure) => emit(
        PostsFailure(failure.message, profileLoadKey: event.profileLoadKey),
      ),
      (posts) {
        final hasReachedMax = posts.length < event.limit;
        if (event.userId != null) {
          emit(
            ProfilePostsLoadSuccess(
              posts: posts,
              hasReachedMax: hasReachedMax,
              profileLoadKey: event.profileLoadKey ?? 0,
            ),
          );
        } else {
          emit(FeedLoadSuccess(posts: posts, hasReachedMax: hasReachedMax));
        }
      },
    );
  }

  Future<void> _onUploadMediaRequested(
    UploadMediaRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    emit(PostsLoading());
    final result = await uploadMediaUseCase(event.file);
    result.fold(
      (failure) => emit(PostsFailure(failure.message)),
      (url) => emit(MediaUploadSuccess(url)),
    );
  }

  Future<void> _onCreatePostRequested(
    CreatePostRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    emit(PostsLoading());
    final result = await createPostUseCase(
      CreatePostParams(
        type: event.type,
        videoUrl: event.videoUrl,
        hlsUrl: event.hlsUrl,
        thumbnailUrl: event.thumbnailUrl,
        animatedCoverUrl: event.animatedCoverUrl,
        description: event.description,
        category: event.category,
        status: event.status,
        duration: event.duration,
        videoWidth: event.videoWidth,
        videoHeight: event.videoHeight,
        isAd: event.isAd,
        privacyStatus: event.privacyStatus,
        allowComments: event.allowComments,
        allowDuets: event.allowDuets,
        allowStitch: event.allowStitch,
        isStory: event.isStory,
        isAuctionable: event.isAuctionable,
        auction: event.auction,
        locationId: event.locationId,
        playlistId: event.playlistId,
        soundId: event.soundId,
        originalPostId: event.originalPostId,
        media: event.media,
      ),
    );

    result.fold(
      (failure) => emit(PostsFailure(failure.message)),
      (post) => emit(CreatePostSuccess(post)),
    );
  }
}
