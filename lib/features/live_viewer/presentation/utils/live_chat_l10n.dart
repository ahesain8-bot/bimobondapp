import '../../../../l10n/app_localizations.dart';
import '../../domain/live_chat_rules.dart';

String liveChatNoticeText(AppLocalizations l10n, LiveChatNotice notice) {
  switch (notice.kind) {
    case LiveChatNoticeKind.muted:
      return l10n.liveChatMutedOnLive;
    case LiveChatNoticeKind.unmuted:
      return l10n.liveChatUnmuted;
    case LiveChatNoticeKind.mutedReason:
      return l10n.liveChatMutedReason(notice.reason ?? '');
    case LiveChatNoticeKind.rulesUpdated:
      return liveChatRulesUpdatedText(l10n, notice);
    case LiveChatNoticeKind.followToComment:
      return l10n.liveChatFollowToComment;
    case LiveChatNoticeKind.subscribeToComment:
      return l10n.liveChatSubscribeToComment;
    case LiveChatNoticeKind.blockedKeyword:
      final server = notice.serverMessage?.trim();
      if (server != null && server.isNotEmpty) return server;
      return l10n.liveChatBlockedKeyword;
    case LiveChatNoticeKind.slowMode:
      final seconds = notice.seconds ?? 0;
      if (seconds > 0) return l10n.liveChatSlowModeWait(seconds);
      final server = notice.serverMessage?.trim();
      if (server != null && server.isNotEmpty) return server;
      return l10n.liveChatSlowModeWait(1);
    case LiveChatNoticeKind.sendFailed:
      final server = notice.serverMessage?.trim();
      if (server != null && server.isNotEmpty) return server;
      return l10n.liveChatSendFailed;
    case LiveChatNoticeKind.deleteFailed:
      return l10n.liveChatDeleteFailed;
  }
}

String liveChatRulesUpdatedText(AppLocalizations l10n, LiveChatNotice notice) {
  if (notice.ruleChanges.isEmpty) return l10n.liveChatRulesUpdated;
  return notice.ruleChanges
      .map((change) => _ruleChangeText(l10n, change))
      .join('\n');
}

String _ruleChangeText(AppLocalizations l10n, LiveChatRuleChange change) {
  switch (change.kind) {
    case LiveChatRuleChangeKind.slowModeEnabled:
      return l10n.liveChatSlowModeEnabled(change.seconds ?? 0);
    case LiveChatRuleChangeKind.slowModeChanged:
      return l10n.liveChatSlowModeChanged(change.seconds ?? 0);
    case LiveChatRuleChangeKind.slowModeDisabled:
      return l10n.liveChatSlowModeDisabled;
    case LiveChatRuleChangeKind.chatEveryone:
      return l10n.liveChatModeEveryone;
    case LiveChatRuleChangeKind.chatFollowers:
      return l10n.liveChatModeFollowers;
    case LiveChatRuleChangeKind.chatSubscribers:
      return l10n.liveChatModeSubscribers;
    case LiveChatRuleChangeKind.blockedKeywords:
      return l10n.liveChatBlockedKeywordsUpdated;
  }
}

String liveChatComposerHint(
  AppLocalizations l10n,
  LiveChatComposerStatus status, {
  required bool sending,
}) {
  if (sending) return l10n.liveChatSending;
  switch (status.block) {
    case LiveChatComposerBlock.muted:
      return l10n.liveChatMuted;
    case LiveChatComposerBlock.followers:
      return l10n.liveChatFollowToComment;
    case LiveChatComposerBlock.subscribers:
      return l10n.liveChatSubscribeToComment;
    case LiveChatComposerBlock.slowMode:
      return l10n.liveChatSlowModeWait(status.slowModeRemainingSeconds);
    case LiveChatComposerBlock.none:
      return l10n.liveChatComment;
  }
}
