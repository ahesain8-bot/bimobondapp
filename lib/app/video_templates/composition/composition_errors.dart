/// User-facing composition errors (Phase 18). Technical detail stays in logs.
class CompositionException implements Exception {
  CompositionException(
    this.userMessage, {
    this.technicalDetail,
    this.code = CompositionErrorCode.unknown,
  });

  final String userMessage;
  final String? technicalDetail;
  final CompositionErrorCode code;

  @override
  String toString() =>
      'CompositionException($code): $userMessage'
      '${technicalDetail != null ? ' — $technicalDetail' : ''}';
}

enum CompositionErrorCode {
  unknown,
  invalidTemplate,
  missingMedia,
  unsupportedMedia,
  corruptMedia,
  decodeFailed,
  encodeFailed,
  lowStorage,
  network,
  assetMissing,
  cancelled,
}

/// Soft result wrapper — never throw across UI boundaries.
class CompositionResult<T> {
  const CompositionResult._({this.value, this.error});

  const CompositionResult.ok(T value) : this._(value: value);

  const CompositionResult.fail(CompositionException error)
      : this._(error: error);

  final T? value;
  final CompositionException? error;

  bool get isOk => error == null && value != null;

  R fold<R>(
    R Function(CompositionException e) onError,
    R Function(T v) onOk,
  ) {
    if (error != null) return onError(error!);
    return onOk(value as T);
  }
}
