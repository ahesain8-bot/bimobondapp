/// Encodes/decodes image attachments stored in comment `content`.
///
/// Backend currently accepts text `content` only; image comments are sent as a
/// marked URL so they round-trip through the existing API.
class CommentMedia {
  CommentMedia._();

  static const marker = '[bimobond_img]';

  static final RegExp _bareImageUrl = RegExp(
    r'^https?:\/\/\S+\.(?:jpg|jpeg|png|gif|webp|heic)(?:\?\S*)?$',
    caseSensitive: false,
  );

  static String encodeImage(String url) => '$marker${url.trim()}';

  static String? parseImageUrl(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith(marker)) {
      final url = trimmed.substring(marker.length).trim();
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }
      return null;
    }

    if (_bareImageUrl.hasMatch(trimmed)) return trimmed;
    return null;
  }

  static bool isImageComment(String content) => parseImageUrl(content) != null;
}
