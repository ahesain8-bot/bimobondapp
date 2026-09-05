import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_endpoints.dart';
import 'api_exceptions.dart';

typedef IdTokenProvider = Future<String?> Function();

class LiveApiClient {
  LiveApiClient({
    http.Client? httpClient,
    this.idTokenProvider,
    this.timeout = _defaultTimeout,
  }) : _http = httpClient ?? http.Client();

  /// Deadline for a single JSON request.
  ///
  /// Every endpoint reached through this client is a small JSON call — joins,
  /// feeds, comments, moderation — and none of them legitimately take this
  /// long. Media uploads use a separate data source and are unaffected.
  /// Fifteen seconds is above the worst realistic mobile round trip and well
  /// below the point where a viewer concludes the app is broken.
  static const _defaultTimeout = Duration(seconds: 15);

  final http.Client _http;
  IdTokenProvider? idTokenProvider;
  final Duration timeout;

  /// Turns a stalled socket into an ordinary failure the caller can render.
  ///
  /// `TimeoutException` is deliberate: every repository already maps it to a
  /// user-facing network failure, so no call site needs to learn a new type.
  Future<http.Response> _send(
    Future<http.Response> Function() request,
    String description,
  ) {
    return request().timeout(
      timeout,
      onTimeout: () => throw TimeoutException(description, timeout),
    );
  }

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
    final response = await _send(
      () => _http.get(uri, headers: headers),
      'GET $path',
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    bool auth = true,
    dynamic body,
  }) async {
    final uri = ApiEndpoints.uri(path);
    final headers = await _headers(auth: auth);
    final response = await _send(
      () => _http.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      'POST $path',
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
    final response = await _send(
      () => _http.patch(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      'PATCH $path',
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
    final response = await _send(
      () => _http.put(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      'PUT $path',
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = true,
  }) async {
    final uri = ApiEndpoints.uri(path);
    final headers = await _headers(auth: auth);
    final response = await _send(
      () => _http.delete(uri, headers: headers),
      'DELETE $path',
    );
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
      case 503:
        throw ServiceUnavailableException(message, statusCode: 503, details: decoded);
      default:
        throw ApiException(message, statusCode: response.statusCode, details: decoded);
    }
  }
}
