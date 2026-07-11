import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/chats/domain/usecases/create_or_get_chat_usecase.dart';
import 'package:bimobondapp/app/chats/domain/usecases/send_message_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart'
    as chats_di;
import 'package:bimobondapp/app/home/presentation/utils/chat_shared_post_cache.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_options_actions.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_share_destinations.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_suggestions_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/social/presentation/services/mention_friends_source.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/common_search_bar.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Post options + inline share (friends, apps) in one bottom sheet.
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
    return GlassBottomSheet.showContent<void>(
      context,
      isScrollControlled: true,
      child: _PostOptionsSheetContent(
        post: post,
        isOwner: isOwner,
        onEdit: onEdit,
        onPromote: onPromote,
        onDelete: onDelete,
        onRepost: onRepost,
        isReposted: isReposted,
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
  List<SocialUserEntity> _allPeople = const [];
  bool _loadingPeople = true;
  final Set<String> _sentTo = {};
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
    super.dispose();
  }

  Future<void> _loadPeople() async {
    final merged = <SocialUserEntity>[];
    final seen = <String>{};

    void addUsers(Iterable<SocialUserEntity> users) {
      for (final user in users) {
        if (seen.add(user.id)) merged.add(user);
      }
    }

    final friends = await MentionFriendsSource.ensureLoaded();
    addUsers(friends);

    final suggestionsResult = await social_di.sl<GetSuggestionsUseCase>()(
      const GetSuggestionsParams(limit: 80),
    );
    suggestionsResult.fold((_) => null, (suggestions) {
      addUsers(
        suggestions.map(
          (UserSuggestionEntity s) => SocialUserEntity(
            id: s.id,
            username: s.username,
            fullName: s.fullName,
            avatarUrl: s.avatarUrl,
            isFollowing: s.isFollowing,
          ),
        ),
      );
    });

    if (!mounted) return;
    setState(() {
      _allPeople = merged;
      _loadingPeople = false;
    });
  }

  List<SocialUserEntity> get _visiblePeople {
    if (_query.isEmpty) {
      return _allPeople.take(24).toList(growable: false);
    }
    return MentionFriendsSource.filter(_allPeople, _query, limit: 24);
  }

  bool _ensureLoggedIn() {
    final l10n = AppLocalizations.of(context)!;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return true;

    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.loginRequired,
      message: l10n.loginRequiredMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.login,
      onConfirm: () => context.pushNamed('login'),
    );
    return false;
  }

  Future<void> _shareWithUser(SocialUserEntity user) async {
    if (!_ensureLoggedIn() || _sentTo.contains(user.id)) return;

    ChatSharedPostCache.put(widget.post);

    final chatResult = await chats_di.sl<CreateOrGetChatUseCase>()(
      CreateOrGetChatParams(participantIds: [user.id]),
    );

    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    await chatResult.fold(
      (_) async {
        PopupDialogs.showErrorDialog(context, l10n.postShareSendFailed);
      },
      (chat) async {
        final sendResult = await chats_di.sl<SendMessageUseCase>()(
          SendMessageParams(
            chatId: chat.id,
            content: l10n.messagesInboxLastShare,
            type: 'SHARE',
            sharedPostId: widget.post.id,
          ),
        );

        if (!mounted) return;

        sendResult.fold(
          (_) =>
              PopupDialogs.showErrorDialog(context, l10n.postShareSendFailed),
          (_) {
            setState(() => _sentTo.add(user.id));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.postShareSentTo(user.displayName))),
            );
          },
        );
      },
    );
  }

  List<_PostOptionItem> _buildOptionItems(PostOptionsActions actions) {
    final l10n = AppLocalizations.of(context)!;

    return [
      _PostOptionItem(
        icon: LucideIcons.circlePlus,
        label: l10n.postOptionAddToStory,
        color: const Color(0xFFEC4899),
        onTap: actions.addToStory,
      ),
      if (!widget.isOwner && widget.onRepost != null)
        _PostOptionItem(
          icon: LucideIcons.repeat2,
          label: widget.isReposted ? l10n.repostUndo : l10n.repostAction,
          color: const Color(0xFF2ECC71),
          onTap: widget.onRepost!,
        ),
      _PostOptionItem(
        icon: LucideIcons.film,
        label: l10n.postOptionShareAsGif,
        color: const Color(0xFF8B5CF6),
        onTap: actions.shareAsGif,
      ),
      _PostOptionItem(
        icon: LucideIcons.download,
        label: l10n.postOptionDownload,
        color: const Color(0xFF10B981),
        onTap: actions.download,
      ),
      _PostOptionItem(
        icon: LucideIcons.users,
        label: l10n.postOptionCreateGroup,
        color: const Color(0xFF06B6D4),
        onTap: actions.createGroup,
      ),
      if (widget.isOwner && widget.onEdit != null)
        _PostOptionItem(
          icon: LucideIcons.pencil,
          label: l10n.editPost,
          color: const Color(0xFF3B82F6),
          onTap: widget.onEdit!,
        ),
      if (widget.isOwner &&
          widget.onPromote != null &&
          widget.post.canBePromoted)
        _PostOptionItem(
          icon: LucideIcons.flame,
          label: l10n.promotePostAction,
          color: const Color(0xFFFF6B35),
          onTap: widget.onPromote!,
        ),
      if (!widget.isOwner)
        _PostOptionItem(
          icon: LucideIcons.flag,
          label: l10n.postOptionReport,
          color: const Color(0xFFF97316),
          onTap: actions.report,
        ),
      if (!widget.isOwner)
        _PostOptionItem(
          icon: LucideIcons.eyeOff,
          label: l10n.postOptionNotInterested,
          color: const Color(0xFF6B7280),
          onTap: actions.notInterested,
        ),
      if (widget.isOwner && widget.onDelete != null)
        _PostOptionItem(
          icon: LucideIcons.trash2,
          label: l10n.deletePost,
          color: const Color(0xFFEF4444),
          onTap: widget.onDelete!,
        ),
    ];
  }

  List<_ShareAppTarget> _appTargets(AppLocalizations l10n, String link) {
    return [
      _ShareAppTarget(
        label: l10n.postShareMessenger,
        assetPath: AppAssets.shareMessengerIcon,
        onTap: () => PostShareDestinations.messenger(link),
      ),
      _ShareAppTarget(
        label: l10n.postShareFacebook,
        assetPath: AppAssets.shareFacebookIcon,
        onTap: () => PostShareDestinations.facebook(link),
      ),
      _ShareAppTarget(
        label: l10n.postShareWhatsApp,
        assetPath: AppAssets.shareWhatsAppIcon,
        onTap: () => PostShareDestinations.whatsApp(link),
      ),
      _ShareAppTarget(
        label: l10n.postShareTelegram,
        assetPath: AppAssets.shareTelegramIcon,
        onTap: () => PostShareDestinations.telegram(link),
      ),
      _ShareAppTarget(
        label: l10n.postShareTwitter,
        assetPath: AppAssets.shareXIcon,
        onTap: () => PostShareDestinations.twitter(link),
      ),
      _ShareAppTarget(
        label: l10n.postShareSms,
        assetPath: AppAssets.shareSmsIcon,
        onTap: () => PostShareDestinations.sms(link),
      ),
      _ShareAppTarget(
        label: l10n.postShareEmail,
        assetPath: AppAssets.shareGmailIcon,
        onTap: () => PostShareDestinations.email(link),
      ),
      _ShareAppTarget(
        label: l10n.postShareCopyLink,
        assetPath: AppAssets.shareCopyLinkIcon,
        showCopiedSnack: true,
        onTap: () => PostShareDestinations.copyLink(link),
      ),
      _ShareAppTarget(
        label: l10n.postShareMore,
        assetPath: AppAssets.shareMoreIcon,
        onTap: () => PostShareDestinations.systemShare(link),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final link = _link;
    final actions = PostOptionsActions(context, widget.post);
    final optionItems = _buildOptionItems(actions);
    final appTargets = _appTargets(l10n, link);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.p16,
        0,
        AppSizes.p16,
        MediaQuery.paddingOf(context).bottom + AppSizes.p12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CommonSearchBar(
            controller: _searchController,
            hintText: l10n.postShareSearchUsers,
            fillColor: Colors.white.withValues(alpha: 0.08),
            hintColor: onSurface.withValues(alpha: 0.5),
            textColor: onSurface,
            iconColor: onSurface.withValues(alpha: 0.75),
            onClear: () => _searchController.clear(),
          ),
          const SizedBox(height: AppSizes.p12),
          SizedBox(
            height: 92,
            child: _loadingPeople
                ? const Center(child: CustomLoadingWidget(size: 48))
                : _visiblePeople.isEmpty
                ? Center(
                    child: Text(
                      l10n.postShareNoUsers,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _visiblePeople.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppSizes.p12),
                    itemBuilder: (context, index) {
                      final user = _visiblePeople[index];
                      final sent = _sentTo.contains(user.id);
                      return _FriendShareAvatar(
                        user: user,
                        sent: sent,
                        onTap: () => _shareWithUser(user),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSizes.p12),
          Text(
            l10n.postShareToApps,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.p10),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: appTargets.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSizes.p10),
              itemBuilder: (context, index) {
                final target = appTargets[index];
                return _ShareAppButton(
                  label: target.label,
                  assetPath: target.assetPath,
                  onTap: () async {
                    await target.onTap();
                    if (!context.mounted) return;
                    if (target.showCopiedSnack) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.postLinkCopied)),
                      );
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: AppSizes.p10),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: AppSizes.p4),
              itemCount: optionItems.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSizes.p10),
              itemBuilder: (context, index) {
                final item = optionItems[index];
                return _PostOptionButton(
                  icon: item.icon,
                  label: item.label,
                  color: item.color,
                  onTap: () {
                    Navigator.pop(context);
                    item.onTap();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PostOptionItem {
  const _PostOptionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _ShareAppTarget {
  const _ShareAppTarget({
    required this.label,
    required this.assetPath,
    required this.onTap,
    this.showCopiedSnack = false,
  });

  final String label;
  final String assetPath;
  final Future<void> Function() onTap;
  final bool showCopiedSnack;
}

class _FriendShareAvatar extends StatelessWidget {
  const _FriendShareAvatar({
    required this.user,
    required this.sent,
    required this.onTap,
  });

  final SocialUserEntity user;
  final bool sent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: sent ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SafeNetworkAvatar(
                    imageUrl: user.avatarUrl,
                    fallbackText: user.displayName,
                    radius: 26,
                  ),
                  if (sent)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.p6),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareAppButton extends StatelessWidget {
  const _ShareAppButton({
    required this.label,
    required this.assetPath,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final VoidCallback onTap;

  static const _iconBoxSize = 46.0;
  static const _logoSize = 40.0;
  static const _itemWidth = 68.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _itemWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _iconBoxSize,
                height: _iconBoxSize,
                child: Center(
                  child: SvgPicture.asset(
                    assetPath,
                    width: _logoSize,
                    height: _logoSize,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostOptionButton extends StatelessWidget {
  const _PostOptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  static const _iconBoxSize = 46.0;
  static const _iconSize = 22.0;
  static const _itemWidth = 68.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _itemWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _iconBoxSize,
                height: _iconBoxSize,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.28)),
                ),
                child: Icon(icon, color: color, size: _iconSize),
              ),
              const SizedBox(height: AppSizes.p6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
