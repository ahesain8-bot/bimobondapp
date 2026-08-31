import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Compact, safe HTTP traces for debug builds.
///
/// It intentionally logs bounded, redacted previews instead of handing large
/// response bodies to logcat. That keeps the console useful like Postman
/// without making a live room slower merely because diagnostics are enabled.
class NetworkConsole {
  NetworkConsole._();

  static const _maxMapEntries = 16;
  static const _maxListEntries = 10;
  static const _maxDepth = 3;
  static const _maxStringLength = 480;
  static int _nextId = 0;

  static NetworkRequestTrace start({
    required String method,
    required Uri uri,
    Map<String, dynamic>? headers,
    Object? body,
  }) {
    if (!kDebugMode) {
      return NetworkRequestTrace._(0, '', '', Stopwatch());
    }
    final stopwatch = Stopwatch();
    stopwatch.start();
    final trace = NetworkRequestTrace._(
      ++_nextId,
      method.toUpperCase(),
      _safeUri(uri),
      stopwatch,
    );
    _write(
      '[HTTP #${trace.id} →] ${trace.method} ${trace.uri}\n'
      '  headers: ${_previewHeaders(headers)}\n'
      '  body: ${_preview(body)}',
    );
    return trace;
  }

  static void complete(
    NetworkRequestTrace trace, {
    required int statusCode,
    Map<String, dynamic>? headers,
    Object? body,
  }) {
    if (!kDebugMode) return;
    trace.stopwatch.stop();
    _write(
      '[HTTP #${trace.id} ←] $statusCode ${trace.stopwatch.elapsedMilliseconds}ms '
      '${trace.method} ${trace.uri}\n'
      '  headers: ${_previewHeaders(headers)}\n'
      '  body: ${_preview(body)}',
    );
  }

  static void failure(
    NetworkRequestTrace trace, {
    required Object error,
    int? statusCode,
    Map<String, dynamic>? headers,
    Object? body,
  }) {
    if (!kDebugMode) return;
    trace.stopwatch.stop();
    final status = statusCode == null ? '' : ' $statusCode';
    _write(
      '[HTTP #${trace.id} ✕]$status ${trace.stopwatch.elapsedMilliseconds}ms '
      '${trace.method} ${trace.uri}\n'
      '  error: ${_safeError(error)}\n'
      '  headers: ${_previewHeaders(headers)}\n'
      '  body: ${_preview(body)}',
    );
  }

  static String _safeUri(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri.toString();
    final query = <String, String>{
      for (final entry in uri.queryParameters.entries)
        entry.key: _isSensitiveKey(entry.key) ? '***' : entry.value,
    };
    return uri.replace(queryParameters: query).toString();
  }

  static Object? _previewHeaders(Map<String, dynamic>? headers) {
    if (headers == null || headers.isEmpty) return const <String, Object?>{};
    return <String, Object?>{
      for (final entry in headers.entries)
        entry.key: _isSensitiveKey(entry.key)
            ? '***'
            : _boundedValue(entry.value, 0),
    };
  }

  static String _preview(Object? value) {
    try {
      return jsonEncode(_boundedValue(value, 0));
    } catch (_) {
      return '"<${value?.runtimeType ?? 'null'}>"';
    }
  }

  static Object? _boundedValue(Object? value, int depth, {String? key}) {
    if (key != null && _isSensitiveKey(key)) return '***';
    if (value == null || value is num || value is bool) return value;
    if (depth >= _maxDepth) return '<${value.runtimeType}>';

    if (value is String) {
      final trimmed = value.trim();
      if (_looksLikeJson(trimmed) && trimmed.length <= 32 * 1024) {
        try {
          return _boundedValue(jsonDecode(trimmed), depth + 1);
        } catch (_) {
          // A malformed JSON response is still safe to report as text below.
        }
      }
      // Plain text is not structured enough to redact reliably. Report its
      // size rather than risking a token or a user's private message in logs.
      return '<text ${trimmed.length} chars>';
    }
    if (value is Map) {
      final preview = <String, Object?>{};
      var count = 0;
      for (final entry in value.entries) {
        if (count++ >= _maxMapEntries) {
          preview['…'] = '<${value.length - _maxMapEntries} more fields>';
          break;
        }
        final key = entry.key.toString();
        preview[key] = _boundedValue(entry.value, depth + 1, key: key);
      }
      return preview;
    }
    if (value is Iterable) {
      final preview = <Object?>[];
      var count = 0;
      for (final item in value) {
        if (count++ >= _maxListEntries) {
          preview.add('<more items>');
          break;
        }
        preview.add(_boundedValue(item, depth + 1));
      }
      return preview;
    }
    if (value is FormData) {
      return <String, Object?>{
        'fields': _boundedValue(<String, Object?>{
          for (final field in value.fields) field.key: field.value,
        }, depth + 1),
        'files': '<${value.files.length} multipart file(s)>',
      };
    }
    return '<${value.runtimeType}>';
  }

  static bool _looksLikeJson(String value) =>
      value.startsWith('{') || value.startsWith('[');

  static String _shortText(String value) {
    if (value.length <= _maxStringLength) return value;
    return '${value.substring(0, _maxStringLength)}… '
        '(${value.length} chars total)';
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll('_', '-');
    return normalized == 'authorization' ||
        normalized == 'auth' ||
        normalized == 'cookie' ||
        normalized == 'set-cookie' ||
        normalized == 'x-api-key' ||
        normalized == 'api-key' ||
        normalized == 'apikey' ||
        normalized == 'device-token' ||
        normalized.contains('token') ||
        normalized.contains('password') ||
        normalized.contains('secret') ||
        normalized.contains('credential');
  }

  static String _safeError(Object error) =>
      _redactLooseSecrets(_shortText(error.toString()));

  static String _redactLooseSecrets(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'Bearer\s+[^\s,]+', caseSensitive: false),
          (_) => 'Bearer ***',
        )
        .replaceAllMapped(
          RegExp(
            r'(token|password|secret|credential|api[_-]?key)=([^&\s,]+)',
            caseSensitive: false,
          ),
          (match) => '${match.group(1)}=***',
        );
  }

  static void _write(String message) {
    // `debugPrint` chunks long messages and is compiled out of production
    // assertions; this code is additionally guarded by kDebugMode above.
    debugPrint(message);
  }
}

class NetworkRequestTrace {
  const NetworkRequestTrace._(this.id, this.method, this.uri, this.stopwatch);

  final int id;
  final String method;
  final String uri;
  final Stopwatch stopwatch;
}

/// Dio adapter for [NetworkConsole]. Keep it after the auth interceptor so
/// its (redacted) header report reflects the request that actually left Dio.
class NetworkConsoleInterceptor extends Interceptor {
  static const _traceExtraKey = 'network_console_trace';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.extra[_traceExtraKey] = NetworkConsole.start(
        method: options.method,
        uri: options.uri,
        headers: Map<String, dynamic>.from(options.headers),
        body: options.data,
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final trace =
        response.requestOptions.extra[_traceExtraKey] as NetworkRequestTrace?;
    if (trace != null) {
      NetworkConsole.complete(
        trace,
        statusCode: response.statusCode ?? 0,
        headers: _headers(response.headers),
        body: response.data,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final trace =
        err.requestOptions.extra[_traceExtraKey] as NetworkRequestTrace?;
    if (trace != null) {
      NetworkConsole.failure(
        trace,
        error: err.message ?? err.type.name,
        statusCode: err.response?.statusCode,
        headers: err.response == null
            ? null
            : _headers(err.response!.headers),
        body: err.response?.data,
      );
    }
    handler.next(err);
  }

  static Map<String, dynamic> _headers(Headers headers) => <String, dynamic>{
    for (final entry in headers.map.entries) entry.key: entry.value.join(', '),
  };
}
