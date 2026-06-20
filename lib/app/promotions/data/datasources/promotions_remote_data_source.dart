import 'package:bimobondapp/app/promotions/domain/entities/promotion_entities.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PromotionsRemoteDataSource {
  PromotionsRemoteDataSource({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw ServerException(message: 'User not authenticated');
    }
    final idToken = await user.getIdToken();
    return {'Authorization': 'Bearer $idToken'};
  }

  Future<PromotionOptionsEntity> getOptions() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.promotionsOptions,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return PromotionOptionsEntity.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(message: 'Failed to load promotion options');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<List<PromotionPackageEntity>> getPackages() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.promotionsPackages,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final raw = response.data;
        final list = raw is List ? raw : (raw is Map ? raw['data'] : null);
        if (list is List) {
          return list
              .whereType<Map>()
              .map(
                (e) => PromotionPackageEntity.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((p) => p.isActive)
              .toList();
        }
      }
      throw ServerException(message: 'Failed to load promotion packages');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<PromotionCampaignEntity> createCampaign(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.promotions,
        data: body,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PromotionCampaignEntity.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(message: 'Failed to create promotion');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<PromotionPayResultEntity> payCampaign(String campaignId) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.promotionPay(campaignId),
        options: Options(headers: await _authHeaders()),
      );
      final code = response.statusCode;
      if (code == 200 || code == 201) {
        final data = response.data;
        if (data is Map) {
          return PromotionPayResultEntity.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
      }
      throw ServerException(message: 'Payment failed');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<PromotedPostsPageEntity> getPromotedPosts({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
      };
      final response = await apiClient.dio.get(
        ApiConstants.promotionsPosts,
        queryParameters: query,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return PromotedPostsPageEntity.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
      }
      throw ServerException(message: 'Failed to load promoted posts');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<PromotedPostStatsEntity> getPromotedPostStats(
    String postId, {
    String? campaignId,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.promotionPostStats(postId),
        queryParameters: {
          if (campaignId != null && campaignId.isNotEmpty)
            'campaignId': campaignId,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return PromotedPostStatsEntity.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
      }
      throw ServerException(message: 'Failed to load promotion stats');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<PromotedPostRowEntity> getPromotedPost(String postId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.promotionPostById(postId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return PromotedPostRowEntity.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
      }
      throw ServerException(message: 'Failed to load promoted post');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<CampaignStatsEntity> getCampaignStats(String campaignId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.promotionStats(campaignId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return CampaignStatsEntity.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
      }
      throw ServerException(message: 'Failed to load campaign stats');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<PromotionCampaignSummaryEntity> pauseCampaign(String campaignId) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.promotionPause(campaignId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return PromotionCampaignSummaryEntity.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
      }
      throw ServerException(message: 'Failed to pause campaign');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<PromotionCampaignSummaryEntity> resumeCampaign(
    String campaignId,
  ) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.promotionResume(campaignId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return PromotionCampaignSummaryEntity.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
      }
      throw ServerException(message: 'Failed to resume campaign');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }
}
