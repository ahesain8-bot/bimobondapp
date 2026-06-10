import 'package:flutter/material.dart';

/// Inserts @ or # at the text field cursor (or appends when no selection).
class TagTextEditing {
  TagTextEditing._();

  static void insertToken(TextEditingController controller, String token) {
    assert(token == '@' || token == '#');
    final text = controller.text;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.baseOffset : text.length;
    final safeOffset = offset.clamp(0, text.length);

    final newText = text.replaceRange(safeOffset, safeOffset, token);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: safeOffset + token.length),
    );
  }

  static void insertHashtag(TextEditingController controller, String name) {
    var normalized = name.trim();
    if (normalized.startsWith('#')) {
      normalized = normalized.substring(1);
    }
    if (normalized.isEmpty) return;

    final hashtag = '#$normalized ';
    final text = controller.text;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.baseOffset : text.length;
    final safeOffset = offset.clamp(0, text.length);

    final newText = text.replaceRange(safeOffset, safeOffset, hashtag);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: safeOffset + hashtag.length),
    );
  }

  static void insertMention(
    TextEditingController controller,
    String username,
  ) {
    final mention = '@$username ';
    final text = controller.text;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.baseOffset : text.length;
    final safeOffset = offset.clamp(0, text.length);

    final newText = text.replaceRange(safeOffset, safeOffset, mention);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: safeOffset + mention.length),
    );
  }

  /// Replaces `@partial` at [mentionStart]..[mentionEnd] with `@username `.
  static void completeMention(
    TextEditingController controller, {
    required int mentionStart,
    required int mentionEnd,
    required String username,
  }) {
    final text = controller.text;
    final mention = '@$username ';
    final newText = text.replaceRange(mentionStart, mentionEnd, mention);
    final newOffset = mentionStart + mention.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  /// Replaces `#partial` at [hashtagStart]..[hashtagEnd] with `#name `.
  static void completeHashtag(
    TextEditingController controller, {
    required int hashtagStart,
    required int hashtagEnd,
    required String name,
  }) {
    var normalized = name.trim();
    if (normalized.startsWith('#')) {
      normalized = normalized.substring(1);
    }
    if (normalized.isEmpty) return;

    final text = controller.text;
    final hashtag = '#$normalized ';
    final newText = text.replaceRange(hashtagStart, hashtagEnd, hashtag);
    final newOffset = hashtagStart + hashtag.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}
