import 'package:bimobondapp/app/home/presentation/utils/post_options_actions.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_share_destinations.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_share_people.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_share_tracker.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
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
          hostContext: context,
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
    this.hostContext,
    this.onEdit,
    this.onPromote,
    this.onDelete,
    this.onCancelAuction,
    this.onRepost,
    this.isReposted = false,
  });

  final BuildContext? hostContext;
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
      await PostShareTracker.trackAndResolveLink(widget.post, channel: 'CHAT');
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
    return PostShareTracker.trackAndResolveLink(widget.post, channel: channel);
  }

  List<_CircleAction> _buildExternalShareActions(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final mutedBg = AppTheme.shareIconMutedBackground(cs);
    final showRepost = !widget.isOwner && widget.onRepost != null;
    return [
      if (showRepost)
        _CircleAction(
          label: widget.isReposted ? l10n.repostUndo : l10n.repostAction,
          background: AppTheme.shareRepostBackground,
          assetPath: AppAssets.repostIcon,
          iconColor: Colors.white,
          onTap: () {
            Navigator.pop(context);
            widget.onRepost!();
          },
        ),
      _CircleAction(
        label: l10n.postShareCopyLink,
        background: Color.lerp(cs.secondary, Colors.white, 0.38)!,
        icon: LucideIcons.link,
        iconColor: Colors.white,
        onTap: () async {
          final link = await _trackedLink('COPY_LINK');
          if (!mounted) return;
          await PostShareDestinations.copyLink(link);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.postLinkCopied)));
        },
      ),
      _CircleAction(
        label: l10n.postShareInstagram,
        background: Colors.transparent,
        assetPath: AppAssets.shareInstagramIcon,
        assetSize: 52,
        clipAssetToCircle: true,
        onTap: () async {
          final link = await _trackedLink('EXTERNAL');
          if (!mounted) return;
          await PostShareDestinations.instagram(link);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.postShareInstagramHint)));
        },
      ),
      _CircleAction(
        label: l10n.postShareFacebook,
        background: Colors.transparent,
        assetPath: AppAssets.shareFacebookIcon,
        assetSize: 52,
        clipAssetToCircle: true,
        onTap: () async {
          final link = await _trackedLink('EXTERNAL');
          if (!mounted) return;
          await PostShareDestinations.facebook(link);
        },
      ),
      _CircleAction(
        label: l10n.postShareWhatsApp,
        background: Colors.transparent,
        assetPath: AppAssets.shareWhatsAppIcon,
        assetSize: 52,
        clipAssetToCircle: true,
        onTap: () async {
          final link = await _trackedLink('EXTERNAL');
          if (!mounted) return;
          await PostShareDestinations.whatsApp(link);
        },
      ),
      _CircleAction(
        label: l10n.postShareMessenger,
        background: Colors.transparent,
        assetPath: AppAssets.shareMessengerIcon,
        assetSize: 52,
        clipAssetToCircle: true,
        onTap: () async {
          final link = await _trackedLink('EXTERNAL');
          if (!mounted) return;
          await PostShareDestinations.messenger(link);
        },
      ),
      _CircleAction(
        label: l10n.postShareTelegram,
        background: Colors.transparent,
        assetPath: AppAssets.shareTelegramIcon,
        assetSize: 52,
        clipAssetToCircle: true,
        onTap: () async {
          final link = await _trackedLink('EXTERNAL');
          if (!mounted) return;
          await PostShareDestinations.telegram(link);
        },
      ),
      _CircleAction(
        label: l10n.postShareMore,
        background: mutedBg,
        icon: LucideIcons.ellipsis,
        iconColor: cs.onSurface,
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
    final cs = Theme.of(context).colorScheme;
    final mutedBg = AppTheme.shareIconMutedBackground(cs);
    final onMuted = cs.onSurface;

    return [
      if (!widget.isOwner)
        _CircleAction(
          label: l10n.postOptionReport,
          background: mutedBg,
          icon: LucideIcons.flag,
          iconColor: onMuted,
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
          iconColor: onMuted,
          onTap: () {
            Navigator.pop(context);
            actions.notInterested();
          },
        ),
      _CircleAction(
        label: l10n.postOptionDownload,
        background: mutedBg,
        icon: LucideIcons.download,
        iconColor: onMuted,
        onTap: () {
          Navigator.pop(context);
          actions.download();
        },
      ),
      _CircleAction(
        label: l10n.postOptionAddToStory,
        background: mutedBg,
        icon: LucideIcons.circlePlus,
        iconColor: onMuted,
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
          iconColor: onMuted,
          onTap: () {
            Navigator.pop(context);
            widget.onPromote!();
          },
        ),
      _CircleAction(
        label: l10n.postOptionCast,
        background: mutedBg,
        icon: LucideIcons.cast,
        iconColor: onMuted,
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(widget.hostContext ?? context).showSnackBar(
            SnackBar(content: Text(l10n.postOptionCastUnavailable)),
          );
        },
      ),
      _CircleAction(
        label: l10n.postOptionShareAsGif,
        background: mutedBg,
        icon: LucideIcons.film,
        iconColor: onMuted,
        onTap: () {
          Navigator.pop(context);
          actions.shareAsGif();
        },
      ),
      if (widget.isOwner && widget.onEdit != null)
        _CircleAction(
          label: l10n.editPost,
          background: mutedBg,
          icon: LucideIcons.pencil,
          iconColor: onMuted,
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
          iconColor: onMuted,
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
          iconColor: cs.error,
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

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(width: 40, child: leading ?? const SizedBox.shrink()),
          Expanded(
            child: CustomText(
              l10n.postShareSendToTitle,
              textAlign: TextAlign.center,
              fontSize: 16,
              fontWeight: FontWeight.w700,
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

    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomText(
            l10n.postShareSendToTitle,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
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
            Icon(LucideIcons.search, size: 18, color: cs.onSurfaceVariant),
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
    if (_loadingPeople) {
      return const Center(child: CustomLoadingWidget(size: 40));
    }
    if (people.isEmpty) {
      return Center(
        child: CustomText(
          l10n.postShareNoUsers,
          variant: TextVariant.muted,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final bottomSafe = keyboard > 0 ? 0.0 : media.padding.bottom;
    // Sit above the keyboard at 80% of the visible area (not full screen).
    final availableHeight = (media.size.height - keyboard).clamp(280.0, media.size.height);
    final panelHeight = availableHeight * 0.80;

    return SizedBox(
      height: panelHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.p16,
          0,
          AppSizes.p16,
          bottomSafe > 0 ? bottomSafe : AppSizes.p6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchTitleBar(l10n),
            const SizedBox(height: AppSizes.p8),
            _buildSearchField(l10n),
            const SizedBox(height: AppSizes.p8),
            CustomText(
              l10n.postShareRecentChats,
              variant: TextVariant.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            const SizedBox(height: AppSizes.p6),
            Expanded(child: _buildFriendSearchList(l10n)),
            if (_selected.isNotEmpty) _buildSendButton(l10n, compact: true),
          ],
        ),
      ),
    );
  }

  Widget _horizontalActions(List<_CircleAction> actions) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _CircleActionButton(action: action);
        },
      ),
    );
  }

  Widget _buildSendToRow(AppLocalizations l10n) {
    final people = _horizontalPeople;
    final itemCount = _loadingPeople ? 0 : people.length;

    if (_loadingPeople) {
      return const SizedBox(
        height: 92,
        child: Center(child: CustomLoadingWidget(size: 36)),
      );
    }

    if (people.isEmpty) {
      return SizedBox(
        height: 92,
        child: Center(
          child: CustomText(
            l10n.postShareNoUsers,
            variant: TextVariant.muted,
            fontSize: 12,
          ),
        ),
      );
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final user = people[index];
          return _FriendShareAvatar(
            user: user,
            selected: _selected.contains(user.id),
            sent: _sentTo.contains(user.id),
            onTap: () => _toggleUser(user),
          );
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

    final actions =
        PostOptionsActions(widget.hostContext ?? context, widget.post);
    final externalActions = _buildExternalShareActions(l10n);
    final optionActions = _buildOptionActions(actions);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        0,
        AppSizes.p16,
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
              icon: Icon(LucideIcons.search, size: 22, color: onSurface),
            ),
          ),
          const SizedBox(height: 10),
          // Row 1 — friends (Send to)
          _buildSendToRow(l10n),
          if (_selected.isNotEmpty) _buildSendButton(l10n, compact: true),
          const SizedBox(height: 14),
          // Row 2 — Repost + external apps
          _horizontalActions(externalActions),
          const SizedBox(height: 10),
          // Row 3 — in-app actions
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
          padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
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
                          color: cs.tertiary,
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
        decoration: BoxDecoration(color: sentColor, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(Icons.check, size: iconSize, color: cs.onTertiary),
      );
    }
    if (selected) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
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
    this.assetSize = 24,
    this.clipAssetToCircle = false,
  });

  final String label;
  final Color background;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final String? assetPath;
  final double assetSize;
  final bool clipAssetToCircle;
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({required this.action});

  final _CircleAction action;

  Widget _buildAssetIcon(_CircleAction action) {
    Widget svg = SvgPicture.asset(
      action.assetPath!,
      width: action.assetSize,
      height: action.assetSize,
      fit: BoxFit.cover,
      colorFilter: action.iconColor != null
          ? ColorFilter.mode(action.iconColor!, BlendMode.srcIn)
          : null,
    );
    if (action.clipAssetToCircle) {
      return ClipOval(child: svg);
    }
    return svg;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: action.background,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: action.assetPath != null
                  ? _buildAssetIcon(action)
                  : Icon(
                      action.icon,
                      size: 22,
                      color: action.iconColor ?? cs.onSurface,
                    ),
            ),
            const SizedBox(height: AppSizes.p6),
            SizedBox(
              height: 28,
              width: 64,
              child: Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
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
      width: 64,
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
                    radius: 24,
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
                          border: Border.all(color: badgeBorder, width: 1.5),
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
            const SizedBox(height: 4),
            SizedBox(
              height: 26,
              width: 64,
              child: Text(
                user.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
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
