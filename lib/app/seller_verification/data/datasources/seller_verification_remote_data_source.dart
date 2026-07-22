import 'dart:io';

import 'package:bimobondapp/app/seller_verification/domain/entities/seller_verification_entities.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class SellerVerificationRemoteDataSource {
  Future<SellerVerificationStatusEntity> getEligibility();
  Future<SellerVerificationStatusEntity> getMe();
  Future<String> uploadDocument(File file);
  Future<SellerVerificationStatusEntity> submit(
    SubmitSellerVerificationInput input,
  );
}

class SellerVerificationRemoteDataSourceImpl
    implements SellerVerificationRemoteDataSource {
  SellerVerificationRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw ServerException(message: 'User not authenticated');
    }
    final idToken = await user.getIdToken();
    return {'Authorization': 'Bearer $idToken'};
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

  @override
  Future<SellerVerificationStatusEntity> getEligibility() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.sellerVerificationEligibility,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return SellerVerificationStatusEntity.fromJson(_asMap(response.data));
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
  Future<SellerVerificationStatusEntity> getMe() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.sellerVerificationMe,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return SellerVerificationStatusEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ??
            'Failed to load seller verification',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<String> uploadDocument(File file) async {
    try {
      final fileName = file.path.split(RegExp(r'[\\/]')).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });
      final response = await apiClient.dio.post(
        ApiConstants.sellerVerificationUpload,
        data: formData,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final map = _asMap(response.data);
        final key = map['fileKey']?.toString() ?? map['key']?.toString();
        if (key != null && key.isNotEmpty) return key;
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to upload document',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<SellerVerificationStatusEntity> submit(
    SubmitSellerVerificationInput input,
  ) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.sellerVerification,
        data: input.toJson(),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return SellerVerificationStatusEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ??
            'Failed to submit seller verification',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
