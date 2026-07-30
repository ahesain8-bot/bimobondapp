import 'package:bimobondapp/app/home/presentation/utils/post_options_actions.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_share_destinations.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_share_people.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_share_tracker.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style "Send to" share + options sheet (tap share).
class PostOptionsSheet {
  PostOptionsSheet._();

  static Future<void> show(
    BuildContext context, {
    required PostEntity post,
    required bool isOwner,
    VoidCallback? onEdit,
    VoidCallback? onPromote,
    VoidCallback? onDelete,
    VoidCallback? onCancelAuction,
    VoidCallback? onRepost,
    bool isReposted = false,
  }) {
    final sheetTheme = Theme.of(context);
    return GlassBottomSheet.showContent<void>(
      context,
      isScrollControlled: true,
      showHandle: true,
      lightSurface: true,
      child: Theme(
        data: sheetTheme,
        child: _PostOptionsSheetContent(
          post: post,
          isOwner: isOwner,
          onEdit: onEdit,
          onPromote: onPromote,
          onDelete: onDelete,
          onCancelAuction: onCancelAuction,
          onRepost: onRepost,
          isReposted: isReposted,
        ),
      ),
    );
  }
}

class _PostOptionsSheetContent extends StatefulWidget {
  const _PostOptionsSheetContent({
    required this.post,
    required this.isOwner,
    this.onEdit,
    this.onPromote,
    this.onDelete,
    this.onCancelAuction,
    this.onRepost,
    this.isReposted = false,
  });

  final PostEntity post;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onPromote;
  final VoidCallback? onDelete;
  final VoidCallback? onCancelAuction;
  final VoidCallback? onRepost;
  final bool isReposted;

  @override
  State<_PostOptionsSheetContent> createState() =>
      _PostOptionsSheetContentState();
}

class _PostOptionsSheetContentState extends State<_PostOptionsSheetContent> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<SocialUserEntity> _allPeople = const [];
  bool _loadingPeople = true;
  bool _searchOpen = false;
  final Set<String> _selected = {};
  final Set<String> _sentTo = {};
  bool _sending = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
    _loadPeople();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    final people = await PostSharePeopleLoader.load(limit: 80);
    if (!mounted) return;
    setState(() {
      _allPeople = people;
      _loadingPeople = false;
    });
  }

  List<SocialUserEntity> get _horizontalPeople {
    return _allPeople.take(20).toList(growable: false);
  }

  List<SocialUserEntity> get _searchListPeople {
    return PostSharePeopleLoader.filter(_allPeople, _query, limit: 60);
  }

  void _toggleUser(SocialUserEntity user) {
    if (_sentTo.contains(user.id) || _sending) return;
    setState(() {
      if (_selected.contains(user.id)) {
        _selected.remove(user.id);
      } else {
        _selected.add(user.id);
      }
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _sendSelected() async {
    if (_selected.isEmpty || _sending) return;
    if (!PostShareSender.ensureLoggedIn(context)) return;

    setState(() => _sending = true);
    final l10n = AppLocalizations.of(context)!;
    final targets = _allPeople.where((u) => _selected.contains(u.id)).toList();
    var sentCount = 0;

    for (final user in targets) {
      final ok = await PostShareSender.shareWithUser(
        context: context,
        post: widget.post,
        user: user,
      );
      if (!mounted) return;
      if (ok) {
        sentCount++;
        _sentTo.add(user.id);
        _selected.remove(user.id);
      }
    }

    if (!mounted) return;
    if (sentCount > 0) {
      await PostShareTracker.trackAndResolveLink(
        widget.post,
        channel: 'CHAT',
      );
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (sentCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.postShareSentCount(sentCount))),
      );
    }
  }

  Future<String> _trackedLink(String channel) {
    return PostShareTracker.trackAndResolveLink(
      widget.post,
      channel: channel,
    );
  }

  List<_CircleAction> _buildAppActions(AppLocalizations l10n) {
    return [
      if (!widget.isOwner && widget.onRepost != null)
        _CircleAction(
          label: widget.isReposted ? l10n.repostUndo : l10n.repostAction,
          background: const Color(0xFFFACC15),
          icon: LucideIcons.repeat2,
          iconColor: Colors.black87,
          onTap: () {
            Navigator.pop(context);
            widget.onRepost!();
          },
        ),
      _CircleAction(
        label: l10n.postShareWhatsApp,
        background: const Color(0xFF25D366),
        assetPath: AppAssets.shareWhatsAppIcon,
        onTap: () async {
          final link = await _trackedLink('EXTERNAL');
          if (!mounted) return;
          await PostShareDestinations.whatsApp(link);
        },
      ),
      _CircleAction(
        label: l10n.postShareCopyLink,
        background: const Color(0xFF3B82F6),
        icon: LucideIcons.link,
        iconColor: Colors.white,
        onTap: () async {
          final link = await _trackedLink('COPY_LINK');
          if (!mounted) return;
          await PostShareDestinations.copyLink(link);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.postLinkCopied)),
          );
        },
      ),
      _CircleAction(
        label: l10n.postShareTelegram,
        background: const Color(0xFF2AABEE),
        assetPath: AppAssets.shareTelegramIcon,
        onTap: () async {
          final link = await _trackedLink('EXTERNAL');
          if (!mounted) return;
          await PostShareDestinations.telegram(link);
        },
      ),
      _CircleAction(
        label: l10n.postShareMessenger,
        background: const Color(0xFF0084FF),
        assetPath: AppAssets.shareMessengerIcon,
        onTap: () async {
          final link = await _trackedLink('EXTERNAL');
          if (!mounted) return;
          await PostShareDestinations.messenger(link);
        },
      ),
      _CircleAction(
        label: l10n.postShareMore,
        background: Theme.of(context).colorScheme.surfaceContainerHighest,
        icon: LucideIcons.ellipsis,
        iconColor: Theme.of(context).colorScheme.onSurface,
        onTap: () async {
          final link = await _trackedLink('EXTERNAL');
          if (!mounted) return;
          await PostShareDestinations.systemShare(link);
        },
      ),
    ];
  }

  List<_CircleAction> _buildOptionActions(PostOptionsActions actions) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final mutedBg = theme.colorScheme.surfaceContainerHighest;
    final onSurface = theme.colorScheme.onSurface;

    return [
      if (!widget.isOwner)
        _CircleAction(
          label: l10n.postOptionReport,
          background: mutedBg,
          icon: LucideIcons.flag,
          iconColor: onSurface,
          onTap: () {
            Navigator.pop(context);
            actions.report();
          },
        ),
      if (!widget.isOwner)
        _CircleAction(
          label: l10n.postOptionNotInterested,
          background: mutedBg,
          icon: LucideIcons.heartOff,
          iconColor: onSurface,
          onTap: () {
            Navigator.pop(context);
            actions.notInterested();
          },
        ),
      _CircleAction(
        label: l10n.postOptionAddToStory,
        background: mutedBg,
        icon: LucideIcons.circlePlus,
        iconColor: onSurface,
        onTap: () {
          Navigator.pop(context);
          actions.addToStory();
        },
      ),
      if (widget.isOwner &&
          widget.onPromote != null &&
          widget.post.canBePromoted)
        _CircleAction(
          label: l10n.promotePostAction,
          background: mutedBg,
          icon: LucideIcons.flame,
          iconColor: onSurface,
          onTap: () {
            Navigator.pop(context);
            widget.onPromote!();
          },
        ),
      _CircleAction(
        label: l10n.postOptionShareAsGif,
        background: mutedBg,
        icon: LucideIcons.film,
        iconColor: onSurface,
        onTap: () {
          Navigator.pop(context);
          actions.shareAsGif();
        },
      ),
      _CircleAction(
        label: l10n.postOptionDownload,
        background: mutedBg,
        icon: LucideIcons.download,
        iconColor: onSurface,
        onTap: () {
          Navigator.pop(context);
          actions.download();
        },
      ),
      if (widget.isOwner && widget.onEdit != null)
        _CircleAction(
          label: l10n.editPost,
          background: mutedBg,
          icon: LucideIcons.pencil,
          iconColor: onSurface,
          onTap: () {
            Navigator.pop(context);
            widget.onEdit!();
          },
        ),
      if (widget.isOwner && widget.onCancelAuction != null)
        _CircleAction(
          label: l10n.auctionCancelAction,
          background: mutedBg,
          icon: LucideIcons.ban,
          iconColor: onSurface,
          onTap: () {
            Navigator.pop(context);
            widget.onCancelAuction!();
          },
        ),
      if (widget.isOwner && widget.onDelete != null)
        _CircleAction(
          label: l10n.deletePost,
          background: mutedBg,
          icon: LucideIcons.trash2,
          iconColor: theme.colorScheme.error,
          onTap: () {
            Navigator.pop(context);
            widget.onDelete!();
          },
        ),
    ];
  }

  Widget _titleBar({
    required AppLocalizations l10n,
    Widget? leading,
    VoidCallback? onClose,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 16,
      color: onSurface,
    );

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: leading ?? const SizedBox.shrink(),
          ),
          Expanded(
            child: Text(
              l10n.postShareSendToTitle,
              textAlign: TextAlign.center,
              style: titleStyle,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: onClose ?? () => Navigator.pop(context),
            icon: Icon(LucideIcons.x, size: 20, color: onSurface),
          ),
        ],
      ),
    );
  }

  Widget _searchTitleBar(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 16,
      color: onSurface,
    );

    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(l10n.postShareSendToTitle, style: titleStyle),
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: () => Navigator.pop(context),
              icon: Icon(LucideIcons.x, size: 20, color: onSurface),
            ),
          ),
        ],
      ),
    );
  }

  /// Elevated fill for the search pill (light gray / dark gray from [ColorScheme]).
  Color _searchFieldFill(ColorScheme cs) {
    return cs.brightness == Brightness.light
        ? cs.surfaceContainerHighest
        : cs.surfaceContainerHigh;
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: _searchFieldFill(cs),
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              LucideIcons.search,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                cursorColor: cs.primary,
                decoration: InputDecoration(
                  hintText: l10n.postShareSearchHint,
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(AppLocalizations l10n, {bool compact = false}) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(top: compact ? 6 : AppSizes.p10),
      child: SizedBox(
        height: compact ? 42 : 48,
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _sending ? null : _sendSelected,
          child: _sending
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : Text(
                  l10n.postShareSendToCount(_selected.length),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 16,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFriendSearchList(AppLocalizations l10n) {
    final people = _searchListPeople;
    final theme = Theme.of(context);
    if (_loadingPeople) {
      return const Center(child: CustomLoadingWidget(size: 40));
    }
    if (people.isEmpty) {
      return Center(
        child: Text(
          l10n.postShareNoUsers,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      itemCount: people.length,
      itemBuilder: (context, index) {
        final user = people[index];
        return _FriendSearchRow(
          user: user,
          friendsLabel: l10n.friendsLabel,
          selected: _selected.contains(user.id),
          sent: _sentTo.contains(user.id),
          showFriendsRelation: _query.isEmpty,
          onTap: () => _toggleUser(user),
        );
      },
    );
  }

  Widget _buildSearchMode(AppLocalizations l10n) {
    final screenH = MediaQuery.sizeOf(context).height;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final theme = Theme.of(context);
    final panelHeight = screenH * 0.88;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: panelHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.p16,
          0,
          AppSizes.p16,
          6 + viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchTitleBar(l10n),
            const SizedBox(height: 8),
            _buildSearchField(l10n),
            const SizedBox(height: 8),
            Text(
              l10n.postShareRecentChats,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(child: _buildFriendSearchList(l10n)),
            if (_selected.isNotEmpty) _buildSendButton(l10n, compact: true),
          ],
        ),
      ),
    );
  }

  Widget _horizontalActions(List<_CircleAction> actions) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _CircleActionButton(action: action);
        },
      ),
    );
  }

  void _openSearchMode() {
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    if (_searchOpen) {
      return _buildSearchMode(l10n);
    }

    final actions = PostOptionsActions(context, widget.post);
    final appActions = _buildAppActions(l10n);
    final optionActions = _buildOptionActions(actions);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p12,
        0,
        AppSizes.p12,
        AppSizes.p8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titleBar(
            l10n: l10n,
            leading: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: _openSearchMode,
              icon: Icon(LucideIcons.search, size: 20, color: onSurface),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 88,
            child: _loadingPeople
                ? const Center(child: CustomLoadingWidget(size: 36))
                : _horizontalPeople.isEmpty
                ? Center(
                    child: Text(
                      l10n.postShareNoUsers,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _horizontalPeople.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final user = _horizontalPeople[index];
                      return _FriendShareAvatar(
                        user: user,
                        selected: _selected.contains(user.id),
                        sent: _sentTo.contains(user.id),
                        onTap: () => _toggleUser(user),
                      );
                    },
                  ),
          ),
          if (_selected.isNotEmpty) _buildSendButton(l10n, compact: true),
          const SizedBox(height: 8),
          _horizontalActions(appActions),
          const SizedBox(height: 6),
          _horizontalActions(optionActions),
        ],
      ),
    );
  }
}

class _FriendSearchRow extends StatelessWidget {
  const _FriendSearchRow({
    required this.user,
    required this.friendsLabel,
    required this.selected,
    required this.sent,
    required this.onTap,
    this.showFriendsRelation = false,
  });

  final SocialUserEntity user;
  final String friendsLabel;
  final bool selected;
  final bool sent;
  final VoidCallback onTap;
  final bool showFriendsRelation;

  bool get _showFriendsBadge {
    if (showFriendsRelation) {
      return user.isFollowing || user.isFollowedBy;
    }
    return user.isFollowing && user.isFollowedBy;
  }

  static const _onlineGreen = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final username = user.username?.trim();
    final handle = username != null && username.isNotEmpty
        ? (username.startsWith('@') ? username : '@$username')
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: sent ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SafeNetworkAvatar(
                    imageUrl: user.avatarUrl,
                    fallbackText: user.displayName,
                    radius: 22,
                  ),
                  if (user.isActive == true)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _onlineGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                        children: [
                          TextSpan(text: user.displayName),
                          if (_showFriendsBadge)
                            TextSpan(
                              text: ' • $friendsLabel',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (handle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SelectionRing(selected: selected, sent: sent, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionRing extends StatelessWidget {
  const _SelectionRing({
    required this.selected,
    required this.sent,
    this.compact = false,
  });

  final bool selected;
  final bool sent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sentColor = cs.tertiary;
    final size = compact ? 22.0 : 26.0;
    final iconSize = compact ? 14.0 : 16.0;

    if (sent) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: sentColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.check, size: iconSize, color: cs.onTertiary),
      );
    }
    if (selected) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.check, size: iconSize, color: cs.onPrimary),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
    );
  }
}

class _CircleAction {
  const _CircleAction({
    required this.label,
    required this.background,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.assetPath,
  });

  final String label;
  final Color background;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final String? assetPath;
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({required this.action});

  final _CircleAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: onSurface.withValues(alpha: 0.85),
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

    return SizedBox(
      width: 60,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: action.background,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: action.assetPath != null
                  ? SvgPicture.asset(
                      action.assetPath!,
                      width: 22,
                      height: 22,
                    )
                  : Icon(
                      action.icon,
                      size: 20,
                      color: action.iconColor ?? onSurface,
                    ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 26,
              width: 60,
              child: Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: labelStyle?.copyWith(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendShareAvatar extends StatelessWidget {
  const _FriendShareAvatar({
    required this.user,
    required this.selected,
    required this.sent,
    required this.onTap,
  });

  final SocialUserEntity user;
  final bool selected;
  final bool sent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sentColor = cs.tertiary;
    final ring = sent
        ? sentColor
        : selected
        ? cs.primary
        : Colors.transparent;
    final badgeBorder = cs.surface;

    return SizedBox(
      width: 56,
      child: InkWell(
        onTap: sent ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: 2),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SafeNetworkAvatar(
                    imageUrl: user.avatarUrl,
                    fallbackText: user.displayName,
                    radius: 21,
                  ),
                  if (selected || sent)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: sent ? sentColor : cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: badgeBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 11,
                          color: sent ? cs.onTertiary : cs.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 24,
              width: 56,
              child: Text(
                user.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
