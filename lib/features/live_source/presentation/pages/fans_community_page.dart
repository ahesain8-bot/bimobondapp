import 'package:flutter/material.dart';

import 'discord_page.dart';

/// Fans community page opened from the start-live tools.
///
/// UI-only version: no API calls, displays static placeholder data.
class FansCommunityPage extends StatefulWidget {
  const FansCommunityPage({super.key, this.creatorId});

  final String? creatorId;

  @override
  State<FansCommunityPage> createState() => _FansCommunityPageState();
}

class _FansCommunityPageState extends State<FansCommunityPage> {
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

  Future<void> _openDiscordPage() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiscordPage(
          discordName: 'Discord',
          onConnected: (name) async {
            _snack('تم ربط Discord بنجاح');
            return true;
          },
        ),
      ),
    );
  }

  void _onCopyPressed() {
    _snack('هذه الميزة غير متاحة حالياً');
  }

  Widget _buildBody() {
    return const _FansEmptyState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              _FansHeader(
                clubName: 'مجتمع المعجبين',
                onCopy: _onCopyPressed,
                onDiscord: _openDiscordPage,
              ),
              const _FansTicker(),
              const SizedBox(height: 8),
              const _FansStatsCard(memberCount: 0),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      _FansTabs(
                        onChanged: (_) {},
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF3F3F3),
                      ),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FansHeader extends StatelessWidget {
  const _FansHeader({
    required this.clubName,
    required this.onCopy,
    required this.onDiscord,
  });

  final String clubName;
  final VoidCallback onCopy;
  final VoidCallback onDiscord;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      color: const Color(0xFFF3F3F3),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Stack(
              children: [
                Positioned(
                  right: 2,
                  top: 5,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.black,
                      size: 36,
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  top: 8,
                  child: Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      const Icon(
                        Icons.help_outline,
                        color: Colors.black,
                        size: 36,
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: onCopy,
                        child: Image.asset(
                          'assets/images/create_live/content_copy.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: onDiscord,
                        child: const _FansDiscordIcon(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: Center(
              child: Text(
                clubName.isEmpty ? 'مجتمع المعجبين' : clubName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FansDiscordIcon extends StatelessWidget {
  const _FansDiscordIcon();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/create_live/discord.png',
      width: 36,
      height: 36,
      fit: BoxFit.contain,
    );
  }
}

class _FansTicker extends StatefulWidget {
  const _FansTicker();

  @override
  State<_FansTicker> createState() => _FansTickerState();
}

class _FansTickerState extends State<_FansTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _slide = Tween<Offset>(
      begin: const Offset(1.1, 0),
      end: const Offset(-1.1, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 0),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            const Icon(Icons.videocam, color: Color(0xFFFF7900), size: 23),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRect(
                child: SlideTransition(
                  position: _slide,
                  child: const Text(
                    'من بثك المباشر  يمكنك منح الإذن للمعجبين والسماح لهم بالانضمام إلى مجتمعك',
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right, color: Color(0xFF777777), size: 25),
          ],
        ),
      ),
    );
  }
}

class _FansStatsCard extends StatelessWidget {
  const _FansStatsCard({required this.memberCount});

  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          _FansMetric(value: '$memberCount', label: 'المعجبون', showInfo: true),
          const _FansMetric(value: '0', label: 'هدية "أحبني"'),
          const _FansMetric(value: '0', label: '"تحقيق الشهرة"'),
        ],
      ),
    );
  }
}

class _FansMetric extends StatelessWidget {
  const _FansMetric({
    required this.value,
    required this.label,
    this.showInfo = false,
  });

  final String value;
  final String label;
  final bool showInfo;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 25,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
              ),
              if (showInfo) ...[
                const SizedBox(width: 3),
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF888888),
                  size: 14,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FansTabs extends StatefulWidget {
  const _FansTabs({required this.onChanged});

  final ValueChanged<int> onChanged;

  @override
  State<_FansTabs> createState() => _FansTabsState();
}

class _FansTabsState extends State<_FansTabs> {
  int _selectedIndex = 0;
  String _bestFansFilter = 'أفضل المعجبين';

  Future<void> _openBestFansMenu() async {
    final renderBox = context.findRenderObject() as RenderBox;
    final origin = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.sizeOf(context);
    final tabWidth = renderBox.size.width / 2;
    final menuRight = origin.dx + renderBox.size.width;
    final menuLeft = menuRight - tabWidth;
    final menuTop = origin.dy + renderBox.size.height;

    final selected = await showMenu<String>(
      context: context,
      initialValue: _bestFansFilter,
      position: RelativeRect.fromLTRB(
        menuLeft,
        menuTop,
        screenSize.width - menuRight,
        screenSize.height - menuTop - 150,
      ),
      constraints: BoxConstraints.tightFor(width: tabWidth),
      menuPadding: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        _BestFansMenuItem(
          value: 'أفضل المعجبين',
          selected: _bestFansFilter == 'أفضل المعجبين',
        ),
        _BestFansMenuItem(
          value: 'في أحدث بث مباشر',
          selected: _bestFansFilter == 'في أحدث بث مباشر',
        ),
      ],
    );

    if (!mounted || selected == null) return;
    setState(() {
      _bestFansFilter = selected;
      _selectedIndex = 0;
    });
    widget.onChanged(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          _FansTab(
            label: _bestFansFilter,
            selected: _selectedIndex == 0,
            fontSize: 14,
            showDropdown: true,
            onTap: _openBestFansMenu,
          ),
          _FansTab(
            label: 'مساحة مجتمع المعجبين',
            selected: _selectedIndex == 1,
            fontSize: 14,
            onTap: () {
              setState(() => _selectedIndex = 1);
              widget.onChanged(1);
            },
          ),
        ],
      ),
    );
  }
}

class _FansTab extends StatelessWidget {
  const _FansTab({
    required this.label,
    required this.selected,
    required this.fontSize,
    required this.onTap,
    this.showDropdown = false,
  });

  final String label;
  final bool selected;
  final double fontSize;
  final VoidCallback onTap;
  final bool showDropdown;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.black : const Color(0xFF9A9A9A),
                    fontSize: fontSize,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (showDropdown)
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.black,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Container(
              width: selected ? double.infinity : 0,
              height: 2,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}

class _BestFansMenuItem extends PopupMenuItem<String> {
  _BestFansMenuItem({required String value, required bool selected})
    : super(
        value: value,
        height: 76,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.black, fontSize: 15),
                ),
              ),
              SizedBox(
                width: 40,
                child: selected
                    ? const Icon(Icons.check, color: Colors.black, size: 27)
                    : null,
              ),
            ],
          ),
        ),
      );
}

class _FansEmptyState extends StatelessWidget {
  const _FansEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _FansEmptyArtwork(),
            const SizedBox(height: 16),
            const Text(
              'يستطيع المشاهدون إرسال هدية "أحبني"\nللانضمام إلى مجتمع المعجبين لديك',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ادع مشاهديك للانضمام إلى مجتمع معجبيك\nوالانطلاق معًا في رحلة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.48),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FansEmptyArtwork extends StatelessWidget {
  const _FansEmptyArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 66,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 7,
            child: Transform.rotate(
              angle: -0.14,
              child: Container(
                width: 47,
                height: 47,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5B45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sentiment_very_satisfied,
                  color: Color(0xFFFFE2A1),
                  size: 35,
                ),
              ),
            ),
          ),
          const Positioned(
            right: 7,
            top: 0,
            child: Icon(Icons.emoji_events, color: Color(0xFFFFC928), size: 21),
          ),
          const Positioned(
            right: 2,
            bottom: 5,
            child: Icon(Icons.star, color: Color(0xFF67B7E8), size: 20),
          ),
          const Positioned(
            left: 3,
            bottom: 0,
            child: Icon(Icons.favorite, color: Color(0xFFFFD22D), size: 15),
          ),
        ],
      ),
    );
  }
}
