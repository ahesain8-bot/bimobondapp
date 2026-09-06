import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_endpoints.dart';
import 'api_exceptions.dart';

typedef IdTokenProvider = Future<String?> Function();

class LiveApiClient {
  LiveApiClient({
    http.Client? httpClient,
    this.idTokenProvider,
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  IdTokenProvider? idTokenProvider;

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth && idTokenProvider != null) {
      final token = await idTokenProvider!();
      final hasToken = token != null && token.isNotEmpty;
      if (hasToken) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    bool auth = true,
    Map<String, String>? query,
  }) async {
    var uri = ApiEndpoints.uri(path);
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final headers = await _headers(auth: auth);
    final response = await _http.get(uri, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    bool auth = true,
    dynamic body,
  }) async {
    final uri = ApiEndpoints.uri(path);
    final headers = await _headers(auth: auth);
    final response = await _http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    bool auth = true,
    dynamic body,
  }) async {
    final uri = ApiEndpoints.uri(path);
    final headers = await _headers(auth: auth);
    final response = await _http.patch(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    bool auth = true,
    dynamic body,
  }) async {
    final uri = ApiEndpoints.uri(path);
    final headers = await _headers(auth: auth);
    final response = await _http.put(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = true,
  }) async {
    final uri = ApiEndpoints.uri(path);
    final headers = await _headers(auth: auth);
    final response = await _http.delete(uri, headers: headers);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{'data': decoded};
    }

    final message = decoded is Map && decoded['message'] != null
        ? (decoded['message'] is List
            ? (decoded['message'] as List).join(', ')
          : decoded['message'].toString())
        : 'Request failed with status ${response.statusCode}';

    switch (response.statusCode) {
      case 400:
        throw BadRequestException(message, statusCode: 400, details: decoded);
      case 401:
      case 403:
        throw UnauthorizedException(message, statusCode: response.statusCode, details: decoded);
      case 404:
        throw NotFoundException(message, statusCode: 404, details: decoded);
      case 429:
        throw ApiException(
          message.isNotEmpty ? message : 'Too many requests. Please wait a moment.',
          statusCode: 429,
          details: decoded,
        );
      case 503:
        throw ServiceUnavailableException(message, statusCode: 503, details: decoded);
      default:
        throw ApiException(message, statusCode: response.statusCode, details: decoded);
    }
  }
}
