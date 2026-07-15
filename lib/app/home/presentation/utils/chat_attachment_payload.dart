import 'dart:convert';

import 'package:bimobondapp/core/utils/media_utils.dart';

class ChatAttachmentDraft {
  const ChatAttachmentDraft({
    required this.type,
    this.content = '',
    this.filePath,
    this.payload,
    this.mimeType,
    this.sizeBytes,
  });

  final String type;
  final String content;
  final String? filePath;
  final Map<String, dynamic>? payload;
  final String? mimeType;
  final int? sizeBytes;
}

class ChatLocationPayload {
  const ChatLocationPayload({
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
    this.placeId,
  });

  final double latitude;
  final double longitude;
  final String? name;
  final String? address;
  final String? placeId;

  /// Legacy alias used by older content JSON.
  String? get label => name ?? address;

  Map<String, dynamic> toPayloadMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
      if (address != null && address!.trim().isNotEmpty)
        'address': address!.trim(),
      if (placeId != null && placeId!.trim().isNotEmpty)
        'placeId': placeId!.trim(),
    };
  }

  String toJsonString() => jsonEncode(toPayloadMap());

  static ChatLocationPayload? tryParse(
    String? raw, [
    Map<String, dynamic>? payload,
  ]) {
    final fromPayload = _fromMap(payload);
    if (fromPayload != null) return fromPayload;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return _fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static ChatLocationPayload? _fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final lat = _toDouble(map['latitude'] ?? map['lat']);
    final lng = _toDouble(map['longitude'] ?? map['lng']);
    if (lat == null || lng == null) return null;
    final name = (map['name'] ?? map['label'])?.toString();
    final address = map['address']?.toString();
    return ChatLocationPayload(
      latitude: lat,
      longitude: lng,
      name: name,
      address: address,
      placeId: map['placeId']?.toString() ?? map['place_id']?.toString(),
    );
  }

  String get displayLabel {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (address != null && address!.trim().isNotEmpty) return address!.trim();
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  String get mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
}

class ChatContactPayload {
  const ChatContactPayload({
    required this.name,
    this.phone = '',
    this.email,
    this.userId,
    this.avatarUrl,
  });

  final String name;
  final String phone;
  final String? email;
  final String? userId;
  final String? avatarUrl;

  bool get hasPhone => phone.trim().isNotEmpty;
  bool get isAppUser => userId != null && userId!.trim().isNotEmpty;

  Map<String, dynamic> toPayloadMap() {
    if (isAppUser) {
      return {'userId': userId!.trim()};
    }
    return {
      'name': name,
      if (hasPhone) 'phone': phone.trim(),
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      if (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
        'avatarUrl': avatarUrl!.trim(),
    };
  }

  String toJsonString() => jsonEncode(toPayloadMap());

  static ChatContactPayload? tryParse(
    String? raw, [
    Map<String, dynamic>? payload,
  ]) {
    final fromPayload = _fromMap(payload);
    if (fromPayload != null) return fromPayload;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return _fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static ChatContactPayload? _fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final userId = (map['userId'] ?? map['user_id'])?.toString();
    final name = (map['name'] ??
            map['displayName'] ??
            map['username'] ??
            map['fullName'])
        ?.toString();
    final phone = (map['phone'] ??
            map['phoneNumber'] ??
            map['mobile'] ??
            '')
        .toString();
    final email = map['email']?.toString();
    final avatarUrl = (map['avatarUrl'] ?? map['avatar_url'])?.toString();

    if (userId != null && userId.trim().isNotEmpty) {
      return ChatContactPayload(
        name: (name ?? '').trim().isNotEmpty ? name!.trim() : 'User',
        phone: phone.trim(),
        email: email,
        userId: userId.trim(),
        avatarUrl: avatarUrl,
      );
    }
    if (name == null || name.trim().isEmpty) return null;
    if (phone.trim().isEmpty && (email == null || email.trim().isEmpty)) {
      return null;
    }
    return ChatContactPayload(
      name: name.trim(),
      phone: phone.trim(),
      email: email,
      avatarUrl: avatarUrl,
    );
  }
}

class ChatFilePayload {
  const ChatFilePayload({
    required this.url,
    required this.fileName,
    required this.mimeType,
    this.sizeBytes,
  });

  final String url;
  final String fileName;
  final String mimeType;
  final int? sizeBytes;

  Map<String, dynamic> toPayloadMap() {
    return {
      'url': url,
      'fileName': fileName,
      'mimeType': mimeType,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
    };
  }

  static ChatFilePayload? tryParse(
    String? content,
    String? mediaUrl, [
    Map<String, dynamic>? payload,
  ]) {
    if (payload != null) {
      final url = (payload['url'] ?? mediaUrl)?.toString();
      final fileName = (payload['fileName'] ??
              payload['file_name'] ??
              content ??
              'file')
          .toString();
      final mime = (payload['mimeType'] ?? payload['mime_type'] ?? 'application/octet-stream')
          .toString();
      final size = payload['sizeBytes'] ?? payload['size_bytes'];
      final sizeBytes = size is num
          ? size.toInt()
          : int.tryParse(size?.toString() ?? '');
      if (url != null && url.trim().isNotEmpty) {
        return ChatFilePayload(
          url: MediaUtils.resolveAbsoluteUrl(url),
          fileName: fileName,
          mimeType: mime,
          sizeBytes: sizeBytes,
        );
      }
    }

    final url = mediaUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ChatFilePayload(
        url: MediaUtils.resolveAbsoluteUrl(url),
        fileName: (content?.trim().isNotEmpty == true) ? content!.trim() : 'file',
        mimeType: 'application/octet-stream',
      );
    }
    return null;
  }
}

class ChatGiftPayload {
  const ChatGiftPayload({
    required this.giftId,
    this.name,
    this.thumbnailUrl,
    this.animationUrl,
    this.priceCoins,
    this.quantity = 1,
    this.receiverId,
  });

  final String giftId;
  final String? name;
  final String? thumbnailUrl;
  final String? animationUrl;
  final int? priceCoins;
  final int quantity;
  final String? receiverId;

  static ChatGiftPayload? tryParse(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final giftId = (payload['giftId'] ?? payload['gift_id'])?.toString();
    if (giftId == null || giftId.isEmpty) return null;
    final price = payload['priceCoins'] ?? payload['price_coins'];
    final qty = payload['quantity'];
    return ChatGiftPayload(
      giftId: giftId,
      name: payload['name']?.toString(),
      thumbnailUrl: (payload['thumbnailUrl'] ?? payload['thumbnail_url'])
          ?.toString(),
      animationUrl: (payload['animationUrl'] ?? payload['animation_url'])
          ?.toString(),
      priceCoins: price is num
          ? price.toInt()
          : int.tryParse(price?.toString() ?? ''),
      quantity: qty is num
          ? qty.toInt()
          : int.tryParse(qty?.toString() ?? '') ?? 1,
      receiverId:
          (payload['receiverId'] ?? payload['receiver_id'])?.toString(),
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String inferMimeTypeFromFileName(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'txt':
      return 'text/plain';
    case 'zip':
      return 'application/zip';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'mp4':
      return 'video/mp4';
    case 'mp3':
      return 'audio/mpeg';
    default:
      return 'application/octet-stream';
  }
}

String formatFileSizeBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(bytes < 10 * 1024 ? 1 : 0)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
