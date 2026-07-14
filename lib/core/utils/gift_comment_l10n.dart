import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

/// Localized display text for gift comments (never embeds image URLs).
String localizedGiftCommentText(AppLocalizations l10n, CommentEntity comment) {
  if (!comment.isGift) return comment.content;

  final giftName = _resolveGiftName(comment);
  if (giftName.isEmpty) {
    return l10n.liveGiftCommentGeneric;
  }

  final emoji = _resolveGiftEmoji(comment);
  final text = l10n.liveGiftSent(
    _localizeGiftName(l10n, giftName),
    emoji,
  );
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Network thumbnail for gift comments (null when only an emoji icon exists).
String? giftCommentImageUrl(CommentEntity comment) {
  for (final candidate in [
    comment.giftThumbnailUrl,
    comment.giftIcon,
  ]) {
    final value = candidate?.trim();
    if (value != null && value.isNotEmpty && looksLikeGiftImageUrl(value)) {
      return value;
    }
  }
  return null;
}

bool looksLikeGiftImageUrl(String value) {
  final lower = value.trim().toLowerCase();
  if (lower.isEmpty) return false;
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('/') ||
      lower.startsWith('uploads/')) {
    return true;
  }
  return lower.contains('.png') ||
      lower.contains('.jpg') ||
      lower.contains('.jpeg') ||
      lower.contains('.webp') ||
      lower.contains('.gif');
}

String _resolveGiftName(CommentEntity comment) {
  final fromField = comment.giftName?.trim();
  if (fromField != null && fromField.isNotEmpty) return fromField;
  return _parseGiftNameFromContent(comment.content);
}

/// Emoji / short symbol only — never a URL.
String _resolveGiftEmoji(CommentEntity comment) {
  final fromField = comment.giftIcon?.trim();
  if (fromField != null &&
      fromField.isNotEmpty &&
      !looksLikeGiftImageUrl(fromField)) {
    return fromField;
  }
  return _parseGiftIconFromContent(comment.content) ?? '';
}

String _parseGiftNameFromContent(String content) {
  var text = content.trim();
  if (text.isEmpty) return '';

  text = text.replaceFirst(
    RegExp(r'^(sent|تم إرسال)\s+', caseSensitive: false),
    '',
  );

  // Drop trailing URLs that APIs sometimes bake into content.
  text = text.replaceAll(
    RegExp(r'https?:\/\/\S+', caseSensitive: false),
    '',
  );
  text = text.replaceAll(RegExp(r'\/uploads\/\S+', caseSensitive: false), '');

  final emojiPattern = RegExp(
    r'(\p{Extended_Pictographic}|\uFE0F|\u200D)',
    unicode: true,
  );
  final iconMatch = emojiPattern.firstMatch(text);
  if (iconMatch != null) {
    text = text.substring(0, iconMatch.start).trim();
  }

  return text.trim().isEmpty ? '' : text.trim();
}

String? _parseGiftIconFromContent(String content) {
  final emojiPattern = RegExp(
    r'\p{Extended_Pictographic}',
    unicode: true,
  );
  final match = emojiPattern.allMatches(content.trim());
  if (match.isEmpty) return null;
  return match.last.group(0);
}

String _localizeGiftName(AppLocalizations l10n, String name) {
  switch (name.trim().toLowerCase()) {
    case 'rose':
      return l10n.liveGiftRose;
    case 'coffee':
      return l10n.liveGiftCoffee;
    case 'donut':
      return l10n.liveGiftDonut;
    case 'heart':
      return l10n.liveGiftHeart;
    case 'party':
      return l10n.liveGiftParty;
    case 'crown':
    case 'golden crown':
      return l10n.liveGiftCrown;
    case 'rocket':
      return l10n.liveGiftRocket;
    case 'diamond':
      return l10n.liveGiftDiamond;
    default:
      return name;
  }
}
