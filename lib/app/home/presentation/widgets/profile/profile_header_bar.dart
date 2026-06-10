import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfileHeaderBar extends StatelessWidget {
  const ProfileHeaderBar({
    required this.username,
    required this.onSettings,
    super.key,
  });

  final String username;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsOnRight =
        Localizations.localeOf(context).languageCode == 'ar';

    final settingsButton = IconButton(
      onPressed: onSettings,
      icon: Icon(
        LucideIcons.menu,
        size: ProfileLayoutConstants.headerMenuIconSize,
        color: theme.iconTheme.color,
      ),
    );

    const sideSpacer = SizedBox(width: 48);

    final title = Expanded(
      child: CustomText(
        username,
        textAlign: TextAlign.center,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileLayoutConstants.headerHorizontalPadding,
        vertical: ProfileLayoutConstants.headerVerticalPadding,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: settingsOnRight
              ? [sideSpacer, title, settingsButton]
              : [settingsButton, title, sideSpacer],
        ),
      ),
    );
  }
}
