import 'dart:io';

import 'package:bimobondapp/app/posts/data/models/comment_model.dart';
import 'package:bimobondapp/app/posts/data/models/post_model.dart';
import 'package:bimobondapp/app/posts/data/models/post_view_model.dart';
import 'package:bimobondapp/app/posts/data/models/feed_item_model.dart';
import 'package:bimobondapp/app/posts/data/models/hashtag_model.dart';
import 'package:bimobondapp/app/posts/domain/entities/hashtag_entity.dart';
import 'package:bimobondapp/app/posts/data/models/repost_model.dart';
import 'package:bimobondapp/app/posts/data/models/post_views_page_model.dart';
import 'package:bimobondapp/app/social/data/models/social_user_model.dart';
import 'package:bimobondapp/app/social/data/models/social_user_page_model.dart';
import 'package:bimobondapp/app/social/data/models/user_like_model.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class PostsRemoteDataSource {
  Future<PostModel> createPost(Map<String, dynamic> postData);
  Future<String> uploadMedia(File file);
  Future<List<FeedItemModel>> getFeed(Map<String, dynamic> queryParams);
  Future<HashtagsPageModel> getHashtags({
    int page = 1,
    int limit = 20,
    String? search,
    HashtagSort sort = HashtagSort.name,
  });
  Future<PostModel> getPostById(String postId);
  Future<bool> toggleLike(String postId);
  Future<SocialUserPageModel> getPostLikes(
    String postId, {
    int page = 1,
    int limit = 20,
  });
  Future<PostViewsPageModel> getPostViews(
    String postId, {
    int page = 1,
    int limit = 20,
  });
  Future<int> recordPostView(
    String postId, {
    int? watchedDuration,
    String? campaignId,
  });
  Future<bool> toggleSave(String postId);
  Future<bool> toggleRepost(String postId, {String? quote});
  Future<RepostsPageModel> getPostReposts(
    String postId, {
    int page = 1,
    int limit = 20,
  });
  Future<UserRepostsPageModel> getMyReposts({
    int page = 1,
    int limit = 10,
  });
  Future<PostModel> updatePost(String postId, Map<String, dynamic> data);
  Future<bool> deletePost(String postId);
  Future<void> markPostNotInterested(String postId);
  Future<void> undoPostNotInterested(String postId);
  Future<void> reportPost(
    String postId, {
    required String reason,
    String? details,
  });
  Future<Map<String, dynamic>> sharePost(
    String postId, {
    String channel = 'EXTERNAL',
  });

  // Comments
  Future<List<CommentModel>> getComments(
    String postId,
    Map<String, dynamic> queryParams,
  );
  Future<CommentModel> addComment(String postId, Map<String, dynamic> data);
  Future<List<CommentModel>> getReplies(
    String commentId,
    Map<String, dynamic> queryParams,
  );
  Future<bool> deleteComment(String commentId);
  Future<bool> toggleLikeComment(String commentId);
  Future<SocialUserPageModel> getCommentLikes(
    String commentId, {
    int page = 1,
    int limit = 20,
  });
}

class PostsRemoteDataSourceImpl implements PostsRemoteDataSource {
  final ApiClient apiClient;

  PostsRemoteDataSourceImpl({required this.apiClient});

  /// Firebase token when available; otherwise relies on [ApiClient] AUTH_TOKEN.
  Future<Map<String, dynamic>> _optionalAuthHeaders() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final idToken = await firebaseUser.getIdToken();
      return {'Authorization': 'Bearer $idToken'};
    }
    return {};
  }

  Future<Map<String, dynamic>> _requiredAuthHeaders() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw ServerException(message: 'User not authenticated');
    }
    final idToken = await firebaseUser.getIdToken();
    return {'Authorization': 'Bearer $idToken'};
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      return data['message']?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      final data = map['data'];
      if (data is List) return data;
      if (data is Map) {
        final nestedData = Map<String, dynamic>.from(data);
        for (final key in [
          'items',
          'users',
          'likes',
          'likers',
          'views',
          'viewers',
        ]) {
          final nested = nestedData[key];
          if (nested is List) return nested;
        }
      }
      for (final key in ['items', 'users', 'likes', 'likers', 'views', 'viewers']) {
        final nested = map[key];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  Map<String, dynamic> _postViewsEnvelope(dynamic body) {
    if (body is! Map) return {};
    final root = Map<String, dynamic>.from(body);
    final data = root['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return root;
  }

  List<dynamic> _extractViewsList(dynamic body) {
    final envelope = _postViewsEnvelope(body);
    final nested = envelope['views'] ?? envelope['viewers'];
    if (nested is List) return nested;
    return _extractList(body);
  }

  List<SocialUserModel> _parsePostLikers(dynamic body) {
    final users = <SocialUserModel>[];
    final seen = <String>{};

    void addUser(SocialUserModel user, {DateTime? likedAt}) {
      if (user.id.isEmpty || seen.contains(user.id)) return;
      seen.add(user.id);
      users.add(
        likedAt == null
            ? user
            : SocialUserModel(
                id: user.id,
                username: user.username,
                fullName: user.fullName,
                avatarUrl: user.avatarUrl,
                isActive: user.isActive,
                isFollowing: user.isFollowing,
                isFollowedBy: user.isFollowedBy,
                likedAt: likedAt,
              ),
      );
    }

    for (final entry in _extractList(body)) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      if (map['user'] is Map ||
          map['liker'] is Map ||
          map['likedBy'] is Map) {
        final like = UserLikeModel.fromJson(map);
        if (like.user != null) {
          final u = like.user!;
          final likedAt = DateTime.tryParse(like.createdAt);
          addUser(
            SocialUserModel(
              id: u.id,
              username: u.username,
              fullName: u.fullName,
              avatarUrl: u.avatarUrl,
              isActive: u.isActive,
              isFollowing: u.isFollowing,
              isFollowedBy: u.isFollowedBy,
            ),
            likedAt: likedAt,
          );
          continue;
        }
      }
      addUser(
        SocialUserModel.fromJson(map),
        likedAt: DateTime.tryParse(
          map['createdAt']?.toString() ?? map['likedAt']?.toString() ?? '',
        ),
      );
    }

    return users;
  }

  List<PostViewModel> _parsePostViews(dynamic body) {
    final views = <PostViewModel>[];
    final seen = <String>{};

    for (final entry in _extractViewsList(body)) {
      if (entry is! Map) continue;
      final view = PostViewModel.fromJson(Map<String, dynamic>.from(entry));
      final dedupeKey = view.id.isNotEmpty
          ? view.id
          : view.userId.isNotEmpty
              ? '${view.userId}_${view.createdAt?.toIso8601String() ?? ''}'
              : '';
      if (dedupeKey.isEmpty || seen.contains(dedupeKey)) continue;
      seen.add(dedupeKey);
      views.add(view);
    }

    return views;
  }

  PostModel _parsePostModel(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map) {
        return _parsePostModel(data['data']);
      }
      if (data['post'] is Map) {
        return PostModel.fromJson(
          Map<String, dynamic>.from(data['post'] as Map),
        );
      }
      return PostModel.fromJson(data);
    }
    throw ServerException(message: 'Invalid post response');
  }

  @override
  Future<List<FeedItemModel>> getFeed(Map<String, dynamic> queryParams) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final Map<String, dynamic> headers = {};
      String endpoint = ApiConstants.publicFeed;

      if (user != null) {
        final idToken = await user.getIdToken();
        headers['Authorization'] = 'Bearer $idToken';
        endpoint = ApiConstants.getFeed;
      }

      final response = await apiClient.dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final raw = response.data['data'];
        if (raw is! List) return const [];
        return raw
            .whereType<Map>()
            .map((e) => FeedItemModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        throw ServerException(message: 'Failed to fetch feed');
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<HashtagsPageModel> getHashtags({
    int page = 1,
    int limit = 20,
    String? search,
    HashtagSort sort = HashtagSort.name,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.postsHashtags,
        queryParameters: {
          'page': page,
          'limit': limit,
          'sort': sort.apiValue,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      if (response.statusCode == 200) {
        return HashtagsPageModel.fromResponse(
          response.data,
          requestedPage: page,
          requestedLimit: limit,
        );
      }

      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load hashtags',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<PostModel> getPostById(String postId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.postById(postId),
        options: Options(headers: await _optionalAuthHeaders()),
      );

      if (response.statusCode == 200) {
        return _parsePostModel(response.data);
      }

      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to fetch post',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<String> uploadMedia(File file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw ServerException(message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();
      final fileName = file.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'files': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await apiClient.dio.post(
        ApiConstants.uploadMedia,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        String? uploadedUrl;

        if (data is Map<String, dynamic>) {
          if (data['urls'] is List && (data['urls'] as List).isNotEmpty) {
            uploadedUrl = (data['urls'] as List).first.toString();
          } else {
            uploadedUrl = (data['url'] ?? data['link'] ?? data['data']?['url'])
                ?.toString();
          }
        } else if (data is String) {
          uploadedUrl = data;
        }

        if (uploadedUrl != null) {
          // If the URL is relative, prepend the base URL
          return MediaUtils.resolveAbsoluteUrl(uploadedUrl);
        }

        throw ServerException(message: 'Invalid response from upload media');
      } else {
        throw ServerException(message: 'Failed to upload media');
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<PostModel> createPost(Map<String, dynamic> postData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw ServerException(message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();

      final response = await apiClient.dio.post(
        ApiConstants.createPost,
        data: postData,
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return PostModel.fromJson(response.data);
      } else {
        throw ServerException(message: 'Failed to create post');
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<SocialUserPageModel> getPostLikes(
    String postId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.postLikes(postId),
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: await _optionalAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final users = _parsePostLikers(response.data);
        return SocialUserPageModel.fromResponse(
          response.data,
          users,
          requestedPage: page,
          requestedLimit: limit,
        );
      }

      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load likes',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<PostViewsPageModel> getPostViews(
    String postId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.postViews(postId),
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: await _requiredAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final views = _parsePostViews(response.data);
        return PostViewsPageModel.fromResponse(
          response.data,
          views,
          requestedPage: page,
          requestedLimit: limit,
          envelope: _postViewsEnvelope(response.data),
        );
      }

      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load views',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<int> recordPostView(
    String postId, {
    int? watchedDuration,
    String? campaignId,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (watchedDuration != null) {
        body['watchedDuration'] = watchedDuration;
      }
      if (campaignId != null && campaignId.isNotEmpty) {
        body['campaignId'] = campaignId;
      }

      final response = await apiClient.dio.post(
        ApiConstants.recordPostView(postId),
        data: body.isEmpty ? null : body,
        options: Options(headers: await _requiredAuthHeaders()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final count = data['viewCount'] ?? data['viewsCount'];
          if (count is num) return count.toInt();
          final nested = data['data'];
          if (nested is Map<String, dynamic>) {
            final nestedCount = nested['viewCount'] ?? nested['viewsCount'];
            if (nestedCount is num) return nestedCount.toInt();
          }
        }
        return 0;
      }

      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to record view',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> markPostNotInterested(String postId) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.postNotInterested(postId),
        options: Options(headers: await _requiredAuthHeaders()),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: _extractErrorMessage(response.data) ??
              'Failed to mark not interested',
        );
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> undoPostNotInterested(String postId) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.postNotInterested(postId),
        options: Options(headers: await _requiredAuthHeaders()),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ServerException(
          message: _extractErrorMessage(response.data) ??
              'Failed to undo not interested',
        );
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> reportPost(
    String postId, {
    required String reason,
    String? details,
  }) async {
    try {
      final body = <String, dynamic>{
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      };
      final response = await apiClient.dio.post(
        ApiConstants.reportPost(postId),
        data: body,
        options: Options(headers: await _requiredAuthHeaders()),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message:
              _extractErrorMessage(response.data) ?? 'Failed to report post',
        );
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<Map<String, dynamic>> sharePost(
    String postId, {
    String channel = 'EXTERNAL',
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.sharePost(postId),
        data: {'channel': channel},
        options: Options(headers: await _requiredAuthHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final nested = data['data'];
          if (nested is Map<String, dynamic>) return nested;
          return data;
        }
        return {'postId': postId, 'channel': channel};
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to share post',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<bool> toggleLike(String postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw ServerException(message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();

      final response = await apiClient.dio.post(
        ApiConstants.toggleLike(postId),
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw ServerException(message: 'Failed to toggle like');
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<PostModel> updatePost(String postId, Map<String, dynamic> data) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.postById(postId),
        data: data,
        options: Options(headers: await _optionalAuthHeaders()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _parsePostModel(response.data);
      } else {
        throw ServerException(
          message:
              _extractErrorMessage(response.data) ?? 'Failed to update post',
        );
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<bool> deletePost(String postId) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.postById(postId),
        options: Options(headers: await _optionalAuthHeaders()),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }

      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to delete post',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<bool> toggleSave(String postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw ServerException(message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();

      final response = await apiClient.dio.post(
        ApiConstants.toggleSave(postId),
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw ServerException(message: 'Failed to toggle save');
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<bool> toggleRepost(String postId, {String? quote}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw ServerException(message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();
      final trimmedQuote = quote?.trim();
      final data = trimmedQuote != null && trimmedQuote.isNotEmpty
          ? {'quote': trimmedQuote}
          : null;

      final response = await apiClient.dio.post(
        ApiConstants.toggleRepost(postId),
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        if (body is Map && body['isReposted'] is bool) {
          return body['isReposted'] as bool;
        }
        return true;
      }

      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to toggle repost',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<RepostsPageModel> getPostReposts(
    String postId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.postReposts(postId),
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: await _optionalAuthHeaders()),
      );

      if (response.statusCode == 200) {
        return RepostsPageModel.fromResponse(
          response.data,
          requestedPage: page,
          requestedLimit: limit,
        );
      }

      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load reposts',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<UserRepostsPageModel> getMyReposts({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw ServerException(message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();
      final response = await apiClient.dio.get(
        ApiConstants.myReposts,
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );

      if (response.statusCode == 200) {
        return UserRepostsPageModel.fromResponse(
          response.data,
          requestedPage: page,
          requestedLimit: limit,
        );
      }

      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load my reposts',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<CommentModel>> getComments(
    String postId,
    Map<String, dynamic> queryParams,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final Map<String, dynamic> headers = {};
      if (user != null) {
        final idToken = await user.getIdToken();
        headers['Authorization'] = 'Bearer $idToken';
      }

      final response = await apiClient.dio.get(
        ApiConstants.getComments(postId),
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => CommentModel.fromJson(json)).toList();
      } else {
        throw ServerException(message: 'Failed to fetch comments');
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<CommentModel> addComment(
    String postId,
    Map<String, dynamic> data,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw ServerException(message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();

      final response = await apiClient.dio.post(
        ApiConstants.addComment(postId),
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final commentData = response.data['data'] ?? response.data;
        return CommentModel.fromJson(commentData as Map<String, dynamic>);
      } else {
        throw ServerException(message: 'Failed to add comment');
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<CommentModel>> getReplies(
    String commentId,
    Map<String, dynamic> queryParams,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final Map<String, dynamic> headers = {};
      if (user != null) {
        final idToken = await user.getIdToken();
        headers['Authorization'] = 'Bearer $idToken';
      }

      final response = await apiClient.dio.get(
        ApiConstants.getReplies(commentId),
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => CommentModel.fromJson(json)).toList();
      } else {
        throw ServerException(message: 'Failed to fetch replies');
      }
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<bool> deleteComment(String commentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw ServerException(message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();

      final response = await apiClient.dio.delete(
        ApiConstants.deleteComment(commentId),
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<bool> toggleLikeComment(String commentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw ServerException(message: 'User not authenticated');
      }

      final idToken = await user.getIdToken();

      final response = await apiClient.dio.post(
        ApiConstants.toggleLikeComment(commentId),
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<SocialUserPageModel> getCommentLikes(
    String commentId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.commentLikes(commentId),
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: await _optionalAuthHeaders()),
      );

      if (response.statusCode == 200) {
        final users = _parsePostLikers(response.data);
        return SocialUserPageModel.fromResponse(
          response.data,
          users,
          requestedPage: page,
          requestedLimit: limit,
        );
      }

      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load likes',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
