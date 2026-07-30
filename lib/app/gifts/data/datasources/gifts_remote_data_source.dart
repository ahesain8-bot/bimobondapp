import 'package:bimobondapp/app/gifts/data/models/gift_group_model.dart';
import 'package:bimobondapp/app/gifts/data/models/gift_model.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class GiftsRemoteDataSource {
  Future<List<GiftGroupModel>> getGiftGroups();
  Future<List<GiftModel>> getGifts({String? groupId, String? groupSlug});
  Future<GiftInventoryModel> getInventory();
  Future<GiftInventoryModel> purchaseGift({
    required String giftId,
    int quantity = 1,
  });
  Future<GiftInventoryModel?> sendGift({
    required String giftId,
    required String receiverId,
    String? postId,
    String? auctionId,
    String? liveId,
    String? message,
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
      for (final key in ['groups', 'items', 'gifts']) {
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

  List<GiftModel> _mapGiftList(List<dynamic> list) {
    return list
        .whereType<Map>()
        .map((json) => Map<String, dynamic>.from(json))
        .where((json) {
          final isActive = json['isActive'];
          return isActive == null || isActive == true;
        })
        .map(GiftModel.fromJson)
        .where((gift) => gift.id.isNotEmpty)
        .toList();
  }

  @override
  Future<List<GiftGroupModel>> getGiftGroups() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.giftsGroups);
      if (response.statusCode == 200) {
        return _extractList(response.data)
            .whereType<Map>()
            .map((json) => GiftGroupModel.fromJson(Map<String, dynamic>.from(json)))
            .where((group) => group.id.isNotEmpty)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load gift groups',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<GiftModel>> getGifts({String? groupId, String? groupSlug}) async {
    try {
      final query = <String, dynamic>{};
      if (groupId != null && groupId.isNotEmpty) {
        query['groupId'] = groupId;
      } else if (groupSlug != null && groupSlug.isNotEmpty) {
        query['groupSlug'] = groupSlug;
      }

      final response = await apiClient.dio.get(
        ApiConstants.gifts,
        queryParameters: query.isEmpty ? null : query,
      );
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map && body['data'] is List) {
          return _mapGiftList(body['data'] as List);
        }
        return _mapGiftList(_extractList(body));
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
    if (body is Map) {
      return GiftInventoryModel.fromApiResponse(
        Map<String, dynamic>.from(body),
      );
    }
    throw ServerException(message: 'Invalid inventory response');
  }

  @override
  Future<GiftInventoryModel> getInventory() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.giftsInventory,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return _parseInventoryResponse(response.data);
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
          return GiftInventoryModel.fromApiResponse(body);
        }
        if (body is Map) {
          return GiftInventoryModel.fromApiResponse(
            Map<String, dynamic>.from(body),
          );
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
    required String receiverId,
    String? postId,
    String? auctionId,
    String? liveId,
    String? message,
  }) async {
    try {
      final data = <String, dynamic>{
        'giftId': giftId,
        'receiverId': receiverId,
      };
      if (postId != null && postId.isNotEmpty) {
        data['postId'] = postId;
      }
      if (auctionId != null && auctionId.isNotEmpty) {
        data['auctionId'] = auctionId;
      }
      if (liveId != null && liveId.isNotEmpty) {
        data['liveId'] = liveId;
      }
      if (message != null && message.trim().isNotEmpty) {
        data['message'] = message.trim();
      }

      final response = await apiClient.dio.post(
        ApiConstants.giftsSend,
        data: data,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        if (body is Map<String, dynamic>) {
          return GiftInventoryModel.fromSendResponse(body);
        }
        if (body is Map) {
          return GiftInventoryModel.fromSendResponse(
            Map<String, dynamic>.from(body),
          );
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
