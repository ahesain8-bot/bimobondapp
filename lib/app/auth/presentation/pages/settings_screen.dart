import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/core/utils/user_roles.dart';
import 'package:bimobondapp/app/auth/presentation/pages/settings_placeholder_screen.dart';
import 'package:bimobondapp/core/constants/settings_layout_constants.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/theme/cubit/theme_cubit.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = context.watch<LocaleCubit>().state;
    final themeMode = context.watch<ThemeCubit>().state;
    final isArabic = locale.languageCode == 'ar';
    final isDark = ThemeCubit.isDarkActive(themeMode);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: l10n.settingsAndPrivacy,
        showBackButton: true,
        // backgroundColor: theme.scaffoldBackgroundColor,
        onBackPressed: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: SettingsLayoutConstants.horizontalPadding,
          vertical: SettingsLayoutConstants.bodyVerticalPadding,
        ),
        children: [
          _SettingsSectionTitle(title: l10n.settingsSectionAccount),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: LucideIcons.user,
                title: l10n.editProfile,
                onTap: () => context.pushNamed('personal_info'),
              ),
              _SettingsTile(
                icon: LucideIcons.shield,
                title: l10n.settingsSecurity,
                onTap: () => _openPlaceholder(context, l10n.settingsSecurity),
              ),
              _SettingsTile(
                icon: LucideIcons.lock,
                title: l10n.settingsPrivacy,
                onTap: () => _openPlaceholder(context, l10n.settingsPrivacy),
              ),
            ],
          ),
          const SizedBox(height: SettingsLayoutConstants.groupSpacing),
          _SettingsSectionTitle(title: l10n.settingsSectionContent),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: LucideIcons.languages,
                title: l10n.settingsLanguage,
                trailingText: isArabic
                    ? l10n.settingsLanguageArabic
                    : l10n.settingsLanguageEnglish,
                onTap: () => _showLanguageSheet(context, l10n, locale),
              ),
              _SettingsTile(
                icon: LucideIcons.bell,
                title: l10n.settingsNotifications,
                onTap: () => context.pushNamed('notifications'),
              ),
              _SettingsTile(
                icon: LucideIcons.moon,
                title: l10n.settingsDarkMode,
                trailingText: isDark ? l10n.settingsOn : l10n.settingsOff,
                onTap: () => _showThemeSheet(context, l10n, themeMode),
              ),
              _SettingsTile(
                icon: LucideIcons.messageCircle,
                title: l10n.settingsChatWallpaper,
                onTap: () => context.pushNamed('chat_wallpaper_settings'),
              ),
            ],
          ),
          const SizedBox(height: SettingsLayoutConstants.groupSpacing),
          BlocBuilder<AuthBloc, AuthState>(
            buildWhen: (previous, current) =>
                previous.runtimeType != current.runtimeType ||
                (current is AuthSuccess &&
                    previous is AuthSuccess &&
                    previous.user.roles != current.user.roles),
            builder: (context, authState) {
              if (authState is! AuthSuccess ||
                  !userHasAdminRole(authState.user.roles)) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsSectionTitle(title: l10n.settingsSectionAdmin),
                  _SettingsGroup(
                    children: [
                      _SettingsTile(
                        icon: LucideIcons.activity,
                        title: l10n.settingsAdminActivity,
                        onTap: () => context.pushNamed('admin_user_activity'),
                      ),
                    ],
                  ),
                  const SizedBox(height: SettingsLayoutConstants.groupSpacing),
                ],
              );
            },
          ),
          _SettingsSectionTitle(title: l10n.settingsSectionSupport),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: LucideIcons.lifeBuoy,
                title: l10n.settingsHelpCenter,
                onTap: () => _showComingSoon(context, l10n),
              ),
              _SettingsTile(
                icon: LucideIcons.info,
                title: l10n.settingsAbout,
                onTap: () => _showComingSoon(context, l10n),
              ),
            ],
          ),
          const SizedBox(height: SettingsLayoutConstants.logoutTopSpacing),
          _SettingsGroup(
            children: [
              ListTile(
                onTap: () => _confirmLogout(context, l10n),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: SettingsLayoutConstants.tileVerticalPadding,
                ),
                title: Center(
                  child: CustomText(
                    l10n.settingsLogout,
                    color: SettingsLayoutConstants.logoutColor,
                    fontSize: SettingsLayoutConstants.logoutFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SettingsLayoutConstants.bottomSpacing),
        ],
      ),
    );
  }

  void _openPlaceholder(BuildContext context, String title) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SettingsPlaceholderScreen(title: title),
      ),
    );
  }

  void _showComingSoon(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.settingsComingSoon),
        behavior: SnackBarBehavior.floating,
        backgroundColor: theme.colorScheme.inverseSurface,
      ),
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor,
        title: Text(l10n.settingsLogoutTitle),
        content: Text(l10n.settingsLogoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.settingsLogout,
              style: const TextStyle(
                color: SettingsLayoutConstants.logoutColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    context.read<AuthBloc>().add(const LogoutRequestedEvent());
    context.go('/');
  }

  void _showLanguageSheet(
    BuildContext context,
    AppLocalizations l10n,
    Locale locale,
  ) {
    GlassBottomSheet.showActions<void>(
      context,
      title: l10n.settingsSelectLanguage,
      children: [
        GlassBottomSheetListTile(
          label: l10n.settingsLanguageEnglish,
          isSelected: locale.languageCode == 'en',
          onTap: () {
            context.read<LocaleCubit>().changeLanguage('en');
            Navigator.pop(context);
          },
        ),
        GlassBottomSheetListTile(
          label: l10n.settingsLanguageArabic,
          isSelected: locale.languageCode == 'ar',
          onTap: () {
            context.read<LocaleCubit>().changeLanguage('ar');
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  void _showThemeSheet(
    BuildContext context,
    AppLocalizations l10n,
    ThemeMode themeMode,
  ) {
    GlassBottomSheet.showActions<void>(
      context,
      title: l10n.settingsAppearance,
      children: [
        GlassBottomSheetListTile(
          label: l10n.settingsLightMode,
          isSelected: themeMode == ThemeMode.light,
          onTap: () {
            context.read<ThemeCubit>().setThemeMode(ThemeMode.light);
            Navigator.pop(context);
          },
        ),
        GlassBottomSheetListTile(
          label: l10n.settingsDarkModeOption,
          isSelected: themeMode == ThemeMode.dark,
          onTap: () {
            context.read<ThemeCubit>().setThemeMode(ThemeMode.dark);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SettingsLayoutConstants.sectionTitleHorizontalPadding,
        SettingsLayoutConstants.sectionTitleTopPadding,
        SettingsLayoutConstants.sectionTitleHorizontalPadding,
        SettingsLayoutConstants.sectionTitleBottomPadding,
      ),
      child: CustomText(
        title,
        fontSize: SettingsLayoutConstants.sectionTitleFontSize,
        fontWeight: FontWeight.w600,
        variant: TextVariant.secondary,
        color: theme.textTheme.bodyLarge?.color?.withValues(
          alpha: SettingsLayoutConstants.sectionTitleColorAlpha,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(
          SettingsLayoutConstants.groupRadius,
        ),
        border: Border.all(
          color: SettingsLayoutConstants.groupBorderColor(theme),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: SettingsLayoutConstants.appBarDividerHeight,
                indent: SettingsLayoutConstants.dividerIndent,
                endIndent: SettingsLayoutConstants.dividerEndIndent,
                color: SettingsLayoutConstants.groupDividerColor(theme),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailingText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SettingsLayoutConstants.tileHorizontalPadding,
        vertical: SettingsLayoutConstants.tileVerticalPadding,
      ),
      leading: Container(
        padding: const EdgeInsets.all(
          SettingsLayoutConstants.iconContainerPadding,
        ),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(
            alpha: SettingsLayoutConstants.iconBackgroundAlpha,
          ),
          borderRadius: BorderRadius.circular(
            SettingsLayoutConstants.iconContainerRadius,
          ),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: SettingsLayoutConstants.leadingIconSize,
        ),
      ),
      title: CustomText(
        title,
        fontSize: SettingsLayoutConstants.itemTitleFontSize,
        fontWeight: FontWeight.w400,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            CustomText(
              trailingText!,
              fontSize: SettingsLayoutConstants.trailingFontSize,
              variant: TextVariant.secondary,
              color: theme.textTheme.bodyLarge?.color?.withValues(
                alpha: SettingsLayoutConstants.trailingTextAlpha,
              ),
            ),
          const SizedBox(width: SettingsLayoutConstants.chevronGap),
          Icon(
            isRtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
            color: theme.textTheme.bodyLarge?.color?.withValues(
              alpha: SettingsLayoutConstants.chevronAlpha,
            ),
            size: SettingsLayoutConstants.chevronSize,
          ),
        ],
      ),
    );
  }
}
