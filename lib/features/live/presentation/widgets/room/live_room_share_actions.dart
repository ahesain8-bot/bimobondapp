import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds the public live URL and performs platform share side-effects.
///
/// Kept out of the BLoC so platform channels stay in the presentation layer,
/// while session identity still comes from domain state.
class LiveRoomShareActions {
  const LiveRoomShareActions._();

  static String liveUrl(String sessionId) =>
      'https://live.bimobond.app/l/$sessionId';

  static String shareMessage(String sessionId, {String? hostName}) {
    final url = liveUrl(sessionId);
    if (hostName == null || hostName.trim().isEmpty) {
      return 'شاهد البث المباشر الآن: $url';
    }
    return 'شاهد بث $hostName المباشر الآن: $url';
  }

  static Future<void> copyLink(String sessionId) async {
    await Clipboard.setData(ClipboardData(text: liveUrl(sessionId)));
  }

  static Future<bool> openWhatsApp(String message) {
    return _launchPreferred([
      Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}'),
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
    ]);
  }

  static Future<bool> openTelegram({
    required String url,
    required String message,
  }) {
    return _launchPreferred([
      Uri.parse(
        'https://t.me/share/url'
        '?url=${Uri.encodeComponent(url)}'
        '&text=${Uri.encodeComponent(message)}',
      ),
    ]);
  }

  static Future<bool> openFacebook(String url) {
    return _launchPreferred([
      Uri.parse(
        'https://www.facebook.com/sharer/sharer.php'
        '?u=${Uri.encodeComponent(url)}',
      ),
    ]);
  }

  static Future<bool> _launchPreferred(List<Uri> candidates) async {
    for (final uri in candidates) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (_) {
        // Try the next candidate.
      }
    }
    return false;
  }
}
