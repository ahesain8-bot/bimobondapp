import 'package:bimobondapp/app/home/presentation/utils/post_options_actions.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_share_destinations.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_share_people.dart';
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
    VoidCallback? onRepost,
    bool isReposted = false,
  }) {
    return GlassBottomSheet.open<void>(
      context,
      isScrollControlled: true,
      builder: (ctx) => GlassBottomSheetShell(
        showHandle: true,
        lightSurface: true,
        child: _PostOptionsSheetContent(
          post: post,
          isOwner: isOwner,
          onEdit: onEdit,
          onPromote: onPromote,
          onDelete: onDelete,
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
    this.onRepost,
    this.isReposted = false,
  });

  final PostEntity post;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onPromote;
  final VoidCallback? onDelete;
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

  String get _link => PostShareLink.forPost(widget.post);

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

  List<SocialUserEntity> get _visiblePeople {
    return PostSharePeopleLoader.filter(_allPeople, _query, limit: 24);
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
    setState(() => _sending = false);
    if (sentCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.postShareSentCount(sentCount))),
      );
    }
  }

  List<_CircleAction> _buildAppActions(AppLocalizations l10n, String link) {
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
        onTap: () => PostShareDestinations.whatsApp(link),
      ),
      _CircleAction(
        label: l10n.postShareCopyLink,
        background: const Color(0xFF3B82F6),
        icon: LucideIcons.link,
        iconColor: Colors.white,
        onTap: () async {
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
        onTap: () => PostShareDestinations.telegram(link),
      ),
      _CircleAction(
        label: l10n.postShareMessenger,
        background: const Color(0xFF0084FF),
        assetPath: AppAssets.shareMessengerIcon,
        onTap: () => PostShareDestinations.messenger(link),
      ),
      _CircleAction(
        label: l10n.postShareMore,
        background: Theme.of(context).colorScheme.surfaceContainerHighest,
        icon: LucideIcons.ellipsis,
        iconColor: Theme.of(context).colorScheme.onSurface,
        onTap: () => PostShareDestinations.systemShare(link),
      ),
    ];
  }

  List<_CircleAction> _buildOptionActions(PostOptionsActions actions) {
    final l10n = AppLocalizations.of(context)!;
    final mutedBg = Theme.of(context).colorScheme.surfaceContainerHighest;
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
      if (widget.isOwner && widget.onDelete != null)
        _CircleAction(
          label: l10n.deletePost,
          background: mutedBg,
          icon: LucideIcons.trash2,
          iconColor: const Color(0xFFEF4444),
          onTap: () {
            Navigator.pop(context);
            widget.onDelete!();
          },
        ),
    ];
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    final onSurface = theme.colorScheme.onSurface;
    if (_searchOpen) {
      return SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                style: TextStyle(
                  color: onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: l10n.postShareSearchUsers,
                  hintStyle: TextStyle(
                    color: onSurface.withValues(alpha: 0.45),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchOpen = false);
              },
              icon: Icon(LucideIcons.x, size: 22, color: onSurface),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              setState(() => _searchOpen = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _searchFocus.requestFocus();
              });
            },
            icon: Icon(LucideIcons.search, size: 22, color: onSurface),
          ),
          Expanded(
            child: Text(
              l10n.postShareSendToTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: onSurface,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => Navigator.pop(context),
            icon: Icon(LucideIcons.x, size: 22, color: onSurface),
          ),
        ],
      ),
    );
  }

  Widget _horizontalActions(List<_CircleAction> actions) {
    return SizedBox(
      height: 102,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _CircleActionButton(action: action);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final actions = PostOptionsActions(context, widget.post);
    final appActions = _buildAppActions(l10n, _link);
    final optionActions = _buildOptionActions(actions);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        0,
        AppSizes.p16,
        AppSizes.p12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme, l10n),
          const SizedBox(height: AppSizes.p10),
          SizedBox(
            height: 100,
            child: _loadingPeople
                ? const Center(child: CustomLoadingWidget(size: 40))
                : _visiblePeople.isEmpty
                ? Center(
                    child: Text(
                      l10n.postShareNoUsers,
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _visiblePeople.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final user = _visiblePeople[index];
                      return _FriendShareAvatar(
                        user: user,
                        selected: _selected.contains(user.id),
                        sent: _sentTo.contains(user.id),
                        onTap: () => _toggleUser(user),
                      );
                    },
                  ),
          ),
          if (_selected.isNotEmpty) ...[
            const SizedBox(height: AppSizes.p10),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: _sending ? null : _sendSelected,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.postShareSendToCount(_selected.length)),
              ),
            ),
          ],
          const SizedBox(height: AppSizes.p12),
          _horizontalActions(appActions),
          const SizedBox(height: AppSizes.p8),
          _horizontalActions(optionActions),
        ],
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 68,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
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
              child: action.assetPath != null
                  ? SvgPicture.asset(
                      action.assetPath!,
                      width: 26,
                      height: 26,
                    )
                  : Icon(
                      action.icon,
                      size: 22,
                      color: action.iconColor ?? onSurface,
                    ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              width: 68,
              child: Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
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
    final onSurface = theme.colorScheme.onSurface;
    final ring = sent
        ? const Color(0xFF22C55E)
        : selected
        ? theme.colorScheme.primary
        : Colors.transparent;

    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: sent ? null : onTap,
        borderRadius: BorderRadius.circular(14),
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
                          color: sent
                              ? const Color(0xFF22C55E)
                              : theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 28,
              width: 64,
              child: Text(
                user.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
