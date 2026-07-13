import 'package:bimobondapp/app/search/data/models/search_history_model.dart';
import 'package:bimobondapp/app/search/data/models/search_trend_model.dart';
import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchHistoryRemoteDataSource {
  SearchHistoryRemoteDataSource({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw UnauthorizedException(message: 'User not authenticated');
    }
    final token = await user.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  Future<SearchHistoryPageEntity> getHistory({
    String? category,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.searchHistory,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (category != null && category.isNotEmpty) 'category': category,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 && response.data is Map) {
        return SearchHistoryPageModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(message: 'Failed to load search history');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<SearchHistoryEntity> addHistory({
    required String query,
    required String category,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.searchHistory,
        data: {'query': query, 'category': category},
        options: Options(headers: await _authHeaders()),
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data is Map) {
        return SearchHistoryModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(message: 'Failed to save search');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<ClearSearchHistoryResult> clearHistory({String? category}) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.searchHistory,
        queryParameters: {
          if (category != null && category.isNotEmpty) 'category': category,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 && response.data is Map) {
        return ClearSearchHistoryResultModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(message: 'Failed to clear search history');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<void> deleteHistory(String id) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.searchHistoryById(id),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }
      throw ServerException(message: 'Failed to delete search history item');
    } on DioException catch (error) {
      throw DioHandler.handle(error);
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<List<SearchTrendModel>> getTrends({
    String? category,
    int limit = 10,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.searchTrends,
        queryParameters: {
          'limit': limit,
          if (category != null && category.isNotEmpty) 'category': category,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return parseSearchTrendsResponse(response.data);
      }
      throw ServerException(message: 'Failed to load search trends');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }
}
