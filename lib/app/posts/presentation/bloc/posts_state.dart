import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:equatable/equatable.dart';

abstract class PostsState extends Equatable {
  const PostsState();

  @override
  List<Object?> get props => [];
}

class PostsInitial extends PostsState {}

class PostsLoading extends PostsState {}

class MediaUploadSuccess extends PostsState {
  final String url;
  const MediaUploadSuccess(this.url);

  @override
  List<Object?> get props => [url];
}

class CreatePostSuccess extends PostsState {
  final PostEntity post;
  const CreatePostSuccess(this.post);

  @override
  List<Object?> get props => [post];
}

class FeedLoadSuccess extends PostsState {
  final List<FeedItemEntity> items;
  final bool hasReachedMax;
  final String? nextCursor;
  /// True when this response is a first page / refresh (no cursor was sent).
  final bool isFirstPage;

  const FeedLoadSuccess({
    required this.items,
    this.hasReachedMax = false,
    this.nextCursor,
    this.isFirstPage = true,
  });

  @override
  List<Object?> get props => [items, hasReachedMax, nextCursor, isFirstPage];
}

class StoriesLoadSuccess extends PostsState {
  final List<PostEntity> stories;
  final bool hasReachedMax;

  const StoriesLoadSuccess({
    required this.stories,
    this.hasReachedMax = false,
  });

  @override
  List<Object?> get props => [stories, hasReachedMax];
}

class ProfilePostsLoadSuccess extends PostsState {
  final List<PostEntity> posts;
  final bool hasReachedMax;
  final int profileLoadKey;

  const ProfilePostsLoadSuccess({
    required this.posts,
    required this.profileLoadKey,
    this.hasReachedMax = false,
  });

  @override
  List<Object?> get props => [posts, hasReachedMax, profileLoadKey];
}

class PostsFailure extends PostsState {
  final String message;
  final int? profileLoadKey;

  const PostsFailure(this.message, {this.profileLoadKey});

  @override
  List<Object?> get props => [message, profileLoadKey];
}

class LikePostSuccess extends PostsState {
  final String postId;
  final bool liked;

  const LikePostSuccess(this.postId, {required this.liked});

  @override
  List<Object?> get props => [postId, liked];
}

class SavePostSuccess extends PostsState {
  final String postId;
  const SavePostSuccess(this.postId);

  @override
  List<Object?> get props => [postId];
}

class RepostPostSuccess extends PostsState {
  final String postId;
  final bool isReposted;

  const RepostPostSuccess({
    required this.postId,
    required this.isReposted,
  });

  @override
  List<Object?> get props => [postId, isReposted];
}

class MyRepostsLoadSuccess extends PostsState {
  final List<PostEntity> posts;
  final bool hasReachedMax;
  final int profileLoadKey;

  const MyRepostsLoadSuccess({
    required this.posts,
    required this.profileLoadKey,
    this.hasReachedMax = false,
  });

  @override
  List<Object?> get props => [posts, hasReachedMax, profileLoadKey];
}

class UpdatePostSuccess extends PostsState {
  final PostEntity post;

  const UpdatePostSuccess(this.post);

  @override
  List<Object?> get props => [post];
}

class DeletePostSuccess extends PostsState {
  final String postId;

  const DeletePostSuccess(this.postId);

  @override
  List<Object?> get props => [postId];
}

class PostHiddenFromFeedState extends PostsState {
  const PostHiddenFromFeedState(this.postId);

  final String postId;

  @override
  List<Object?> get props => [postId];
}
