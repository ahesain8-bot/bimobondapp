import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

export 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_settings_sheet.dart'
    show
        localizedAddPostPrivacyStatus,
        localizedAddPostPrivacyRowLabel;

class AddPostPrivacyPickerSheet {
  AddPostPrivacyPickerSheet._();

  static Future<void> show(
    BuildContext context, {
    required String selectedStatus,
    required ValueChanged<String> onSelected,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return GlassBottomSheetShell.show<void>(
      context,
      title: l10n.whoCanWatchLabel,
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
      ],
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
    return GlassBottomSheetActionTile(
      icon: privacyIconForStatus(value),
      label: label,
      isSelected: selectedStatus == value,
      showChevron: false,
      onTap: () {
        onSelected(value);
        Navigator.pop(context);
      },
    );
  }
}
