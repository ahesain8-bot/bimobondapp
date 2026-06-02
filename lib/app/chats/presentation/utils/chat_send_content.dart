/// Builds a non-empty [content] string for the chat messages API.
///
/// Media is uploaded first; [mediaUrl] is then sent in both `mediaUrl` and
/// `content` when the draft has no caption (same pattern as post media URLs).
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
      case 'FILE':
      case 'AUDIO':
      case 'VOICE':
        return url;
    }
  }

  switch (messageType.toUpperCase()) {
    case 'LOCATION':
    case 'CONTACT':
      return draft;
    default:
      return url ?? '.';
  }
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
