import 'package:bimobondapp/app/interests/data/models/user_interest_model.dart';
import 'package:bimobondapp/app/interests/domain/entities/user_interest_entity.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InterestsRemoteDataSource {
  InterestsRemoteDataSource({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw UnauthorizedException(message: 'User not authenticated');
    }
    final token = await user.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  Future<UserInterestsResult> getMyInterests() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.userInterests,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 && response.data is Map) {
        return UserInterestsResultModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(message: 'Failed to load interests');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<UserInterestsResult> setMyInterests({
    required List<String> categoryIds,
    List<String>? notInterestedCategoryIds,
  }) async {
    try {
      final response = await apiClient.dio.put(
        ApiConstants.userInterests,
        data: {
          'categoryIds': categoryIds,
          if (notInterestedCategoryIds != null)
            'notInterestedCategoryIds': notInterestedCategoryIds,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 && response.data is Map) {
        return UserInterestsResultModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(message: 'Failed to save interests');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }
}
