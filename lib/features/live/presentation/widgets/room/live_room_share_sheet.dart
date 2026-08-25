import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_share_actions.dart';
import 'live_room_share_option.dart';

/// Recent share target shown in the contacts row.
///
/// Backend does not document a share-contacts API in `lives` docs, so this
/// sheet intentionally shows an empty contacts row (no mocks).
class LiveShareContact {
  const LiveShareContact({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
}

/// TikTok-style live share bottom sheet.
class LiveRoomShareSheet {
  const LiveRoomShareSheet._();

  static Future<void> show(BuildContext context) {
    final bloc = context.read<LiveRoomBloc>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.shareScrim,
      builder: (_) {
        return BlocProvider.value(
          value: bloc,
          child: const _LiveRoomShareSheetBody(
            contacts: <LiveShareContact>[],
          ),
        );
      },
    );
  }
}

class _LiveRoomShareSheetBody extends StatefulWidget {
  const _LiveRoomShareSheetBody({required this.contacts});

  final List<LiveShareContact> contacts;

  @override
  State<_LiveRoomShareSheetBody> createState() =>
      _LiveRoomShareSheetBodyState();
}

class _LiveRoomShareSheetBodyState extends State<_LiveRoomShareSheetBody> {
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? get _sessionId {
    final state = context.read<LiveRoomBloc>().state;
    if (state is LiveRoomReady) return state.session.id;
    return null;
  }

  String? get _hostName {
    final state = context.read<LiveRoomBloc>().state;
    if (state is LiveRoomReady) return state.session.host.displayName;
    return null;
  }

  List<LiveShareContact> get _filteredContacts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.contacts;
    return widget.contacts
        .where((c) => c.displayName.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _close() => Navigator.of(context).maybePop();

  void _snack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _onContact(LiveShareContact contact) async {
    context.read<LiveRoomBloc>().add(
          LiveRoomShareContactSelected(
            contactId: contact.id,
            displayName: contact.displayName,
          ),
        );
    final sessionId = _sessionId;
    if (sessionId != null) {
      await LiveRoomShareActions.copyLink(sessionId);
    }
    if (!mounted) return;
    _snack('جاهز للمشاركة مع ${contact.displayName}');
    _close();
  }

  Future<void> _onChannel(LiveRoomShareChannel channel) async {
    context.read<LiveRoomBloc>().add(LiveRoomShareChannelRequested(channel));

    final sessionId = _sessionId;
    if (sessionId == null) {
      _close();
      return;
    }

    final url = LiveRoomShareActions.liveUrl(sessionId);
    final message = LiveRoomShareActions.shareMessage(
      sessionId,
      hostName: _hostName,
    );

    switch (channel) {
      case LiveRoomShareChannel.copyLink:
        await LiveRoomShareActions.copyLink(sessionId);
        if (!mounted) return;
        _snack('تم نسخ الرابط');
        _close();
        return;
      case LiveRoomShareChannel.whatsApp:
        final ok = await LiveRoomShareActions.openWhatsApp(message);
        if (!mounted) return;
        if (!ok) _snack('تعذر فتح WhatsApp');
        _close();
        return;
      case LiveRoomShareChannel.telegram:
        final ok = await LiveRoomShareActions.openTelegram(
          url: url,
          message: message,
        );
        if (!mounted) return;
        if (!ok) _snack('تعذر فتح Telegram');
        _close();
        return;
      case LiveRoomShareChannel.facebook:
        final ok = await LiveRoomShareActions.openFacebook(url);
        if (!mounted) return;
        if (!ok) _snack('تعذر فتح Facebook');
        _close();
        return;
      case LiveRoomShareChannel.instagramDirect:
        await LiveRoomShareActions.copyLink(sessionId);
        if (!mounted) return;
        _snack('تم نسخ الرابط — الصقه في Instagram');
        _close();
        return;
      case LiveRoomShareChannel.status:
        await LiveRoomShareActions.copyLink(sessionId);
        if (!mounted) return;
        _snack('تم نسخ الرابط لحالة WhatsApp');
        _close();
        return;
      case LiveRoomShareChannel.addToStory:
        if (!mounted) return;
        _snack('إضافة إلى القصة — قريبًا');
        _close();
        return;
      case LiveRoomShareChannel.feedback:
        if (!mounted) return;
        _snack('الآراء والملاحظات — قريبًا');
        _close();
        return;
      case LiveRoomShareChannel.promote:
        return;
      case LiveRoomShareChannel.search:
        setState(() {
          _searching = true;
        });
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: AppColors.shareSheetBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.shareSheetRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ShareHeader(
                  searching: _searching,
                  controller: _searchController,
                  onClose: _close,
                  onSearch: () => _onChannel(LiveRoomShareChannel.search),
                  onCancelSearch: () {
                    setState(() {
                      _searching = false;
                      _searchController.clear();
                    });
                  },
                  onQueryChanged: (_) => setState(() {}),
                ),
                const _ShareDivider(),
                SizedBox(
                  height: 96,
                  child: _ContactsRow(
                    contacts: _filteredContacts,
                    onTap: _onContact,
                  ),
                ),
                const _ShareDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.shareSectionGap,
                  ),
                  child: _ChannelsRow(onTap: _onChannel),
                ),
                const _ShareDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.shareSheetHorizontal,
                    AppSpacing.shareSectionGap,
                    AppSpacing.shareSheetHorizontal,
                    AppSpacing.shareSheetBottom,
                  ),
                  child: _ActionsRow(onTap: _onChannel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareHeader extends StatelessWidget {
  const _ShareHeader({
    required this.searching,
    required this.controller,
    required this.onClose,
    required this.onSearch,
    required this.onCancelSearch,
    required this.onQueryChanged,
  });

  final bool searching;
  final TextEditingController controller;
  final VoidCallback onClose;
  final VoidCallback onSearch;
  final VoidCallback onCancelSearch;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: SizedBox(
        height: 44,
        child: searching
            ? Row(
                children: [
                  IconButton(
                    onPressed: onCancelSearch,
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.shareForeground,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: onQueryChanged,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'بحث عن أشخاص',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: AppTextStyles.shareTitle.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  const Text('مشاركة', style: AppTextStyles.shareTitle),
                  // Close / search keep physical LTR corners like the reference.
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.shareForeground,
                            size: 24,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: onSearch,
                          icon: const Icon(
                            Icons.search,
                            color: AppColors.shareForeground,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ShareDivider extends StatelessWidget {
  const _ShareDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.shareDivider,
    );
  }
}

class _ContactsRow extends StatelessWidget {
  const _ContactsRow({
    required this.contacts,
    required this.onTap,
  });

  final List<LiveShareContact> contacts;
  final ValueChanged<LiveShareContact> onTap;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد نتائج',
          style: AppTextStyles.shareItemLabel,
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.shareSheetHorizontal,
        vertical: AppSpacing.sm,
      ),
      itemCount: contacts.length,
      separatorBuilder: (_, _) =>
          const SizedBox(width: AppSpacing.shareItemGap),
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return LiveRoomShareOption(
          label: contact.displayName,
          width: 68,
          onTap: () => onTap(contact),
          child: _ContactAvatar(contact: contact),
        );
      },
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({required this.contact});

  final LiveShareContact contact;

  @override
  Widget build(BuildContext context) {
    final url = contact.avatarUrl;
    return LiveRoomShareCircle(
      background: AppColors.shareAvatarPlaceholder,
      child: url == null
          ? const Icon(
              Icons.person,
              size: AppSizes.shareAvatarIcon,
              color: Color(0xFF9E9E9E),
            )
          : ClipOval(
              child: Image.network(
                url,
                width: AppSizes.shareCircle,
                height: AppSizes.shareCircle,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.person,
                  size: AppSizes.shareAvatarIcon,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ),
    );
  }
}

class _ChannelsRow extends StatelessWidget {
  const _ChannelsRow({required this.onTap});

  final ValueChanged<LiveRoomShareChannel> onTap;

  @override
  Widget build(BuildContext context) {
    // RTL: first item sits on the right — WhatsApp → … → Telegram.
    final items = <Widget>[
      LiveRoomShareOption(
        label: 'WhatsApp',
        onTap: () => onTap(LiveRoomShareChannel.whatsApp),
        child: const LiveRoomShareCircle(
          background: AppColors.shareWhatsApp,
          child: Icon(
            Icons.chat,
            color: Colors.white,
            size: AppSizes.shareCircleIcon,
          ),
        ),
      ),
      LiveRoomShareOption(
        label: 'Status',
        onTap: () => onTap(LiveRoomShareChannel.status),
        child: LiveRoomShareCircle(
          background: AppColors.shareWhatsApp,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.sync,
                color: Colors.white.withValues(alpha: 0.95),
                size: 26,
              ),
              const Icon(
                Icons.add,
                color: Colors.white,
                size: 14,
              ),
            ],
          ),
        ),
      ),
      LiveRoomShareOption(
        label: 'نسخ الرابط',
        onTap: () => onTap(LiveRoomShareChannel.copyLink),
        child: const LiveRoomShareCircle(
          background: AppColors.shareCopyLink,
          child: Icon(
            Icons.link,
            color: Colors.white,
            size: AppSizes.shareCircleIcon,
          ),
        ),
      ),
      LiveRoomShareOption(
        label: 'Facebook',
        onTap: () => onTap(LiveRoomShareChannel.facebook),
        child: const LiveRoomShareCircle(
          background: AppColors.shareFacebook,
          child: Icon(
            Icons.facebook,
            color: Colors.white,
            size: AppSizes.shareCircleIcon,
          ),
        ),
      ),
      LiveRoomShareOption(
        label: 'Instagram Direct',
        width: 84,
        onTap: () => onTap(LiveRoomShareChannel.instagramDirect),
        child: const LiveRoomShareCircle(
          background: Colors.transparent,
          child: _InstagramDirectBadge(),
        ),
      ),
      LiveRoomShareOption(
        label: 'Telegram',
        onTap: () => onTap(LiveRoomShareChannel.telegram),
        child: LiveRoomShareCircle(
          background: AppColors.shareTelegram,
          child: Transform.rotate(
            angle: -0.4,
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    ];

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.shareSheetHorizontal,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppSpacing.shareItemGap),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

class _InstagramDirectBadge extends StatelessWidget {
  const _InstagramDirectBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.shareCircle,
      height: AppSizes.shareCircle,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFFF58529),
            Color(0xFFDD2A7B),
            Color(0xFF8134AF),
            Color(0xFF515BD4),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.send_outlined,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.onTap});

  final ValueChanged<LiveRoomShareChannel> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LiveRoomShareOption(
          label: 'إضافة إلى القصة',
          width: 78,
          onTap: () => onTap(LiveRoomShareChannel.addToStory),
          child: const LiveRoomShareCircle(
            background: AppColors.shareActionCircle,
            child: CustomPaint(
              size: Size(30, 30),
              painter: _DashedStoryPainter(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.shareItemGap),
        LiveRoomShareOption(
          label: 'الاراء والملاحظات',
          width: 86,
          onTap: () => onTap(LiveRoomShareChannel.feedback),
          child: const LiveRoomShareCircle(
            background: AppColors.shareActionCircle,
            child: Icon(
              Icons.help_outline,
              color: AppColors.shareForeground,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.shareItemGap),
        LiveRoomShareOption(
          label: 'الترويج',
          enabled: false,
          child: LiveRoomShareCircle(
            background: AppColors.shareActionCircle.withValues(alpha: 0.7),
            child: const Icon(
              Icons.local_fire_department_outlined,
              color: AppColors.shareDisabled,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

/// Dashed ring + plus to approximate the "add to story" control.
class _DashedStoryPainter extends CustomPainter {
  const _DashedStoryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    final paint = Paint()
      ..color = AppColors.shareForeground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    const dashCount = 12;
    const sweep = (3.1415926535 * 2) / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep * 0.55,
        false,
        paint,
      );
    }

    final plus = Paint()
      ..color = AppColors.shareForeground
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - 5, center.dy),
      Offset(center.dx + 5, center.dy),
      plus,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 5),
      Offset(center.dx, center.dy + 5),
      plus,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
