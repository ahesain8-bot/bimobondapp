import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Rounded search field used on New Chat (and reusable elsewhere).
class MessagesRoundedSearchField extends StatelessWidget {
  const MessagesRoundedSearchField({
    required this.controller,
    this.onChanged,
    this.autofocus = false,
    this.hintText,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MessagesLayoutConstants.horizontalPadding,
        4,
        MessagesLayoutConstants.horizontalPadding,
        12,
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText ?? l10n.messagesNewChatSearchHint,
          hintStyle: TextStyle(
            color: chatTheme.inboxSecondaryText,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            size: 20,
            color: chatTheme.inboxSecondaryText,
          ),
          filled: true,
          fillColor: chatTheme.inboxSearchFill,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
