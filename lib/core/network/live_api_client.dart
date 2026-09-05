import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_endpoints.dart';
import 'api_exceptions.dart';
import 'network_console.dart';

typedef IdTokenProvider = Future<String?> Function();

class LiveApiClient {
  LiveApiClient({http.Client? httpClient, this.idTokenProvider})
    : _http = httpClient ?? http.Client();

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
    return _send(
      method: 'GET',
      uri: uri,
      headers: headers,
      request: () => _http.get(uri, headers: headers),
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    bool auth = true,
    dynamic body,
  }) async {
    final uri = ApiEndpoints.uri(path);
    final headers = await _headers(auth: auth);
    final encodedBody = body != null ? jsonEncode(body) : null;
    return _send(
      method: 'POST',
      uri: uri,
      headers: headers,
      body: body,
      request: () => _http.post(uri, headers: headers, body: encodedBody),
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    bool auth = true,
    dynamic body,
  }) async {
    final uri = ApiEndpoints.uri(path);
    final headers = await _headers(auth: auth);
    final encodedBody = body != null ? jsonEncode(body) : null;
    return _send(
      method: 'PATCH',
      uri: uri,
      headers: headers,
      body: body,
      request: () => _http.patch(uri, headers: headers, body: encodedBody),
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    bool auth = true,
    dynamic body,
  }) async {
    final uri = ApiEndpoints.uri(path);
    final headers = await _headers(auth: auth);
    final encodedBody = body != null ? jsonEncode(body) : null;
    return _send(
      method: 'PUT',
      uri: uri,
      headers: headers,
      body: body,
      request: () => _http.put(uri, headers: headers, body: encodedBody),
    );
  }

  Future<Map<String, dynamic>> delete(String path, {bool auth = true}) async {
    final uri = ApiEndpoints.uri(path);
    final headers = await _headers(auth: auth);
    return _send(
      method: 'DELETE',
      uri: uri,
      headers: headers,
      request: () => _http.delete(uri, headers: headers),
    );
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Future<http.Response> Function() request,
    Object? body,
  }) async {
    final trace = NetworkConsole.start(
      method: method,
      uri: uri,
      headers: Map<String, dynamic>.from(headers),
      body: body,
    );
    var responseLogged = false;
    try {
      final response = await request();
      final decoded = _decodeResponse(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        NetworkConsole.complete(
          trace,
          statusCode: response.statusCode,
          headers: Map<String, dynamic>.from(response.headers),
          body: decoded,
        );
      } else {
        NetworkConsole.failure(
          trace,
          error: 'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          headers: Map<String, dynamic>.from(response.headers),
          body: decoded,
        );
      }
      responseLogged = true;
      return _handleResponse(response, decoded);
    } catch (error) {
      if (!responseLogged) {
        NetworkConsole.failure(trace, error: error);
      }
      rethrow;
    }
  }

  dynamic _decodeResponse(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }
    return decoded;
  }

  Map<String, dynamic> _handleResponse(
    http.Response response,
    dynamic decoded,
  ) {
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
        throw UnauthorizedException(
          message,
          statusCode: response.statusCode,
          details: decoded,
        );
      case 404:
        throw NotFoundException(message, statusCode: 404, details: decoded);
      case 429:
        throw ApiException(
          message.isNotEmpty ? message : 'Too many requests. Please wait a moment.',
          statusCode: 429,
          details: decoded,
        );
      case 503:
        throw ServiceUnavailableException(
          message,
          statusCode: 503,
          details: decoded,
        );
      default:
        throw ApiException(
          message,
          statusCode: response.statusCode,
          details: decoded,
        );
    }
  }
}
