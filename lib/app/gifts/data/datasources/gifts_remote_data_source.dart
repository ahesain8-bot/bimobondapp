import 'package:bimobondapp/app/gifts/data/models/gift_model.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class GiftsRemoteDataSource {
  Future<List<GiftModel>> getGifts();
  Future<GiftInventoryModel> getInventory();
  Future<GiftInventoryModel> purchaseGift({
    required String giftId,
    int quantity = 1,
  });
  Future<GiftInventoryModel?> sendGift({
    required String giftId,
    int quantity = 1,
    String? postId,
    String? receiverId,
    String? auctionId,
  });
}

class GiftsRemoteDataSourceImpl implements GiftsRemoteDataSource {
  GiftsRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> _authHeaders() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final idToken = await firebaseUser.getIdToken();
      return {'Authorization': 'Bearer $idToken'};
    }
    return {};
  }

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      final data = body['data'];
      if (data is List) return data;
      if (data is Map) {
        for (final key in ['items', 'gifts', 'inventory']) {
          final nested = data[key];
          if (nested is List) return nested;
        }
        return [data];
      }
      for (final key in ['items', 'gifts']) {
        final nested = body[key];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      return data['message']?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  @override
  Future<List<GiftModel>> getGifts() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.gifts);
      if (response.statusCode == 200) {
        return _extractList(response.data)
            .whereType<Map>()
            .map(
              (json) => GiftModel.fromJson(Map<String, dynamic>.from(json)),
            )
            .where((gift) => gift.id.isNotEmpty)
            .toList();
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load gifts',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  GiftInventoryModel _parseInventoryResponse(dynamic body) {
    if (body is List) {
      return GiftInventoryModel.fromApiResponse({'inventory': body});
    }
    if (body is Map<String, dynamic>) {
      return GiftInventoryModel.fromApiResponse(body);
    }
    throw ServerException(message: 'Invalid inventory response');
  }

  GiftInventoryModel _overlayOffset(GiftInventoryModel inventory) {
    final purchasedOffset = apiClient.sharedPreferences.getInt('MOCK_COIN_PURCHASED_OFFSET') ?? 0;
    if (purchasedOffset > 0) {
      return GiftInventoryModel(
        coinBalance: inventory.coinBalance + purchasedOffset,
        items: inventory.items,
      );
    }
    return inventory;
  }

  @override
  Future<GiftInventoryModel> getInventory() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.giftsInventory,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return _overlayOffset(_parseInventoryResponse(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load inventory',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<GiftInventoryModel> purchaseGift({
    required String giftId,
    int quantity = 1,
  }) async {
    try {
      final purchaseData = <String, dynamic>{'giftId': giftId};
      if (quantity > 1) {
        purchaseData['quantity'] = quantity;
      }

      final response = await apiClient.dio.post(
        ApiConstants.giftsPurchase,
        data: purchaseData,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        if (body is Map<String, dynamic>) {
          return _overlayOffset(GiftInventoryModel.fromApiResponse(body));
        }
        if (body is Map) {
          return _overlayOffset(GiftInventoryModel.fromApiResponse(
            Map<String, dynamic>.from(body),
          ));
        }
        return getInventory();
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to purchase gift',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<GiftInventoryModel?> sendGift({
    required String giftId,
    int quantity = 1,
    String? postId,
    String? receiverId,
    String? auctionId,
  }) async {
    try {
      final data = <String, dynamic>{'giftId': giftId};
      if (quantity > 1) {
        data['quantity'] = quantity;
      }
      if (postId != null && postId.isNotEmpty) {
        data['postId'] = postId;
      }
      if (receiverId != null && receiverId.isNotEmpty) {
        data['receiverId'] = receiverId;
      }
      if (auctionId != null && auctionId.isNotEmpty) {
        data['auctionId'] = auctionId;
      }

      final response = await apiClient.dio.post(
        ApiConstants.giftsSend,
        data: data,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        if (body is Map<String, dynamic>) {
          return _overlayOffset(GiftInventoryModel.fromApiResponse(body));
        }
        if (body is Map) {
          return _overlayOffset(GiftInventoryModel.fromApiResponse(
            Map<String, dynamic>.from(body),
          ));
        }
        return null;
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to send gift',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
