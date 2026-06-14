import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/widgets/common_search_bar.dart';
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MessagesLayoutConstants.horizontalPadding,
        MessagesLayoutConstants.searchBarTopPadding,
        MessagesLayoutConstants.horizontalPadding,
        MessagesLayoutConstants.searchBarBottomPadding,
      ),
      child: CommonSearchBar(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        onClear: onClear,
        hintText: l10n.messagesSearchHint,
      ),
    );
  }
}
