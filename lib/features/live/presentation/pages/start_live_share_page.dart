import 'package:flutter/material.dart';

import '../../../../core/utils/app_colors.dart';
import '../../../../core/utils/app_sizes.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/app_text_styles.dart';
import '../widgets/room/live_room_share_option.dart';

/// Opens the start-live share UI using the same modal-sheet presentation as the room.
class StartLiveShareSheet {
  const StartLiveShareSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.shareScrim,
      builder: (_) => const StartLiveSharePage(),
    );
  }
}

/// Share sheet body used on the start-live screen.
class StartLiveSharePage extends StatefulWidget {
  const StartLiveSharePage({super.key});

  @override
  State<StartLiveSharePage> createState() => _StartLiveSharePageState();
}

class _StartLiveSharePageState extends State<StartLiveSharePage> {
  static const List<String> _contacts = [
    'سليم',
    'ريم',
    'جود',
    'هادي',
    'لارا',
    'مازن',
  ];

  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredContacts {
    final query = _searchController.text.trim();
    if (query.isEmpty) return _contacts;
    return _contacts.where((name) => name.contains(query)).toList();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StartShareHeader(
          searching: _searching,
          controller: _searchController,
          onClose: () => Navigator.of(context).maybePop(),
          onSearch: () => setState(() => _searching = true),
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
            onTap: (name) => _snack('جاهز للمشاركة مع $name'),
          ),
        ),
        const _ShareDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.shareSectionGap,
          ),
          child: _ChannelsRow(onTap: _snack),
        ),
        const _ShareDivider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.shareSheetHorizontal,
            AppSpacing.shareSectionGap,
            AppSpacing.shareSheetHorizontal,
            AppSpacing.shareSheetBottom,
          ),
          child: _ActionsRow(onTap: _snack),
        ),
      ],
    );

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
            child: SingleChildScrollView(child: content),
          ),
        ),
      ),
    );
  }
}

class _StartShareHeader extends StatelessWidget {
  const _StartShareHeader({
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
  const _ContactsRow({required this.contacts, required this.onTap});

  final List<String> contacts;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return const Center(
        child: Text('لا توجد نتائج', style: AppTextStyles.shareItemLabel),
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
        final name = contacts[index];
        return LiveRoomShareOption(
          label: name,
          width: 68,
          onTap: () => onTap(name),
          child: const LiveRoomShareCircle(
            background: AppColors.shareAvatarPlaceholder,
            child: Icon(
              Icons.person,
              size: AppSizes.shareAvatarIcon,
              color: Color(0xFF9E9E9E),
            ),
          ),
        );
      },
    );
  }
}

class _ChannelsRow extends StatelessWidget {
  const _ChannelsRow({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      LiveRoomShareOption(
        label: 'WhatsApp',
        onTap: () => onTap('تم اختيار WhatsApp'),
        child: const LiveRoomShareCircle(
          background: AppColors.shareWhatsApp,
          child: Icon(Icons.chat, color: Colors.white, size: 28),
        ),
      ),
      LiveRoomShareOption(
        label: 'Status',
        onTap: () => onTap('تم اختيار Status'),
        child: const LiveRoomShareCircle(
          background: AppColors.shareWhatsApp,
          child: Icon(Icons.sync, color: Colors.white, size: 28),
        ),
      ),
      LiveRoomShareOption(
        label: 'نسخ الرابط',
        onTap: () => onTap('تم نسخ الرابط'),
        child: const LiveRoomShareCircle(
          background: AppColors.shareCopyLink,
          child: Icon(Icons.link, color: Colors.white, size: 28),
        ),
      ),
      LiveRoomShareOption(
        label: 'Facebook',
        onTap: () => onTap('تم اختيار Facebook'),
        child: const LiveRoomShareCircle(
          background: AppColors.shareFacebook,
          child: Icon(Icons.facebook, color: Colors.white, size: 28),
        ),
      ),
      LiveRoomShareOption(
        label: 'Instagram Direct',
        width: 84,
        onTap: () => onTap('تم اختيار Instagram Direct'),
        child: const _InstagramDirectBadge(),
      ),
      LiveRoomShareOption(
        label: 'Telegram',
        onTap: () => onTap('تم اختيار Telegram'),
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

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LiveRoomShareOption(
          label: 'إضافة إلى القصة',
          width: 78,
          onTap: () => onTap('إضافة إلى القصة'),
          child: const LiveRoomShareCircle(
            background: AppColors.shareActionCircle,
            child: Icon(
              Icons.add_circle_outline,
              color: AppColors.shareForeground,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.shareItemGap),
        LiveRoomShareOption(
          label: 'الآراء والملاحظات',
          width: 86,
          onTap: () => onTap('الآراء والملاحظات'),
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
      child: const Icon(Icons.send_outlined, color: Colors.white, size: 26),
    );
  }
}
