import 'package:bimobondapp/app/social/data/models/social_user_model.dart';
import 'package:bimobondapp/app/social/data/models/social_user_page_model.dart';
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
}
