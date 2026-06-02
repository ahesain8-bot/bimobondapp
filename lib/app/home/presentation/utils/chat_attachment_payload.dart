import 'dart:convert';

class ChatAttachmentDraft {
  const ChatAttachmentDraft({
    required this.type,
    required this.content,
    this.filePath,
  });

  final String type;
  final String content;
  final String? filePath;
}

class ChatLocationPayload {
  const ChatLocationPayload({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;
  final String? label;

  String toJsonString() {
    return jsonEncode({
      'lat': latitude,
      'lng': longitude,
      if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
    });
  }

  static ChatLocationPayload? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final lat = _toDouble(decoded['lat'] ?? decoded['latitude']);
      final lng = _toDouble(decoded['lng'] ?? decoded['longitude']);
      if (lat == null || lng == null) return null;
      final label = (decoded['label'] ?? decoded['address'])?.toString();
      return ChatLocationPayload(
        latitude: lat,
        longitude: lng,
        label: label,
      );
    } catch (_) {
      return null;
    }
  }

  String get displayLabel {
    if (label != null && label!.trim().isNotEmpty) return label!.trim();
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  String get mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
}

class ChatContactPayload {
  const ChatContactPayload({
    required this.name,
    required this.phone,
  });

  final String name;
  final String phone;

  String toJsonString() {
    return jsonEncode({
      'name': name,
      'phone': phone,
    });
  }

  static ChatContactPayload? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final name = (decoded['name'] ?? decoded['displayName'])?.toString();
      final phone = (decoded['phone'] ??
              decoded['phoneNumber'] ??
              decoded['mobile'])
          ?.toString();
      if (name == null || name.trim().isEmpty) return null;
      if (phone == null || phone.trim().isEmpty) return null;
      return ChatContactPayload(name: name.trim(), phone: phone.trim());
    } catch (_) {
      return null;
    }
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
