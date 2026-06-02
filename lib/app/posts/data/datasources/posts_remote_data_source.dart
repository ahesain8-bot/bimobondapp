import 'dart:io';

import 'package:bimobondapp/app/posts/data/models/comment_model.dart';
import 'package:bimobondapp/app/posts/data/models/post_model.dart';
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
  Future<List<PostModel>> getFeed(Map<String, dynamic> queryParams);
  Future<PostModel> getPostById(String postId);
  Future<bool> toggleLike(String postId);
  Future<bool> toggleSave(String postId);
  Future<PostModel> updatePost(String postId, Map<String, dynamic> data);
  Future<bool> deletePost(String postId);

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

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      return data['message']?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  PostModel _parsePostModel(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map) {
        return PostModel.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }
      return PostModel.fromJson(data);
    }
    throw ServerException(message: 'Invalid post response');
  }

  @override
  Future<List<PostModel>> getFeed(Map<String, dynamic> queryParams) async {
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
        final List<dynamic> data = response.data['data'];
        return data
            .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException(message: 'Failed to fetch feed');
      }
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
}
