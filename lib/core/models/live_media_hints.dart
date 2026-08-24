/// Server-provided recommendations for a LiveKit connection.
///
/// The backend recalculates these values for every role change, so callers
/// must map them from the latest start/join/guest-token response rather than
/// carrying them between rooms.
class LiveMediaHints {
  const LiveMediaHints({
    required this.role,
    required this.canPublish,
    required this.adaptiveStream,
    required this.dynacast,
    required this.simulcast,
    required this.maxVideoResolution,
    required this.maxBitrateKbps,
    required this.maxSubscribeResolution,
    required this.codecPreference,
  });

  final String role;
  final bool canPublish;
  final bool adaptiveStream;
  final bool dynacast;
  final bool simulcast;
  final String maxVideoResolution;
  final int maxBitrateKbps;
  final String maxSubscribeResolution;
  final List<String> codecPreference;

  bool get isPublisher => canPublish;

  String get preferredCodec {
    for (final codec in codecPreference) {
      final value = codec.toLowerCase();
      if (value == 'h264' || value == 'vp8') return value;
    }
    return 'h264';
  }

  int get subscribeWidth => switch (maxSubscribeResolution.toLowerCase()) {
    '1080p' => 1920,
    '720p' => 1280,
    '480p' => 854,
    '360p' => 640,
    _ => 1280,
  };

  int get subscribeHeight => switch (maxSubscribeResolution.toLowerCase()) {
    '1080p' => 1080,
    '720p' => 720,
    '480p' => 480,
    '360p' => 360,
    _ => 720,
  };

  factory LiveMediaHints.fromPayload(
    Map<String, dynamic> payload, {
    String? fallbackRole,
  }) {
    final nestedData = _map(payload['data']);
    final source = nestedData ?? payload;
    final raw = _map(source['mediaHints']) ?? _map(payload['mediaHints']);
    final role = (source['role'] ?? payload['role'] ?? fallbackRole ?? 'viewer')
        .toString()
        .toLowerCase();
    final publishingRole =
        role == 'host' || role == 'guest' || role == 'co_host';

    final defaults = LiveMediaHints.defaultsForRole(role);
    if (raw == null) return defaults;

    final codecs = raw['codecPreference'];
    return LiveMediaHints(
      role: role,
      canPublish: _bool(raw['canPublish']) ?? publishingRole,
      adaptiveStream: _bool(raw['adaptiveStream']) ?? true,
      dynacast: _bool(raw['dynacast']) ?? defaults.dynacast,
      simulcast: _bool(raw['simulcast']) ?? true,
      maxVideoResolution:
          raw['maxVideoResolution']?.toString() ?? defaults.maxVideoResolution,
      maxBitrateKbps: _int(raw['maxBitrateKbps']) ?? defaults.maxBitrateKbps,
      maxSubscribeResolution:
          raw['maxSubscribeResolution']?.toString() ??
          defaults.maxSubscribeResolution,
      codecPreference: codecs is List
          ? codecs
                .map((value) => value.toString().toLowerCase())
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : defaults.codecPreference,
    );
  }

  factory LiveMediaHints.defaultsForRole(String value) {
    final role = value.toLowerCase();
    switch (role) {
      case 'host':
        return const LiveMediaHints(
          role: 'host',
          canPublish: true,
          adaptiveStream: true,
          dynacast: true,
          simulcast: true,
          maxVideoResolution: '1080p',
          maxBitrateKbps: 4500,
          maxSubscribeResolution: '720p',
          codecPreference: ['h264', 'vp8'],
        );
      case 'co_host':
        return const LiveMediaHints(
          role: 'co_host',
          canPublish: true,
          adaptiveStream: true,
          dynacast: true,
          simulcast: true,
          maxVideoResolution: '480p',
          maxBitrateKbps: 1500,
          maxSubscribeResolution: '720p',
          codecPreference: ['h264', 'vp8'],
        );
      case 'guest':
        return const LiveMediaHints(
          role: 'guest',
          canPublish: true,
          adaptiveStream: true,
          dynacast: true,
          simulcast: true,
          maxVideoResolution: '480p',
          maxBitrateKbps: 1200,
          maxSubscribeResolution: '720p',
          codecPreference: ['h264', 'vp8'],
        );
      default:
        return const LiveMediaHints(
          role: 'viewer',
          canPublish: false,
          adaptiveStream: true,
          dynacast: true,
          simulcast: true,
          maxVideoResolution: '0p',
          maxBitrateKbps: 0,
          maxSubscribeResolution: '720p',
          codecPreference: ['h264', 'vp8'],
        );
    }
  }

  static Map<String, dynamic>? _map(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool? _bool(dynamic value) {
    if (value is bool) return value;
    if (value == null) return null;
    final normalized = value.toString().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }
}
