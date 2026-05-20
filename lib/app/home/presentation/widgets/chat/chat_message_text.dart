import 'package:bimobondapp/l10n/app_localizations.dart';

String chatTextFromKey(String? key, AppLocalizations l10n) {
  switch (key) {
    case 'greeting':
      return l10n.chatSeedGreeting;
    case 'interested':
      return l10n.chatSeedInterested;
    case 'finalPrice':
      return l10n.chatSeedFinalPrice;
    case 'autoReply':
      return l10n.chatSeedAutoReply;
    default:
      return '';
  }
}

String chatMessageText(
  Map<String, dynamic> msg,
  AppLocalizations l10n,
) {
  final direct = msg['text'] as String?;
  if (direct != null && direct.isNotEmpty) return direct;
  return chatTextFromKey(msg['textKey'] as String?, l10n);
}

List<Map<String, dynamic>> chatSeedMessages() => [
  {
    'id': '1',
    'type': 'text',
    'textKey': 'greeting',
    'isMe': false,
    'time': '10:00 AM',
    'reactions': <String>[],
    'status': 'read',
  },
  {
    'id': '2',
    'type': 'text',
    'textKey': 'interested',
    'isMe': true,
    'time': '10:01 AM',
    'reactions': ['👍'],
    'status': 'read',
  },
  {
    'id': '3',
    'type': 'image',
    'imageUrl': 'https://picsum.photos/400/300?random=1',
    'isMe': false,
    'time': '10:02 AM',
    'reactions': <String>[],
    'status': 'read',
  },
  {
    'id': '4',
    'type': 'text',
    'textKey': 'finalPrice',
    'isMe': true,
    'time': '10:03 AM',
    'reactions': <String>[],
    'status': 'read',
  },
];

String chatFormatCurrentTime() {
  final now = DateTime.now();
  final hour =
      now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
  final ampm = now.hour >= 12 ? 'PM' : 'AM';
  return '${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm';
}
