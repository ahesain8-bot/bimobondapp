import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PostShareLink {
  PostShareLink._();

  static String forPost(PostEntity post) =>
      '${ApiConstants.baseUrl}/posts/${post.id}';
}

/// Opens external apps / system share for a post link.
class PostShareDestinations {
  PostShareDestinations._();

  static Future<bool> _open(Uri uri) async {
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> messenger(String link) async {
    final encoded = Uri.encodeComponent(link);
    final opened = await _open(
      Uri.parse('fb-messenger://share?link=$encoded'),
    );
    if (!opened) {
      await _open(
        Uri.parse(
          'https://www.facebook.com/dialog/send?link=$encoded&redirect_uri=$encoded',
        ),
      );
    }
  }

  static Future<void> facebook(String link) async {
    await _open(
      Uri.parse(
        'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(link)}',
      ),
    );
  }

  static Future<void> whatsApp(String link) async {
    final text = Uri.encodeComponent(link);
    final opened = await _open(Uri.parse('whatsapp://send?text=$text'));
    if (!opened) {
      await _open(Uri.parse('https://wa.me/?text=$text'));
    }
  }

  static Future<void> telegram(String link) async {
    await _open(
      Uri.parse(
        'https://t.me/share/url?url=${Uri.encodeComponent(link)}',
      ),
    );
  }

  static Future<void> twitter(String link) async {
    await _open(
      Uri.parse(
        'https://twitter.com/intent/tweet?url=${Uri.encodeComponent(link)}',
      ),
    );
  }

  static Future<void> sms(String link) async {
    await _open(Uri.parse('sms:?body=${Uri.encodeComponent(link)}'));
  }

  static Future<void> email(String link) async {
    await _open(
      Uri.parse('mailto:?body=${Uri.encodeComponent(link)}'),
    );
  }

  static Future<void> copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
  }

  static Future<void> systemShare(String link, {String? message}) async {
    await SharePlus.instance.share(
      ShareParams(text: message ?? link, subject: message),
    );
  }
}
