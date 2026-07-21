import 'dart:io';

import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_input.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/create_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:bimobondapp/app/posts/domain/entities/toggle_like_params.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_like_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/entities/update_post_params.dart';
import 'package:bimobondapp/app/posts/domain/usecases/delete_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_save_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_repost_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/entities/toggle_repost_params.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_my_reposts_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/update_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/upload_media_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/utils/media_upload_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PostsBloc extends Bloc<PostsEvent, PostsState> {
  final CreatePostUseCase createPostUseCase;
  final UploadMediaUseCase uploadMediaUseCase;
  final GetFeedUseCase getFeedUseCase;
  final ToggleLikePostUsecase toggleLikePostUsecase;
  final ToggleSavePostUsecase toggleSavePostUsecase;
  final ToggleRepostPostUsecase toggleRepostPostUsecase;
  final GetMyRepostsUseCase getMyRepostsUseCase;
  final UpdatePostUsecase updatePostUsecase;
  final DeletePostUsecase deletePostUsecase;

  PostsBloc({
    required this.createPostUseCase,
    required this.uploadMediaUseCase,
    required this.getFeedUseCase,
    required this.toggleLikePostUsecase,
    required this.toggleSavePostUsecase,
    required this.toggleRepostPostUsecase,
    required this.getMyRepostsUseCase,
    required this.updatePostUsecase,
    required this.deletePostUsecase,
  }) : super(PostsInitial()) {
    on<UploadMediaRequestedEvent>(_onUploadMediaRequested);
    on<CreatePostRequestedEvent>(_onCreatePostRequested);
    on<CreatePostWithMediaRequestedEvent>(_onCreatePostWithMediaRequested);
    on<FetchFeedRequestedEvent>(_onFetchFeedRequested);
    on<FetchStoriesRequestedEvent>(_onFetchStoriesRequested);
    on<ToggleLikePostRequestedEvent>(_onToggleLikePostRequested);
    on<ToggleSavePostRequestedEvent>(_onToggleSavePostRequested);
    on<ToggleRepostPostRequestedEvent>(_onToggleRepostPostRequested);
    on<FetchMyRepostsRequestedEvent>(_onFetchMyRepostsRequested);
    on<UpdatePostRequestedEvent>(_onUpdatePostRequested);
    on<DeletePostRequestedEvent>(_onDeletePostRequested);
    on<HidePostFromFeedEvent>(_onHidePostFromFeed);
  }

  void _onHidePostFromFeed(
    HidePostFromFeedEvent event,
    Emitter<PostsState> emit,
  ) {
    emit(PostHiddenFromFeedState(event.postId));
  }

  Future<void> _onUpdatePostRequested(
    UpdatePostRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final result = await updatePostUsecase(
      UpdatePostParams(
        postId: event.postId,
        description: event.description,
        categoryId: event.categoryId,
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

  Future<void> _onToggleRepostPostRequested(
    ToggleRepostPostRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final result = await toggleRepostPostUsecase(
      ToggleRepostParams(postId: event.postId, quote: event.quote),
    );
    result.fold(
      (failure) => emit(PostsFailure(failure.message)),
      (isReposted) =>
          emit(RepostPostSuccess(postId: event.postId, isReposted: isReposted)),
    );
  }

  Future<void> _onFetchMyRepostsRequested(
    FetchMyRepostsRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final result = await getMyRepostsUseCase(
      GetMyRepostsParams(page: event.page, limit: event.limit),
    );
    result.fold(
      (failure) => emit(
        PostsFailure(failure.message, profileLoadKey: event.profileLoadKey),
      ),
      (page) {
        final reposts = List.of(page.reposts)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final posts = reposts.map((item) => item.post).toList();
        emit(
          MyRepostsLoadSuccess(
            posts: posts,
            hasReachedMax: page.hasReachedMax,
            profileLoadKey: event.profileLoadKey ?? 0,
          ),
        );
      },
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
      (_) => emit(LikePostSuccess(event.postId, liked: event.liked)),
    );
  }

  Future<String> _uploadMediaFile(File file) async {
    final prepared = await MediaUploadUtils.prepareForUpload(file);
    try {
      final result = await uploadMediaUseCase(prepared);
      return result.fold(
        (failure) => throw Exception(failure.message),
        (url) => url,
      );
    } finally {
      await MediaUploadUtils.deleteIfTemp(file, prepared);
    }
  }

  Future<String?> _uploadVideoThumbnail(File videoFile) async {
    final thumbFile = await VideoThumbnailUtils.generateThumbnailFile(
      videoFile,
    );
    if (thumbFile == null) return null;

    try {
      return await _uploadMediaFile(thumbFile);
    } finally {
      await VideoThumbnailUtils.deleteIfExists(thumbFile);
    }
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
        final file = event.files[i];
        final isVideo = VideoThumbnailUtils.isVideoFile(file);

        if (isVideo) {
          thumbnailUrl ??= await _uploadVideoThumbnail(file);

          final url = await _uploadMediaFile(file);
          videoUrl ??= url;
          mediaEntities.add(
            PostMediaEntity(url: url, mediaType: 'VIDEO', order: i),
          );
        } else {
          final url = await _uploadMediaFile(file);
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
          categoryId: event.categoryId,
          status: event.status,
          privacyStatus: event.privacyStatus,
          allowComments: event.allowComments,
          allowDuets: event.allowDuets,
          allowStitch: event.allowStitch,
          isStory: event.isStory ? true : null,
          isAuctionable: event.isAuctionable,
          auction: event.isAuctionable ? auction : null,
          media: mediaEntities,
          soundId: event.soundId,
          filterName: event.filterName,
          filterCategory: event.filterCategory,
          effectSlug: event.effectSlug,
          beautyEnabled: event.beautyEnabled,
          location: event.location,
        ),
      );

      result.fold(
        (failure) => emit(PostsFailure(failure.message)),
        (post) => emit(CreatePostSuccess(post)),
      );
    } catch (e) {
      emit(PostsFailure(ErrorMessageResolver.resolve(e)));
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
        categoryId: event.categoryId,
        type: event.type,
        hashtag: event.hashtag,
        search: event.search,
        sort: event.sort,
        userId: event.userId,
        isLiked: event.isLiked,
        isSaved: event.isSaved,
        isStory: event.isStory,
        contentType: event.contentType,
        privacyStatus: event.privacyStatus,
        from: event.from,
        latitude: event.latitude,
        longitude: event.longitude,
        radiusKm: event.radiusKm,
      ),
    );

    result.fold(
      (failure) => emit(
        PostsFailure(failure.message, profileLoadKey: event.profileLoadKey),
      ),
      (items) {
        final hasReachedMax = items.length < event.limit;
        if (event.profileLoadKey != null) {
          emit(
            ProfilePostsLoadSuccess(
              posts: items.map((item) => item.post).toList(),
              hasReachedMax: hasReachedMax,
              profileLoadKey: event.profileLoadKey!,
            ),
          );
        } else {
          emit(FeedLoadSuccess(items: items, hasReachedMax: hasReachedMax));
        }
      },
    );
  }

  Future<void> _onFetchStoriesRequested(
    FetchStoriesRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final result = await getFeedUseCase(
      GetFeedParams(
        page: event.page,
        limit: event.limit,
        isStory: true,
        activeStory: true,
      ),
    );

    result.fold(
      (failure) => emit(PostsFailure(failure.message)),
      (items) => emit(
        StoriesLoadSuccess(
          stories: items.map((item) => item.post).toList(),
          hasReachedMax: items.length < event.limit,
        ),
      ),
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
        categoryId: event.categoryId,
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
        location: event.location,
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
