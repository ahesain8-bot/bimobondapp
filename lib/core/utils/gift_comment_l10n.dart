import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

/// Localized display text for gift comments from the API.
String localizedGiftCommentText(AppLocalizations l10n, CommentEntity comment) {
  if (!comment.isGift) return comment.content;

  final giftName = _resolveGiftName(comment);
  final giftIcon = _resolveGiftIcon(comment);

  if (giftName.isEmpty) {
    return l10n.liveGiftCommentGeneric;
  }

  return l10n.liveGiftSent(
    _localizeGiftName(l10n, giftName),
    giftIcon,
  );
}

String _resolveGiftName(CommentEntity comment) {
  final fromField = comment.giftName?.trim();
  if (fromField != null && fromField.isNotEmpty) return fromField;
  return _parseGiftNameFromContent(comment.content);
}

String _resolveGiftIcon(CommentEntity comment) {
  final fromField = comment.giftIcon?.trim();
  if (fromField != null && fromField.isNotEmpty) return fromField;
  return _parseGiftIconFromContent(comment.content) ?? '🎁';
}

String _parseGiftNameFromContent(String content) {
  var text = content.trim();
  if (text.isEmpty) return '';

  text = text.replaceFirst(
    RegExp(r'^(sent|تم إرسال)\s+', caseSensitive: false),
    '',
  );

  final emojiPattern = RegExp(
    r'(\p{Extended_Pictographic}|\uFE0F|\u200D)',
    unicode: true,
  );
  final iconMatch = emojiPattern.firstMatch(text);
  if (iconMatch != null) {
    text = text.substring(0, iconMatch.start).trim();
  }

  return text.isEmpty ? content.trim() : text;
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
