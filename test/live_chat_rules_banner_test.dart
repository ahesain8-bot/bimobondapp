import 'package:bimobondapp/features/live_viewer/domain/live_chat_rules.dart';
import 'package:bimobondapp/features/live_viewer/presentation/utils/live_chat_l10n.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

LiveChatNotice _notice(List<LiveChatRuleChange> changes) {
  return LiveChatNotice(
    LiveChatNoticeKind.rulesUpdated,
    ruleChanges: changes,
  );
}

void main() {
  const previous = LiveChatRules();

  group('LiveChatRules.diff', () {
    test('slow mode enabled', () {
      final next = previous.mergeChatRules({'slowModeSeconds': 10});
      expect(
        LiveChatRules.diff(previous, next),
        [
          const LiveChatRuleChange(
            LiveChatRuleChangeKind.slowModeEnabled,
            seconds: 10,
          ),
        ],
      );
    });

    test('slow mode changed', () {
      const from = LiveChatRules(slowModeSeconds: 5);
      final next = from.mergeChatRules({'slowModeSeconds': 15});
      expect(
        LiveChatRules.diff(from, next),
        [
          const LiveChatRuleChange(
            LiveChatRuleChangeKind.slowModeChanged,
            seconds: 15,
          ),
        ],
      );
    });

    test('slow mode disabled', () {
      const from = LiveChatRules(slowModeSeconds: 10);
      final next = from.mergeChatRules({'slowModeSeconds': 0});
      expect(
        LiveChatRules.diff(from, next),
        [const LiveChatRuleChange(LiveChatRuleChangeKind.slowModeDisabled)],
      );
    });

    test('EVERYONE', () {
      const from = LiveChatRules(chatMode: LiveChatRules.followers);
      final next = from.mergeChatRules({'chatMode': 'EVERYONE'});
      expect(
        LiveChatRules.diff(from, next),
        [const LiveChatRuleChange(LiveChatRuleChangeKind.chatEveryone)],
      );
    });

    test('FOLLOWERS', () {
      final next = previous.mergeChatRules({'chatMode': 'FOLLOWERS'});
      expect(
        LiveChatRules.diff(previous, next),
        [const LiveChatRuleChange(LiveChatRuleChangeKind.chatFollowers)],
      );
    });

    test('SUBSCRIBERS', () {
      final next = previous.mergeChatRules({'chatMode': 'SUBSCRIBERS'});
      expect(
        LiveChatRules.diff(previous, next),
        [const LiveChatRuleChange(LiveChatRuleChangeKind.chatSubscribers)],
      );
    });

    test('blocked keywords changed without exposing the list', () {
      const from = LiveChatRules(blockedKeywords: ['old']);
      final next = from.mergeChatRules({
        'blockedKeywords': ['secret', 'word'],
      });
      expect(
        LiveChatRules.diff(from, next),
        [const LiveChatRuleChange(LiveChatRuleChangeKind.blockedKeywords)],
      );
    });

    test('multiple rule changes', () {
      final next = previous.mergeChatRules({
        'chatMode': 'FOLLOWERS',
        'slowModeSeconds': 10,
        'blockedKeywords': ['x'],
      });
      expect(LiveChatRules.diff(previous, next), [
        const LiveChatRuleChange(
          LiveChatRuleChangeKind.slowModeEnabled,
          seconds: 10,
        ),
        const LiveChatRuleChange(LiveChatRuleChangeKind.chatFollowers),
        const LiveChatRuleChange(LiveChatRuleChangeKind.blockedKeywords),
      ]);
    });
  });

  group('chat-rule banner localization', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ar = lookupAppLocalizations(const Locale('ar'));

    test('AR and EN slow mode enabled', () {
      final notice = _notice([
        const LiveChatRuleChange(
          LiveChatRuleChangeKind.slowModeEnabled,
          seconds: 10,
        ),
      ]);
      expect(
        liveChatNoticeText(ar, notice),
        'تم تفعيل الوضع البطيء: 10 ثوانٍ بين التعليقات',
      );
      expect(
        liveChatNoticeText(en, notice),
        'Slow mode on: 10 seconds between comments',
      );
    });

    test('AR and EN slow mode changed', () {
      final notice = _notice([
        const LiveChatRuleChange(
          LiveChatRuleChangeKind.slowModeChanged,
          seconds: 15,
        ),
      ]);
      expect(
        liveChatNoticeText(ar, notice),
        'تم تغيير الوضع البطيء: 15 ثوانٍ بين التعليقات',
      );
      expect(
        liveChatNoticeText(en, notice),
        'Slow mode is now 15 seconds between comments',
      );
    });

    test('AR and EN slow mode disabled', () {
      final notice = _notice([
        const LiveChatRuleChange(LiveChatRuleChangeKind.slowModeDisabled),
      ]);
      expect(liveChatNoticeText(ar, notice), 'تم إيقاف الوضع البطيء');
      expect(liveChatNoticeText(en, notice), 'Slow mode turned off');
    });

    test('AR and EN EVERYONE', () {
      final notice = _notice([
        const LiveChatRuleChange(LiveChatRuleChangeKind.chatEveryone),
      ]);
      expect(liveChatNoticeText(ar, notice), 'أصبحت الدردشة متاحة للجميع');
      expect(liveChatNoticeText(en, notice), 'Chat is now open to everyone');
    });

    test('AR and EN FOLLOWERS', () {
      final notice = _notice([
        const LiveChatRuleChange(LiveChatRuleChangeKind.chatFollowers),
      ]);
      expect(liveChatNoticeText(ar, notice), 'أصبحت الدردشة للمتابعين فقط');
      expect(liveChatNoticeText(en, notice), 'Chat is now followers only');
    });

    test('AR and EN SUBSCRIBERS', () {
      final notice = _notice([
        const LiveChatRuleChange(LiveChatRuleChangeKind.chatSubscribers),
      ]);
      expect(liveChatNoticeText(ar, notice), 'أصبحت الدردشة للمشتركين فقط');
      expect(liveChatNoticeText(en, notice), 'Chat is now subscribers only');
    });

    test('AR and EN blocked keywords without listing words', () {
      final notice = _notice([
        const LiveChatRuleChange(LiveChatRuleChangeKind.blockedKeywords),
      ]);
      expect(liveChatNoticeText(ar, notice), 'تم تحديث الكلمات المحظورة');
      expect(liveChatNoticeText(en, notice), 'Blocked keywords updated');
      expect(liveChatNoticeText(en, notice).toLowerCase(), isNot(contains('secret')));
    });

    test('AR and EN multiple rule changes', () {
      final notice = _notice([
        const LiveChatRuleChange(
          LiveChatRuleChangeKind.slowModeEnabled,
          seconds: 10,
        ),
        const LiveChatRuleChange(LiveChatRuleChangeKind.chatFollowers),
      ]);
      expect(
        liveChatNoticeText(ar, notice),
        'تم تفعيل الوضع البطيء: 10 ثوانٍ بين التعليقات\nأصبحت الدردشة للمتابعين فقط',
      );
      expect(
        liveChatNoticeText(en, notice),
        'Slow mode on: 10 seconds between comments\nChat is now followers only',
      );
    });
  });
}
