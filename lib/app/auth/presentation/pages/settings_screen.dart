import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/pages/settings_placeholder_screen.dart';
import 'package:bimobondapp/core/constants/settings_layout_constants.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/theme/cubit/theme_cubit.dart';
import 'package:bimobondapp/core/utils/user_roles.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
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
    final pageBg = SettingsLayoutConstants.pageBackground(theme);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Directionality.of(context) == TextDirection.rtl
                ? LucideIcons.chevronRight
                : LucideIcons.chevronLeft,
            color: onSurface,
            size: 28,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SettingsLayoutConstants.horizontalPadding,
          SettingsLayoutConstants.bodyTopPadding,
          SettingsLayoutConstants.horizontalPadding,
          SettingsLayoutConstants.bottomSpacing,
        ),
        children: [
          Text(
            l10n.settingsAndPrivacy,
            style: TextStyle(
              fontSize: SettingsLayoutConstants.pageTitleFontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.15,
              color: onSurface,
            ),
          ),
          const SizedBox(
            height: SettingsLayoutConstants.pageTitleBottomSpacing,
          ),
          _SettingsSectionTitle(title: l10n.settingsSectionAccount),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: LucideIcons.user,
                title: l10n.editProfile,
                onTap: () => context.pushNamed('personal_info'),
              ),
              _SettingsTile(
                icon: LucideIcons.heart,
                title: l10n.settingsInterests,
                onTap: () => context.pushNamed(
                  'interest_selection',
                  queryParameters: {'mode': 'edit'},
                ),
              ),
              _SettingsTile(
                icon: LucideIcons.lock,
                title: l10n.settingsPrivacy,
                onTap: () => _openPlaceholder(context, l10n.settingsPrivacy),
              ),
              _SettingsTile(
                icon: LucideIcons.shield,
                title: l10n.settingsSecurity,
                onTap: () => _openPlaceholder(context, l10n.settingsSecurity),
              ),
              _SettingsTile(
                icon: LucideIcons.wallet,
                title: l10n.balanceTitle,
                onTap: () => context.pushNamed('balance'),
              ),
              _SettingsTile(
                icon: LucideIcons.circleDollarSign,
                title: l10n.walletTitle,
                onTap: () => context.pushNamed('wallet'),
              ),
            ],
          ),
          const SizedBox(height: SettingsLayoutConstants.groupSpacing),
          _SettingsSectionTitle(title: l10n.settingsSectionContent),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: LucideIcons.bell,
                title: l10n.settingsNotifications,
                onTap: () => context.pushNamed('notifications'),
              ),
              _SettingsTile(
                icon: LucideIcons.languages,
                title: l10n.settingsLanguage,
                trailingText: isArabic
                    ? l10n.settingsLanguageArabic
                    : l10n.settingsLanguageEnglish,
                onTap: () => _showLanguageSheet(context, l10n, locale),
              ),
              _SettingsTile(
                icon: LucideIcons.moon,
                title: l10n.settingsDarkMode,
                trailingText: isDark ? l10n.settingsOn : l10n.settingsOff,
                onTap: () => _showThemeSheet(context, l10n, themeMode),
              ),
              _SettingsTile(
                icon: LucideIcons.megaphone,
                title: l10n.settingsPromotedPosts,
                onTap: () => context.pushNamed('promoted_posts'),
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
              InkWell(
                onTap: () => _confirmLogout(context, l10n),
                borderRadius: BorderRadius.circular(
                  SettingsLayoutConstants.groupRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: SettingsLayoutConstants.tileHorizontalPadding,
                  ),
                  child: Center(
                    child: Text(
                      l10n.settingsLogout,
                      style: const TextStyle(
                        color: SettingsLayoutConstants.logoutColor,
                        fontSize: SettingsLayoutConstants.logoutFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
      child: Text(
        title,
        style: TextStyle(
          fontSize: SettingsLayoutConstants.sectionTitleFontSize,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface.withValues(
            alpha: SettingsLayoutConstants.sectionTitleColorAlpha,
          ),
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

    return Material(
      color: SettingsLayoutConstants.cardBackground(theme),
      borderRadius: BorderRadius.circular(SettingsLayoutConstants.groupRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
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
    final onSurface = theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SettingsLayoutConstants.tileHorizontalPadding,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: SettingsLayoutConstants.leadingIconSize,
              color: SettingsLayoutConstants.iconColor(theme),
            ),
            const SizedBox(width: SettingsLayoutConstants.leadingGap),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: SettingsLayoutConstants.itemTitleFontSize,
                  fontWeight: FontWeight.w400,
                  color: onSurface,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText!,
                style: TextStyle(
                  fontSize: SettingsLayoutConstants.trailingFontSize,
                  color: SettingsLayoutConstants.trailingTextColor(theme),
                ),
              ),
              const SizedBox(width: SettingsLayoutConstants.chevronGap),
            ],
            DirectionalChevronIcon(
              size: SettingsLayoutConstants.chevronSize,
              color: SettingsLayoutConstants.chevronColor(theme),
            ),
          ],
        ),
      ),
    );
  }
}
