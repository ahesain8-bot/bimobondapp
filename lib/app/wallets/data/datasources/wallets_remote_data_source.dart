import 'package:bimobondapp/app/wallets/data/models/wallet_model.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class WalletsRemoteDataSource {
  Future<WalletModel> getMyWallet();
  Future<List<CoinPackageModel>> getPackages();
  Future<CoinPurchaseResultModel> purchasePackage({
    required String packageId,
    required String provider,
    required String providerTxId,
  });
  Future<CoinPurchaseResultModel> topUp({
    required double paidPrice,
    required String provider,
    required String providerTxId,
    String currencyCode = 'USD',
  });
}

class WalletsRemoteDataSourceImpl implements WalletsRemoteDataSource {
  WalletsRemoteDataSourceImpl({required this.apiClient});

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
      final message = data['message'];
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
      return data['message']?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      final data = body['data'];
      if (data is List) return data;
      for (final key in ['packages', 'items']) {
        final nested = body[key];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  @override
  Future<WalletModel> getMyWallet() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.walletsMe,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map<String, dynamic>) {
          return WalletModel.fromJson(body);
        }
        if (body is Map) {
          return WalletModel.fromJson(Map<String, dynamic>.from(body));
        }
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load wallet',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<CoinPackageModel>> getPackages() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.walletsPackages);
      if (response.statusCode == 200) {
        return _extractList(response.data)
            .whereType<Map>()
            .map(
              (json) => CoinPackageModel.fromJson(
                Map<String, dynamic>.from(json),
              ),
            )
            .where((pack) => pack.id.isNotEmpty && pack.isActive)
            .toList();
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load packages',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<CoinPurchaseResultModel> purchasePackage({
    required String packageId,
    required String provider,
    required String providerTxId,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.walletsPurchase,
        data: {
          'packageId': packageId,
          'provider': provider,
          'providerTxId': providerTxId,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        if (body is Map<String, dynamic>) {
          return CoinPurchaseResultModel.fromJson(body);
        }
        if (body is Map) {
          return CoinPurchaseResultModel.fromJson(
            Map<String, dynamic>.from(body),
          );
        }
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to purchase coins',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<CoinPurchaseResultModel> topUp({
    required double paidPrice,
    required String provider,
    required String providerTxId,
    String currencyCode = 'USD',
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.walletsTopUp,
        data: {
          'paidPrice': paidPrice,
          'currencyCode': currencyCode,
          'provider': provider,
          'providerTxId': providerTxId,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        if (body is Map<String, dynamic>) {
          return CoinPurchaseResultModel.fromJson(body);
        }
        if (body is Map) {
          return CoinPurchaseResultModel.fromJson(
            Map<String, dynamic>.from(body),
          );
        }
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to top up wallet',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
