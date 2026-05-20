import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

String localizedAddPostPrivacyStatus(String status, AppLocalizations l10n) {
  switch (status) {
    case 'PUBLIC':
      return l10n.everyoneLabel;
    case 'FRIENDS':
      return l10n.friendsLabel;
    case 'PRIVATE':
      return l10n.onlyMeLabel;
    default:
      return status;
  }
}

class AddPostPrivacyPickerSheet {
  AddPostPrivacyPickerSheet._();

  static Future<void> show(
    BuildContext context, {
    required String selectedStatus,
    required ValueChanged<String> onSelected,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.p16)),
      ),
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrivacyOption(
            value: 'PUBLIC',
            label: l10n.everyoneLabel,
            selectedStatus: selectedStatus,
            onSelected: onSelected,
          ),
          _PrivacyOption(
            value: 'FRIENDS',
            label: l10n.friendsLabel,
            selectedStatus: selectedStatus,
            onSelected: onSelected,
          ),
          _PrivacyOption(
            value: 'PRIVATE',
            label: l10n.onlyMeLabel,
            selectedStatus: selectedStatus,
            onSelected: onSelected,
          ),
          const SizedBox(height: AppSizes.p20),
        ],
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  const _PrivacyOption({
    required this.value,
    required this.label,
    required this.selectedStatus,
    required this.onSelected,
  });

  final String value;
  final String label;
  final String selectedStatus;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(label),
      trailing: selectedStatus == value
          ? Icon(LucideIcons.check, color: theme.colorScheme.primary)
          : null,
      onTap: () {
        onSelected(value);
        Navigator.pop(context);
      },
    );
  }
}
