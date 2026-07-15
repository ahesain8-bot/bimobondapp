/// Builds a non-empty [content] string for the chat messages API when needed.
///
/// Rich types (`LOCATION`, `CONTACT`, `GIFT`, `POLL`) can omit content; the API
/// fills an inbox preview. Media types still send a caption or URL fallback.
String buildChatMessageContent({
  required String messageType,
  required String draftContent,
  String? mediaUrl,
}) {
  final draft = draftContent.trim();
  if (draft.isNotEmpty) return draft;

  final url = mediaUrl?.trim();
  if (url != null && url.isNotEmpty) {
    switch (messageType.toUpperCase()) {
      case 'IMAGE':
      case 'VIDEO':
      case 'AUDIO':
      case 'VOICE':
        return url;
    }
  }

  return '';
}

bool chatMessageTypeRequiresUpload(String messageType) {
  switch (messageType.toUpperCase()) {
    case 'IMAGE':
    case 'VIDEO':
    case 'FILE':
    case 'AUDIO':
    case 'VOICE':
      return true;
    default:
      return false;
  }
}

bool chatMessageTypeUsesPayload(String messageType) {
  switch (messageType.toUpperCase()) {
    case 'LOCATION':
    case 'CONTACT':
    case 'FILE':
    case 'GIFT':
    case 'POLL':
      return true;
    default:
      return false;
  }
}
