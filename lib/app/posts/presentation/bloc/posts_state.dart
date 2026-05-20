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
  final List<PostEntity> posts;
  final bool hasReachedMax;
  const FeedLoadSuccess({required this.posts, this.hasReachedMax = false});

  @override
  List<Object?> get props => [posts, hasReachedMax];
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
  const LikePostSuccess(this.postId);

  @override
  List<Object?> get props => [postId];
}

class SavePostSuccess extends PostsState {
  final String postId;
  const SavePostSuccess(this.postId);

  @override
  List<Object?> get props => [postId];
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
