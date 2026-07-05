import 'package:bimobondapp/app/auctions/data/models/auction_details_model.dart';
import 'package:bimobondapp/app/auctions/data/models/auction_pricing_preview_model.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuctionsRemoteDataSource {
  Future<AuctionDetailsModel> getAuctionDetails(String auctionId);
  Future<AuctionPricingPreviewModel> getPricingPreview({
    required int targetCoins,
    double startingPrice = 0,
  });
}

class AuctionsRemoteDataSourceImpl implements AuctionsRemoteDataSource {
  AuctionsRemoteDataSourceImpl({required this.apiClient});

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

  @override
  Future<AuctionDetailsModel> getAuctionDetails(String auctionId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.auctionById(auctionId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map<String, dynamic>) {
          return AuctionDetailsModel.fromJson(body);
        }
        if (body is Map) {
          return AuctionDetailsModel.fromJson(
            Map<String, dynamic>.from(body),
          );
        }
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load auction',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<AuctionPricingPreviewModel> getPricingPreview({
    required int targetCoins,
    double startingPrice = 0,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.auctionsPricingPreview,
        queryParameters: {
          'targetCoins': targetCoins,
          if (startingPrice > 0) 'startingPrice': startingPrice,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map<String, dynamic>) {
          return AuctionPricingPreviewModel.fromJson(body);
        }
        if (body is Map) {
          return AuctionPricingPreviewModel.fromJson(
            Map<String, dynamic>.from(body),
          );
        }
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ??
            'Failed to load pricing preview',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
