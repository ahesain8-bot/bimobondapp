import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/core/constants/settings_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Account privacy settings — mirrors `docs/privacy/mobile-api.md`.
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _saving = false;
  bool? _pendingPrivate;
  bool? _pendingAllowComments;
  String? _pendingMessagePermission;

  UserEntity? get _user {
    final state = context.read<AuthBloc>().state;
    return state is AuthSuccess ? state.user : null;
  }

  bool get _isPrivate =>
      _pendingPrivate ?? (_user?.isPrivate ?? false);

  bool get _allowComments =>
      _pendingAllowComments ?? (_user?.allowComments ?? true);

  String get _messagePermission =>
      (_pendingMessagePermission ?? _user?.resolvedMessagePermission ?? 'EVERYONE')
          .toUpperCase();

  Future<void> _patch(Map<String, dynamic> data) async {
    if (_saving) return;
    setState(() => _saving = true);
    context.read<AuthBloc>().add(UpdateProfileRequestedEvent(data));
  }

  void _onPrivateChanged(bool value) {
    setState(() => _pendingPrivate = value);
    _patch({'isPrivate': value});
  }

  void _onAllowCommentsChanged(bool value) {
    setState(() => _pendingAllowComments = value);
    _patch({'allowComments': value});
  }

  Future<void> _pickMessagePermission() async {
    final l10n = AppLocalizations.of(context)!;
    final options = <(String, String)>[
      ('EVERYONE', l10n.privacyMessageEveryone),
      ('FOLLOWERS', l10n.privacyMessageFollowers),
      ('FRIENDS', l10n.privacyMessageFriends),
      ('NOBODY', l10n.privacyMessageNobody),
    ];

    final selected = await GlassBottomSheet.showActions<String>(
      context,
      title: l10n.privacyWhoCanMessage,
      children: [
        for (final (value, label) in options)
          GlassBottomSheetListTile(
            icon: value == _messagePermission
                ? LucideIcons.circleCheck
                : LucideIcons.circle,
            label: label,
            onTap: () => Navigator.pop(context, value),
          ),
      ],
    );
    if (selected == null || !mounted || selected == _messagePermission) return;

    setState(() => _pendingMessagePermission = selected);
    await _patch({'messagePermission': selected});
  }

  String _messagePermissionLabel(AppLocalizations l10n) {
    switch (_messagePermission) {
      case 'FOLLOWERS':
        return l10n.privacyMessageFollowers;
      case 'FRIENDS':
        return l10n.privacyMessageFriends;
      case 'NOBODY':
        return l10n.privacyMessageNobody;
      case 'EVERYONE':
      default:
        return l10n.privacyMessageEveryone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pageBg = SettingsLayoutConstants.pageBackground(theme);
    final cardBg = SettingsLayoutConstants.cardBackground(theme);

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          curr is AuthSuccess || curr is AuthFailure,
      listener: (context, state) {
        if (!_saving) return;
        setState(() => _saving = false);
        if (state is AuthFailure) {
          setState(() {
            _pendingPrivate = null;
            _pendingAllowComments = null;
            _pendingMessagePermission = null;
          });
          PopupDialogs.showErrorDialog(context, state.message);
          return;
        }
        if (state is AuthSuccess) {
          setState(() {
            _pendingPrivate = null;
            _pendingAllowComments = null;
            _pendingMessagePermission = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.privacyUpdated)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: pageBg,
        appBar: CustomAppBar(
          title: l10n.settingsPrivacy,
          showBackButton: true,
          backgroundColor: pageBg,
          onBackPressed: () => context.pop(),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            SettingsLayoutConstants.horizontalPadding,
            SettingsLayoutConstants.bodyTopPadding,
            SettingsLayoutConstants.horizontalPadding,
            SettingsLayoutConstants.bottomSpacing,
          ),
          children: [
            _SectionTitle(l10n.privacySectionAccount),
            _Group(
              color: cardBg,
              children: [
                _SwitchTile(
                  icon: LucideIcons.lock,
                  title: l10n.privacyPrivateAccount,
                  subtitle: l10n.privacyPrivateAccountSubtitle,
                  value: _isPrivate,
                  enabled: !_saving,
                  onChanged: _onPrivateChanged,
                ),
              ],
            ),
            const SizedBox(height: SettingsLayoutConstants.groupSpacing),
            _SectionTitle(l10n.privacySectionInteractions),
            _Group(
              color: cardBg,
              children: [
                _NavTile(
                  icon: LucideIcons.messageCircle,
                  title: l10n.privacyWhoCanMessage,
                  trailing: _messagePermissionLabel(l10n),
                  enabled: !_saving,
                  onTap: _pickMessagePermission,
                ),
                Divider(
                  height: 1,
                  indent: 54,
                  color: SettingsLayoutConstants.groupBorderColor(theme),
                ),
                _SwitchTile(
                  icon: LucideIcons.messageSquareText,
                  title: l10n.privacyAllowComments,
                  subtitle: l10n.privacyAllowCommentsSubtitle,
                  value: _allowComments,
                  enabled: !_saving,
                  onChanged: _onAllowCommentsChanged,
                ),
              ],
            ),
            if (_saving) ...[
              const SizedBox(height: AppSizes.p16),
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: SettingsLayoutConstants.sectionTitleTopPadding,
        bottom: SettingsLayoutConstants.sectionTitleBottomPadding,
        left: SettingsLayoutConstants.sectionTitleHorizontalPadding,
        right: SettingsLayoutConstants.sectionTitleHorizontalPadding,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: SettingsLayoutConstants.sectionTitleFontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: theme.colorScheme.onSurface.withValues(
            alpha: SettingsLayoutConstants.sectionTitleColorAlpha,
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.color, required this.children});

  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(
          SettingsLayoutConstants.groupRadius,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SettingsLayoutConstants.tileHorizontalPadding,
        vertical: AppSizes.p12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: SettingsLayoutConstants.leadingIconSize,
            color: SettingsLayoutConstants.iconColor(theme),
          ),
          const SizedBox(width: SettingsLayoutConstants.leadingGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title,
                  fontSize: SettingsLayoutConstants.itemTitleFontSize,
                  fontWeight: FontWeight.w500,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  CustomText(
                    subtitle!,
                    fontSize: 13,
                    variant: TextVariant.secondary,
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SettingsLayoutConstants.tileHorizontalPadding,
          vertical: AppSizes.p12,
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
              child: CustomText(
                title,
                fontSize: SettingsLayoutConstants.itemTitleFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
            Flexible(
              child: Text(
                trailing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: SettingsLayoutConstants.trailingFontSize,
                  color: SettingsLayoutConstants.trailingTextColor(theme),
                ),
              ),
            ),
            const SizedBox(width: SettingsLayoutConstants.chevronGap),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? LucideIcons.chevronLeft
                  : LucideIcons.chevronRight,
              size: SettingsLayoutConstants.chevronSize,
              color: SettingsLayoutConstants.chevronColor(theme),
            ),
          ],
        ),
      ),
    );
  }
}
