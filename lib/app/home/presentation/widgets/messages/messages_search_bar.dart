import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class MessagesSearchBar extends StatelessWidget {
  const MessagesSearchBar({
    required this.controller,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
    this.autofocus = false,
    this.focusNode,
    super.key,
  })  : readOnly = false,
        onTap = null;

  const MessagesSearchBar.launcher({
    required this.onTap,
    super.key,
  })  : controller = null,
        searchQuery = '',
        onChanged = null,
        onClear = null,
        autofocus = false,
        focusNode = null,
        readOnly = true;

  final TextEditingController? controller;
  final String searchQuery;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: readOnly ? onTap : null,
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
        suffixIcon: !readOnly && searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.cancel_rounded, size: 18),
                onPressed: onClear,
              )
            : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );

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
        child: readOnly
            ? GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: AbsorbPointer(child: field),
              )
            : field,
      ),
    );
  }
}
