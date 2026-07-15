import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
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

String localizedAddPostPrivacyRowLabel(String status, AppLocalizations l10n) {
  switch (status) {
    case 'PUBLIC':
      return l10n.everyoneCanViewPost;
    case 'FRIENDS':
      return l10n.friendsCanViewPost;
    case 'PRIVATE':
      return l10n.onlyYouCanViewPost;
    default:
      return localizedAddPostPrivacyStatus(status, l10n);
  }
}

/// TikTok-style post settings sheet (who can view + video privacy).
class AddPostSettingsSheet {
  AddPostSettingsSheet._();

  static Future<void> show(
    BuildContext context, {
    required String privacyStatus,
    required bool allowComments,
    required bool allowReuse,
    required ValueChanged<String> onPrivacyChanged,
    required ValueChanged<bool> onAllowCommentsChanged,
    required ValueChanged<bool> onAllowReuseChanged,
  }) {
    return GlassBottomSheet.showDraggable<void>(
      context,
      initialChildSize: 0.68,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      lightSurface: true,
      showHandle: true,
      builder: (context, _) => _AddPostSettingsBody(
        privacyStatus: privacyStatus,
        allowComments: allowComments,
        allowReuse: allowReuse,
        onPrivacyChanged: onPrivacyChanged,
        onAllowCommentsChanged: onAllowCommentsChanged,
        onAllowReuseChanged: onAllowReuseChanged,
      ),
    );
  }
}

class _AddPostSettingsBody extends StatefulWidget {
  const _AddPostSettingsBody({
    required this.privacyStatus,
    required this.allowComments,
    required this.allowReuse,
    required this.onPrivacyChanged,
    required this.onAllowCommentsChanged,
    required this.onAllowReuseChanged,
  });

  final String privacyStatus;
  final bool allowComments;
  final bool allowReuse;
  final ValueChanged<String> onPrivacyChanged;
  final ValueChanged<bool> onAllowCommentsChanged;
  final ValueChanged<bool> onAllowReuseChanged;

  @override
  State<_AddPostSettingsBody> createState() => _AddPostSettingsBodyState();
}

class _AddPostSettingsBodyState extends State<_AddPostSettingsBody> {
  late String _privacy;
  late bool _comments;
  late bool _reuse;

  @override
  void initState() {
    super.initState();
    _privacy = widget.privacyStatus;
    _comments = widget.allowComments;
    _reuse = widget.allowReuse;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final cardColor = theme.brightness == Brightness.dark
        ? const Color(0xFF2A2A2D)
        : const Color(0xFFF1F1F2);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(
                    l10n.addPostSettingsTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    LucideIcons.x,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.whoCanWatchLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PrivacyRadioTile(
                        label: l10n.everyoneLabel,
                        selected: _privacy == 'PUBLIC',
                        onTap: () {
                          setState(() => _privacy = 'PUBLIC');
                          widget.onPrivacyChanged('PUBLIC');
                        },
                      ),
                      _PrivacyRadioTile(
                        label: l10n.friendsLabel,
                        subtitle: l10n.friendsPrivacySubtitle,
                        selected: _privacy == 'FRIENDS',
                        onTap: () {
                          setState(() => _privacy = 'FRIENDS');
                          widget.onPrivacyChanged('FRIENDS');
                        },
                      ),
                      _PrivacyRadioTile(
                        label: l10n.onlyMeLabel,
                        selected: _privacy == 'PRIVATE',
                        onTap: () {
                          setState(() => _privacy = 'PRIVATE');
                          widget.onPrivacyChanged('PRIVATE');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.videoPrivacySection,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      _ToggleRow(
                        title: l10n.allowCommentsLabel,
                        value: _comments,
                        onChanged: (v) {
                          setState(() => _comments = v);
                          widget.onAllowCommentsChanged(v);
                        },
                      ),
                      Divider(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.25),
                      ),
                      _ToggleRow(
                        title: l10n.allowReuseLabel,
                        subtitle: l10n.allowReuseSubtitle,
                        value: _reuse,
                        onChanged: (v) {
                          setState(() => _reuse = v);
                          widget.onAllowReuseChanged(v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.advancedSettings,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyRadioTile extends StatelessWidget {
  const _PrivacyRadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                ],
              ),
            ),
            _RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (selected) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.p12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: const Color(0xFF57C9FF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
