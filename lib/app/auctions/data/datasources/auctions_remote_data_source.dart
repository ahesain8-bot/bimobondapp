import 'package:bimobondapp/app/auctions/data/models/auction_details_model.dart';
import 'package:bimobondapp/app/auctions/data/models/auction_pricing_preview_model.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_fulfillment_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/auction_seller_eligibility_entity.dart';
import 'package:bimobondapp/app/auctions/domain/entities/create_auction_input.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuctionsRemoteDataSource {
  Future<AuctionDetailsModel> getAuctionDetails(String auctionId);
  Future<List<AuctionDetailsModel>> getActiveAuctions();
  Future<AuctionPricingPreviewModel> getPricingPreview({
    int? targetCoins,
    double? targetPrice,
  });
  Future<AuctionSellerEligibilityEntity> getSellerEligibility();
  Future<AuctionDetailsModel> createAuction(CreateAuctionInput input);
  Future<AuctionDetailsModel> updateAuction(
    String auctionId,
    Map<String, dynamic> data,
  );
  Future<AuctionDetailsModel> cancelAuction(String auctionId);
  Future<({List<AuctionDetailsModel> auctions, int total, int page, int lastPage})>
      getMyAuctions({
    String type = 'all',
    int page = 1,
    int limit = 10,
  });
  Future<AuctionFulfillmentEntity> getFulfillment(String auctionId);
  Future<AuctionFulfillmentEntity> shipFulfillment(
    String auctionId, {
    String? trackingNumber,
    String? shippingNote,
  });
  Future<AuctionFulfillmentEntity> receiveFulfillment(String auctionId);
  Future<AuctionFulfillmentEntity> acceptFulfillment(String auctionId);
  Future<AuctionFulfillmentEntity> disputeFulfillment(
    String auctionId, {
    String? reason,
  });
}

class AuctionsRemoteDataSourceImpl implements AuctionsRemoteDataSource {
  AuctionsRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> _authHeaders({bool required = false}) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final idToken = await firebaseUser.getIdToken();
      return {'Authorization': 'Bearer $idToken'};
    }
    if (required) {
      throw ServerException(message: 'User not authenticated');
    }
    return {};
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'];
      if (message is List && message.isNotEmpty) {
        return message.map((e) => e.toString()).join(', ');
      }
      return message?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    throw ServerException(message: 'Unexpected response shape');
  }

  List<AuctionDetailsModel> _parseAuctionList(dynamic body) {
    final map = body is Map ? _asMap(body) : null;
    final raw = map?['auctions'] ?? map?['data'] ?? body;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => AuctionDetailsModel.fromJson(Map<String, dynamic>.from(e)))
        .where((a) => a.id.isNotEmpty)
        .toList();
  }

  @override
  Future<AuctionDetailsModel> getAuctionDetails(String auctionId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.auctionById(auctionId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return AuctionDetailsModel.fromJson(_asMap(response.data));
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
  Future<List<AuctionDetailsModel>> getActiveAuctions() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.auctionsActive,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return _parseAuctionList(response.data);
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ??
            'Failed to load active auctions',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<AuctionPricingPreviewModel> getPricingPreview({
    int? targetCoins,
    double? targetPrice,
  }) async {
    final hasCoins = targetCoins != null && targetCoins >= 1;
    final hasPrice = targetPrice != null && targetPrice >= 0.01;
    if (hasCoins == hasPrice) {
      throw ServerException(
        message: 'Provide exactly one of targetCoins or targetPrice',
      );
    }

    try {
      final response = await apiClient.dio.get(
        ApiConstants.auctionsPricingPreview,
        queryParameters: {
          if (hasCoins) 'targetCoins': targetCoins,
          if (hasPrice) 'targetPrice': targetPrice,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return AuctionPricingPreviewModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ??
            'Failed to load pricing preview',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<AuctionSellerEligibilityEntity> getSellerEligibility() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.auctionsSellerEligibility,
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return AuctionSellerEligibilityEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ??
            'Failed to check seller eligibility',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<AuctionDetailsModel> createAuction(CreateAuctionInput input) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.auctions,
        data: input.toJson(),
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuctionDetailsModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to create auction',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<AuctionDetailsModel> updateAuction(
    String auctionId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.auctionById(auctionId),
        data: data,
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return AuctionDetailsModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to update auction',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<AuctionDetailsModel> cancelAuction(String auctionId) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.auctionCancel(auctionId),
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return AuctionDetailsModel.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to cancel auction',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<
      ({
        List<AuctionDetailsModel> auctions,
        int total,
        int page,
        int lastPage
      })> getMyAuctions({
    String type = 'all',
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.myAuctions,
        queryParameters: {
          'type': type,
          'page': page,
          'limit': limit,
        },
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        final map = _asMap(response.data);
        final auctions = _parseAuctionList(map);
        final meta = map['meta'] is Map
            ? Map<String, dynamic>.from(map['meta'] as Map)
            : const <String, dynamic>{};
        return (
          auctions: auctions,
          total: (meta['total'] is num) ? (meta['total'] as num).toInt() : auctions.length,
          page: (meta['page'] is num) ? (meta['page'] as num).toInt() : page,
          lastPage: (meta['lastPage'] is num)
              ? (meta['lastPage'] as num).toInt()
              : 1,
        );
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load my auctions',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<AuctionFulfillmentEntity> getFulfillment(String auctionId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.auctionFulfillment(auctionId),
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return AuctionFulfillmentEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ??
            'Failed to load fulfillment',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<AuctionFulfillmentEntity> shipFulfillment(
    String auctionId, {
    String? trackingNumber,
    String? shippingNote,
  }) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.auctionFulfillmentShip(auctionId),
        data: {
          if (trackingNumber != null && trackingNumber.isNotEmpty)
            'trackingNumber': trackingNumber,
          if (shippingNote != null && shippingNote.isNotEmpty)
            'shippingNote': shippingNote,
        },
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return AuctionFulfillmentEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to mark shipped',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<AuctionFulfillmentEntity> receiveFulfillment(String auctionId) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.auctionFulfillmentReceive(auctionId),
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return AuctionFulfillmentEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to confirm receipt',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<AuctionFulfillmentEntity> acceptFulfillment(String auctionId) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.auctionFulfillmentAccept(auctionId),
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return AuctionFulfillmentEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to accept fulfillment',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<AuctionFulfillmentEntity> disputeFulfillment(
    String auctionId, {
    String? reason,
  }) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.auctionFulfillmentDispute(auctionId),
        data: {
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
        options: Options(headers: await _authHeaders(required: true)),
      );
      if (response.statusCode == 200) {
        return AuctionFulfillmentEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to open dispute',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
