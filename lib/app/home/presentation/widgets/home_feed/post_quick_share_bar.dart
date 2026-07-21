import 'package:bimobondapp/app/home/presentation/utils/post_share_people.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating white pill of recent friends (long-press share), TikTok-style.
class PostQuickShareBar {
  PostQuickShareBar._();

  static Future<void> showNear(
    BuildContext context, {
    required GlobalKey anchorKey,
    required PostEntity post,
  }) async {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final anchorBox =
        anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || anchorBox == null || !anchorBox.hasSize) {
      return;
    }

    final anchorOffset = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final screen = overlayBox.size;
    const pillHeight = 64.0;
    const maxPillWidth = 220.0;
    const gap = 10.0;

    var left = anchorOffset.dx - maxPillWidth - gap;
    left = left.clamp(12.0, screen.width - maxPillWidth - 12);
    var top =
        anchorOffset.dy + (anchorBox.size.height - pillHeight) / 2;
    top = top.clamp(12.0, screen.height - pillHeight - 12);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'quick-share',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.88, end: 1).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  alignment: Alignment.centerRight,
                  child: _QuickSharePill(post: post),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }
}

class _QuickSharePill extends StatefulWidget {
  const _QuickSharePill({required this.post});

  final PostEntity post;

  @override
  State<_QuickSharePill> createState() => _QuickSharePillState();
}

class _QuickSharePillState extends State<_QuickSharePill> {
  List<SocialUserEntity> _people = const [];
  bool _loading = true;
  final Set<String> _sentTo = {};
  String? _sendingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final people = await PostSharePeopleLoader.load(limit: 4);
    if (!mounted) return;
    setState(() {
      _people = people;
      _loading = false;
    });
  }

  Future<void> _share(SocialUserEntity user) async {
    if (_sentTo.contains(user.id) || _sendingId != null) return;
    if (!PostShareSender.ensureLoggedIn(context)) return;

    setState(() => _sendingId = user.id);
    final ok = await PostShareSender.shareWithUser(
      context: context,
      post: widget.post,
      user: user,
    );
    if (!mounted) return;

    if (ok) {
      HapticFeedback.lightImpact();
      setState(() {
        _sentTo.add(user.id);
        _sendingId = null;
      });
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.postShareSentTo(user.displayName))),
      );
    } else {
      setState(() => _sendingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.surface;
    final onPill = theme.brightness == Brightness.dark
        ? Colors.black87
        : theme.colorScheme.onSurface;

    return Material(
      color: surface,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        height: 64,
        constraints: const BoxConstraints(minWidth: 72, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: _loading
            ? SizedBox(
                width: 120,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onPill.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              )
            : _people.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  AppLocalizations.of(context)!.postShareNoUsers,
                  style: TextStyle(
                    color: onPill.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final user in _people) ...[
                    _PillAvatar(
                      user: user,
                      sent: _sentTo.contains(user.id),
                      sending: _sendingId == user.id,
                      onTap: () => _share(user),
                    ),
                    if (user != _people.last) const SizedBox(width: 8),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PillAvatar extends StatelessWidget {
  const _PillAvatar({
    required this.user,
    required this.sent,
    required this.sending,
    required this.onTap,
  });

  final SocialUserEntity user;
  final bool sent;
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sent || sending ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: sent ? 0.7 : 1,
            child: SafeNetworkAvatar(
              imageUrl: user.avatarUrl,
              fallbackText: user.displayName,
              radius: 22,
            ),
          ),
          if (sending)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
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
                child: const Icon(Icons.check, size: 11, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
