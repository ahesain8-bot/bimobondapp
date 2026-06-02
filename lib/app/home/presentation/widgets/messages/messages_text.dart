import 'package:bimobondapp/l10n/app_localizations.dart';

String messagesPreviewText(String? key, AppLocalizations l10n) {
  switch (key) {
    case 'property':
      return l10n.messagesPreviewProperty;
    case 'offer':
      return l10n.messagesPreviewOffer;
    case 'thanks':
      return l10n.messagesPreviewThanks;
    case 'car':
      return l10n.messagesPreviewCar;
    default:
      return '';
  }
}

String messagesMentionText(String? key, AppLocalizations l10n) {
  switch (key) {
    case 'villa':
      return l10n.messagesMentionVilla;
    case 'check':
      return l10n.messagesMentionCheck;
    default:
      return '';
  }
}

String messagesSuggestionReason({
  required String? reason,
  required int mutualCount,
  required AppLocalizations l10n,
}) {
  if (mutualCount > 0) {
    return l10n.messagesSuggestionMutualFriends(mutualCount);
  }

  switch (reason) {
    case 'friends_of_friends':
      return l10n.messagesSuggestionFriendsOfFriends;
    case 'popular':
      return l10n.messagesSuggestionPopular;
    default:
      return reason?.replaceAll('_', ' ') ?? '';
  }
}

String messagesSuggestionBio(String? key, AppLocalizations l10n) {
  switch (key) {
    case 'designer':
      return l10n.messagesSuggestionBioDesigner;
    case 'jeddah':
      return l10n.messagesSuggestionBioJeddah;
    case 'luxury':
      return l10n.messagesSuggestionBioLuxury;
    default:
      return '';
  }
}
