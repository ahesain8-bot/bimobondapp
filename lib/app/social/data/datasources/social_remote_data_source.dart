import 'package:bimobondapp/app/social/data/models/social_user_model.dart';
import 'package:bimobondapp/app/social/data/models/social_user_page_model.dart';
import 'package:bimobondapp/app/social/data/models/user_comment_model.dart';
import 'package:bimobondapp/app/social/data/models/user_comments_page_model.dart';
import 'package:bimobondapp/app/social/data/models/user_like_model.dart';
import 'package:bimobondapp/app/social/data/models/user_likes_page_model.dart';
import 'package:bimobondapp/app/social/data/models/user_mention_model.dart';
import 'package:bimobondapp/app/social/data/models/user_mentions_page_model.dart';
import 'package:bimobondapp/app/social/data/models/user_suggestion_model.dart';
import 'package:bimobondapp/app/social/domain/entities/follow_status.dart';
import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class SocialRemoteDataSource {
  Future<FollowStatus> toggleFollow(String userId);

  Future<SocialUserPageModel> getFollowers(SocialListQuery query);

  Future<SocialUserPageModel> getFollowing(SocialListQuery query);

  Future<SocialUserPageModel> getMyFriends(SocialListQuery query);

  Future<List<UserSuggestionModel>> getSuggestions({int limit = 20});

  Future<UserCommentsPageModel> getUserComments({
    String? userId,
    required int page,
    required int limit,
  });

  Future<UserLikesPageModel> getMyLikes({
    required int page,
    required int limit,
  });

  Future<UserMentionsPageModel> getMyMentions({
    required int page,
    required int limit,
  });
}

class SocialRemoteDataSourceImpl implements SocialRemoteDataSource {
  SocialRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> _authHeaders() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final idToken = await firebaseUser.getIdToken();
      return {'Authorization': 'Bearer $idToken'};
    }
    return {};
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
      final data = body['data'];
      if (data is List) return data;
      for (final key in [
        'items',
        'users',
        'friends',
        'followers',
        'following',
        'suggestions',
        'comments',
        'likes',
        'mentions',
      ]) {
        final nested = body[key];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  Map<String, dynamic> _extractObject(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
      return body;
    }
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      if (map['data'] is Map) {
        return Map<String, dynamic>.from(map['data'] as Map);
      }
      return map;
    }
    throw ServerException(message: 'Invalid response');
  }

  List<SocialUserModel> _parseUsers(dynamic body) {
    return _extractList(body)
        .whereType<Map>()
        .map((e) => SocialUserModel.fromJson(Map<String, dynamic>.from(e)))
        .where((u) => u.id.isNotEmpty)
        .toList();
  }

  SocialUserPageModel _parsePage(
    dynamic body,
    SocialListQuery query,
  ) {
    return SocialUserPageModel.fromResponse(
      body,
      _parseUsers(body),
      requestedPage: query.page,
      requestedLimit: query.limit,
    );
  }

  @override
  Future<FollowStatus> toggleFollow(String userId) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.followUser(userId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _extractObject(response.data);
        return FollowStatus.fromResponse(data);
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to follow user',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<SocialUserPageModel> getFollowers(SocialListQuery query) async {
    try {
      final userId = query.userId;
      if (userId == null || userId.isEmpty) {
        throw ServerException(message: 'User id is required');
      }

      final response = await apiClient.dio.get(
        ApiConstants.userFollowers(userId),
        queryParameters: query.toQueryParams(),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return _parsePage(response.data, query);
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load followers',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<SocialUserPageModel> getFollowing(SocialListQuery query) async {
    try {
      final userId = query.userId;
      if (userId == null || userId.isEmpty) {
        throw ServerException(message: 'User id is required');
      }

      final response = await apiClient.dio.get(
        ApiConstants.userFollowing(userId),
        queryParameters: query.toQueryParams(),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return _parsePage(response.data, query);
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load following',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<SocialUserPageModel> getMyFriends(SocialListQuery query) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.myFriends,
        queryParameters: query.toQueryParams(),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return _parsePage(response.data, query);
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load friends',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<UserSuggestionModel>> getSuggestions({int limit = 20}) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.mySuggestions,
        queryParameters: {'limit': limit},
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return _extractList(response.data)
            .whereType<Map>()
            .map(
              (e) => UserSuggestionModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .where((s) => s.id.isNotEmpty)
            .toList();
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ??
            'Failed to load suggestions',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<UserCommentsPageModel> getUserComments({
    String? userId,
    required int page,
    required int limit,
  }) async {
    try {
      final path = userId == null || userId.isEmpty
          ? ApiConstants.myComments
          : ApiConstants.userComments(userId);

      final response = await apiClient.dio.get(
        path,
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: await _authHeaders()),
      );

      if (response.statusCode == 200) {
        final comments = _extractList(response.data)
            .whereType<Map>()
            .map(
              (e) => UserCommentModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .where((comment) => comment.id.isNotEmpty)
            .toList();

        return UserCommentsPageModel.fromResponse(
          response.data,
          comments,
          requestedPage: page,
          requestedLimit: limit,
        );
      }

      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load comments',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<UserLikesPageModel> getMyLikes({
    required int page,
    required int limit,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.myLikes,
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: await _authHeaders()),
      );

      if (response.statusCode == 200) {
        final likes = _extractList(response.data)
            .whereType<Map>()
            .map(
              (e) => UserLikeModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .where((like) => like.postId.isNotEmpty)
            .toList();

        return UserLikesPageModel.fromResponse(
          response.data,
          likes,
          requestedPage: page,
          requestedLimit: limit,
        );
      }

      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load likes',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<UserMentionsPageModel> getMyMentions({
    required int page,
    required int limit,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.myMentions,
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: await _authHeaders()),
      );

      if (response.statusCode == 200) {
        final mentions = _extractList(response.data)
            .whereType<Map>()
            .map(
              (e) => UserMentionModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .where((mention) => mention.postId.isNotEmpty)
            .toList();

        return UserMentionsPageModel.fromResponse(
          response.data,
          mentions,
          requestedPage: page,
          requestedLimit: limit,
        );
      }

      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load mentions',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
