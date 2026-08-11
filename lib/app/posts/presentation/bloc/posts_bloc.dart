import 'dart:io';

import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_auction_input.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_sound_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/create_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:bimobondapp/app/posts/domain/entities/toggle_like_params.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_like_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/entities/update_post_params.dart';
import 'package:bimobondapp/app/posts/domain/usecases/delete_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/mark_post_not_interested_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_save_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_repost_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/entities/toggle_repost_params.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_my_reposts_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/update_post_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/upload_media_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/posts/presentation/utils/pending_post_uploads.dart';
import 'package:bimobondapp/app/stories/domain/entities/story_entities.dart';
import 'package:bimobondapp/app/stories/domain/usecases/stories_usecases.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/usecases/video_templates_usecases.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/media_upload_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/foundation.dart';
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
  final MarkPostNotInterestedUseCase markPostNotInterestedUseCase;
  final CreateStoryUseCase createStoryUseCase;
  final GetStoryRingsUseCase getStoryRingsUseCase;
  final DeleteStoryUseCase deleteStoryUseCase;
  final ApplyVideoTemplateUseCase? applyVideoTemplateUseCase;
  final CompleteVideoTemplateProjectUseCase? completeVideoTemplateProjectUseCase;

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
    required this.markPostNotInterestedUseCase,
    required this.createStoryUseCase,
    required this.getStoryRingsUseCase,
    required this.deleteStoryUseCase,
    this.applyVideoTemplateUseCase,
    this.completeVideoTemplateProjectUseCase,
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

  Future<void> _onHidePostFromFeed(
    HidePostFromFeedEvent event,
    Emitter<PostsState> emit,
  ) async {
    // Optimistically remove from feed; sync preference with the API.
    emit(PostHiddenFromFeedState(event.postId));
    if (!event.syncApi) return;
    await markPostNotInterestedUseCase(
      MarkPostNotInterestedParams(event.postId),
    );
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
    emit(DeletePostLoading(event.postId));
    if (event.isStory) {
      final result = await deleteStoryUseCase(event.postId);
      result.fold(
        (failure) => emit(DeletePostFailure(event.postId, failure.message)),
        (_) => emit(DeletePostSuccess(event.postId)),
      );
      return;
    }
    final result = await deletePostUsecase(event.postId);
    result.fold(
      (failure) => emit(DeletePostFailure(event.postId, failure.message)),
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

  Future<String> _uploadMediaFile(
    File file, {
    double rangeStart = 0,
    double rangeEnd = 1,
  }) async {
    final prepared = await MediaUploadUtils.prepareForUpload(file);
    try {
      final result = await uploadMediaUseCase(
        prepared,
        onSendProgress: (sent, total) {
          if (!PendingPostUploads.instance.hasPending) return;
          if (total <= 0) return;
          final local = (sent / total).clamp(0.0, 1.0);
          final overall =
              rangeStart + (rangeEnd - rangeStart) * local;
          // Reserve the last 5% for create-post.
          PendingPostUploads.instance.updateProgress(overall * 0.95);
        },
      );
      return result.fold(
        (failure) => throw Exception(failure.message),
        (url) => url,
      );
    } finally {
      await MediaUploadUtils.deleteIfTemp(file, prepared);
    }
  }

  void _markPendingPublishing() {
    if (PendingPostUploads.instance.hasPending) {
      PendingPostUploads.instance.updateProgress(0.97);
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
      File? primaryVideoFile;
      var postType = event.type;
      var templateProjectId = event.templateProjectId;
      var soundSegmentId = event.soundSegmentId;
      var videoTemplateId = event.videoTemplateId?.trim();
      if (videoTemplateId != null && videoTemplateId.isEmpty) {
        videoTemplateId = null;
      }

      final applyUseCase = applyVideoTemplateUseCase;
      final isTemplatePost = videoTemplateId != null &&
          applyUseCase != null &&
          !event.isStory;

      if (isTemplatePost) {
        // Forced: always server export with quality=draft.
        if (PendingPostUploads.instance.hasPending) {
          PendingPostUploads.instance.updateProgress(0.05);
        }
        final slotFiles = (event.templateSlotFiles != null &&
                event.templateSlotFiles!.isNotEmpty)
            ? event.templateSlotFiles!
            : event.files;

        final existingExport = MediaUtils.toServerUploadPath(
          event.templateServerExportUrl?.trim() ?? '',
        );

        if (existingExport.isNotEmpty) {
          videoUrl = existingExport;
          postType = 'VIDEO';
          templateProjectId =
              VideoTemplateProjectIds.normalizeServerId(templateProjectId) ??
                  templateProjectId;
          if (slotFiles.isNotEmpty &&
              !VideoThumbnailUtils.isVideoFile(slotFiles.first)) {
            thumbnailUrl = await _uploadMediaFile(
              slotFiles.first,
              rangeStart: 0.55,
              rangeEnd: 0.95,
            );
          }
          if (PendingPostUploads.instance.hasPending) {
            PendingPostUploads.instance.updateProgress(0.9);
          }
        } else {
          final applyResult = await applyUseCase(
            selection: VideoTemplateSelection(
              templateId: videoTemplateId,
              name: '',
              projectId:
                  VideoTemplateProjectIds.normalizeServerId(templateProjectId),
              soundSegmentId: soundSegmentId,
            ),
            localFiles: slotFiles,
            preferServerExport: true,
            allowClientFallback: false,
            renderClientVideo: false,
            exportQuality: 'draft',
          );
          final applied = applyResult.fold<VideoTemplateApplyResult?>(
            (_) => null,
            (r) => r,
          );
          if (applied == null) {
            applyResult.fold(
              (f) => emit(PostsFailure(f.message)),
              (_) => emit(PostsFailure('template_apply_failed')),
            );
            return;
          }
          if (PendingPostUploads.instance.hasPending) {
            PendingPostUploads.instance.updateProgress(0.55);
          }
          templateProjectId = applied.projectId;
          soundSegmentId =
              applied.selection.soundSegmentId ?? soundSegmentId;
          if (!applied.recipe.canAttachTemplateToPost) {
            videoTemplateId = null;
          }

          final serverUrl = applied.serverExportUrl;
          var rendered = applied.renderedVideo;
          if (rendered != null && !await rendered.exists()) {
            rendered = null;
          }

          if (serverUrl != null && serverUrl.isNotEmpty) {
            videoUrl = serverUrl;
            postType = 'VIDEO';
            if (slotFiles.isNotEmpty &&
                !VideoThumbnailUtils.isVideoFile(slotFiles.first)) {
              thumbnailUrl = await _uploadMediaFile(
                slotFiles.first,
                rangeStart: 0.55,
                rangeEnd: 0.95,
              );
            }
            if (PendingPostUploads.instance.hasPending) {
              PendingPostUploads.instance.updateProgress(0.9);
            }
          } else if (rendered != null) {
            primaryVideoFile = rendered;
            thumbnailUrl = await _uploadVideoThumbnail(rendered);
            if (PendingPostUploads.instance.hasPending) {
              PendingPostUploads.instance.updateProgress(0.65);
            }
            videoUrl = await _uploadMediaFile(
              rendered,
              rangeStart: 0.65,
              rangeEnd: 0.95,
            );
            postType = 'VIDEO';
          } else {
            emit(
              const PostsFailure(
                'Template export failed — try again or check connection',
              ),
            );
            return;
          }
        }
      } else {
        final n = event.files.length;
        for (int i = 0; i < n; i++) {
          final file = event.files[i];
          final isVideo = VideoThumbnailUtils.isVideoFile(file);
          final start = n == 0 ? 0.0 : i / n;
          final end = n == 0 ? 1.0 : (i + 1) / n;

          if (isVideo) {
            // Thumbnail is a small share of this file's range.
            final mid = start + (end - start) * 0.15;
            thumbnailUrl ??= await _uploadVideoThumbnail(file);
            // Rough bump after thumb (no Dio bytes for nested call weight).
            if (PendingPostUploads.instance.hasPending) {
              PendingPostUploads.instance.updateProgress(mid * 0.95);
            }
            primaryVideoFile ??= file;

            final url = await _uploadMediaFile(
              file,
              rangeStart: mid,
              rangeEnd: end,
            );
            videoUrl ??= url;
            mediaEntities.add(
              PostMediaEntity(url: url, mediaType: 'VIDEO', order: i),
            );
          } else {
            final url = await _uploadMediaFile(
              file,
              rangeStart: start,
              rangeEnd: end,
            );
            mediaEntities.add(
              PostMediaEntity(url: url, mediaType: 'IMAGE', order: i),
            );
          }
        }
      }

      _markPendingPublishing();

      PostAuctionInput? auction = event.auction;
      if (event.isAuctionable && auction != null) {
        final coverUrl =
            thumbnailUrl ??
            (mediaEntities.isNotEmpty ? mediaEntities.first.url : null);
        auction = auction.copyWith(itemImageUrl: coverUrl);
      }

      final newSound = await _resolveNewSound(
        event: event,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        primaryVideoFile: primaryVideoFile,
      );

      if (event.isStory) {
        final storyResult = await createStoryUseCase(
          CreateStoryInput(
            type: event.type,
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            description: event.description,
            categoryId: event.categoryId,
            status: event.status,
            privacyStatus: event.privacyStatus,
            media: mediaEntities,
            soundId: event.soundId,
            soundSegmentId: event.soundSegmentId,
            startMs: event.startMs,
            endMs: event.endMs,
            newSound: newSound,
            filterName: event.filterName,
            filterCategory: event.filterCategory,
            effectSlug: event.effectSlug,
            beautyEnabled: event.beautyEnabled,
            location: event.location,
          ),
        );
        storyResult.fold(
          (failure) => emit(PostsFailure(failure.message)),
          (story) => emit(CreatePostSuccess(story.toPostEntity())),
        );
        return;
      }

      final result = await createPostUseCase(
        CreatePostParams(
          type: postType,
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          description: event.description,
          categoryId: event.categoryId,
          status: event.status,
          privacyStatus: event.privacyStatus,
          allowComments: event.allowComments,
          allowDuets: event.allowDuets,
          allowStitch: event.allowStitch,
          isAuctionable: event.isAuctionable,
          auction: event.isAuctionable ? auction : null,
          media: mediaEntities.isEmpty ? null : mediaEntities,
          soundId: event.soundId,
          soundSegmentId: soundSegmentId,
          startMs: event.startMs,
          endMs: event.endMs,
          newSound: newSound,
          filterName: event.filterName,
          filterCategory: event.filterCategory,
          effectSlug: event.effectSlug,
          beautyEnabled: event.beautyEnabled,
          location: event.location,
          videoTemplateId: videoTemplateId,
          // Only link project when template id is attached (Nest photo-slot rule).
          templateProjectId:
              videoTemplateId != null ? templateProjectId : null,
        ),
      );

      await result.fold(
        (failure) async => emit(PostsFailure(failure.message)),
        (post) async {
          // Complete project after successful post (mobile-api sequence).
          final projectId = templateProjectId?.trim();
          final complete = completeVideoTemplateProjectUseCase;
          if (projectId != null &&
              projectId.isNotEmpty &&
              complete != null) {
            await complete(projectId);
          }

          final chosen = event.sound;
          PostEntity finalPost = post;
          if (chosen != null) {
            final enrichedSound = PostSoundEntity(
              id: chosen.id,
              name: chosen.name,
              author: chosen.author,
              duration: chosen.duration,
              useCount: chosen.useCount,
              audioUrl: chosen.resolvedAudioUrl,
              segmentId: soundSegmentId ?? post.sound?.segmentId,
              startMs: event.startMs ?? post.sound?.startMs,
              endMs: event.endMs ?? post.sound?.endMs,
            );
            finalPost = post.copyWith(sound: enrichedSound);
          }
          emit(CreatePostSuccess(finalPost));
        },
      );
    } catch (e) {
      emit(PostsFailure(ErrorMessageResolver.resolve(e)));
    }
  }

  /// Builds inline `newSound` for original recorded video audio when the
  /// Mode C: Return explicit [newSound] if provided; otherwise null so original-audio
  /// videos omit all sound fields as per mobile-api spec.
  Future<Map<String, dynamic>?> _resolveNewSound({
    required CreatePostWithMediaRequestedEvent event,
    required String? videoUrl,
    required String? thumbnailUrl,
    required File? primaryVideoFile,
  }) async {
    return event.newSound;
  }

  Future<void> _onFetchFeedRequested(
    FetchFeedRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final usingCursor = event.cursor != null && event.cursor!.trim().isNotEmpty;
    final isFirstPage = event.isRefresh || (!usingCursor && event.page <= 1);
    if (isFirstPage) {
      emit(PostsLoading());
    }

    final result = await getFeedUseCase(
      GetFeedParams(
        page: event.page,
        limit: event.limit,
        cursor: event.cursor,
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
        auctionQuery: event.auctionQuery,
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
      (page) {
        if (event.profileLoadKey != null) {
          emit(
            ProfilePostsLoadSuccess(
              posts: page.items.map((item) => item.post).toList(),
              hasReachedMax: page.hasReachedMax,
              profileLoadKey: event.profileLoadKey!,
            ),
          );
        } else {
          emit(
            FeedLoadSuccess(
              items: page.items,
              hasReachedMax: page.hasReachedMax,
              nextCursor: page.nextCursor,
              isFirstPage: isFirstPage,
            ),
          );
        }
      },
    );
  }

  Future<void> _onFetchStoriesRequested(
    FetchStoriesRequestedEvent event,
    Emitter<PostsState> emit,
  ) async {
    final result = await getStoryRingsUseCase(NoParams());

    result.fold((failure) => emit(PostsFailure(failure.message)), (rings) {
      final stories = <PostEntity>[];
      for (final ring in rings) {
        for (final story in ring.stories) {
          stories.add(story.toPostEntity());
        }
      }
      emit(StoriesLoadSuccess(stories: stories, hasReachedMax: true));
    });
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
    if (event.isStory == true) {
      final storyResult = await createStoryUseCase(
        CreateStoryInput(
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
          privacyStatus: event.privacyStatus,
          locationId: event.locationId,
          location: event.location,
          soundId: event.soundId,
          soundSegmentId: event.soundSegmentId,
          startMs: event.startMs,
          endMs: event.endMs,
          newSound: event.newSound,
          media: event.media,
        ),
      );
      storyResult.fold(
        (failure) => emit(PostsFailure(failure.message)),
        (story) => emit(CreatePostSuccess(story.toPostEntity())),
      );
      return;
    }
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
        isAuctionable: event.isAuctionable,
        auction: event.auction,
        locationId: event.locationId,
        location: event.location,
        playlistId: event.playlistId,
        soundId: event.soundId,
        soundSegmentId: event.soundSegmentId,
        startMs: event.startMs,
        endMs: event.endMs,
        newSound: event.newSound,
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
