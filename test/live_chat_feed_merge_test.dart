import 'package:bimobondapp/features/live/domain/entities/live_chat_feed_merge.dart';
import 'package:bimobondapp/features/live/domain/entities/live_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

LiveChatMessage msg(String id, [String? text]) =>
    LiveChatMessage(id: id, text: text ?? 'body-$id', body: text ?? 'body-$id');

void main() {
  group('mergeLiveChatMessages', () {
    test('keeps socket comments that the history page does not contain', () {
      // The regression: enrichment lands after the room goes Ready, and used
      // to assign the history straight over anything already delivered.
      final history = [msg('h1'), msg('h2')];
      final live = [msg('h1'), msg('socket-1'), msg('socket-2')];

      final merged = mergeLiveChatMessages(history, live);

      expect(
        merged.map((m) => m.id),
        ['h1', 'h2', 'socket-1', 'socket-2'],
        reason: 'history order first, unseen live lines appended',
      );
    });

    test('never duplicates a comment delivered by both paths', () {
      final shared = msg('c1');
      final merged = mergeLiveChatMessages([shared], [shared]);

      expect(merged.length, 1);
    });

    test('de-duplicates repeats inside a single side', () {
      final merged = mergeLiveChatMessages([msg('a'), msg('a')], [msg('a')]);

      expect(merged.map((m) => m.id), ['a']);
    });

    test('empty live feed leaves the history untouched', () {
      final history = [msg('h1'), msg('h2')];

      expect(mergeLiveChatMessages(history, const []).map((m) => m.id), [
        'h1',
        'h2',
      ]);
    });

    test('empty history keeps everything the socket delivered', () {
      final live = [msg('s1'), msg('s2')];

      expect(mergeLiveChatMessages(const [], live).map((m) => m.id), [
        's1',
        's2',
      ]);
    });

    test('caps the backlog and keeps the newest lines', () {
      final history = [
        for (var i = 0; i < kLiveChatBacklogLimit + 40; i++) msg('h$i'),
      ];

      final merged = mergeLiveChatMessages(history, [msg('newest')]);

      expect(merged.length, kLiveChatBacklogLimit);
      expect(merged.last.id, 'newest', reason: 'newest line must survive');
      expect(
        merged.any((m) => m.id == 'h0'),
        isFalse,
        reason: 'oldest lines are the ones dropped',
      );
    });
  });

  group('capLiveChatMessages', () {
    test('returns the list unchanged when under the limit', () {
      final messages = [msg('a'), msg('b')];

      expect(identical(capLiveChatMessages(messages), messages), isTrue);
    });

    test('trims from the front so the newest survive', () {
      final messages = [
        for (var i = 0; i < kLiveChatBacklogLimit + 5; i++) msg('m$i'),
      ];

      final capped = capLiveChatMessages(messages);

      expect(capped.length, kLiveChatBacklogLimit);
      expect(capped.first.id, 'm5');
      expect(capped.last.id, 'm${kLiveChatBacklogLimit + 4}');
    });
  });
}
