import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class MessagesSearchBar extends StatelessWidget {
  const MessagesSearchBar({
    required this.controller,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MessagesLayoutConstants.horizontalPadding,
        MessagesLayoutConstants.searchBarTopPadding,
        MessagesLayoutConstants.horizontalPadding,
        MessagesLayoutConstants.searchBarBottomPadding,
      ),
      child: Container(
        height: MessagesLayoutConstants.searchBarHeight,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(
            MessagesLayoutConstants.searchBarRadius,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: MessagesLayoutConstants.searchBarShadowAlpha,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: theme.dividerColor.withValues(
              alpha: MessagesLayoutConstants.searchBarBorderAlpha,
            ),
          ),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: l10n.messagesSearchHint,
            hintStyle: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
              fontSize: 15,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.primary.withValues(
                alpha: MessagesLayoutConstants.searchIconAlpha,
              ),
              size: 22,
            ),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel_rounded, size: 18),
                    onPressed: onClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}
