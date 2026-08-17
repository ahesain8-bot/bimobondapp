import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/live_api_client.dart';
import '../../data/datasources/fan_club_remote_datasource.dart';
import '../../data/repositories/fan_club_repository_impl.dart';
import '../../domain/entities/fan_club.dart';
import '../../domain/usecases/get_fan_club.dart';
import '../../domain/usecases/get_fan_club_members.dart';
import '../../domain/usecases/get_my_fan_clubs.dart';
import '../../domain/usecases/subscribe_fan_club.dart';
import '../../domain/usecases/unsubscribe_fan_club.dart';
import '../../domain/usecases/update_fan_club.dart';
import '../bloc/fan_club/fan_club_bloc.dart';
import '../bloc/fan_club/fan_club_event.dart';
import '../bloc/fan_club/fan_club_state.dart';
import 'discord_page.dart';

/// Fans community page opened from the start-live tools.
///
/// Clean Architecture: the page only talks to [FanClubBloc]; the bloc
/// orchestrates the 6 Fan Club endpoints (lives/mobile-api.md §20).
class FansCommunityPage extends StatefulWidget {
  const FansCommunityPage({super.key, this.creatorId});

  /// Optional creator whose club to show. Defaults to the signed-in user.
  final String? creatorId;

  @override
  State<FansCommunityPage> createState() => _FansCommunityPageState();
}

class _FansCommunityPageState extends State<FansCommunityPage> {
  FanClubBloc? _bloc;
  int _selectedTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bloc != null) return;

    final apiClient = LiveApiClient();
    final remote = FanClubRemoteDataSource(apiClient: apiClient);
    final repository = FanClubRepositoryImpl(remote: remote);
    _bloc = FanClubBloc(
      getFanClub: GetFanClub(repository),
      getFanClubMembers: GetFanClubMembers(repository),
      getMyFanClubs: GetMyFanClubs(repository),
      subscribeFanClub: SubscribeFanClub(repository),
      unsubscribeFanClub: UnsubscribeFanClub(repository),
      updateFanClub: UpdateFanClub(repository),
      apiClient: apiClient,
    )..add(FanClubLoaded(creatorId: widget.creatorId));
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
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

  Future<void> _openDiscordPage(FanClubReady? ready) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiscordPage(
          discordName: ready?.club.name ?? 'Discord',
          onConnected: (name) async {
            if (_bloc == null || ready == null) return false;
            return _connectDiscord(_bloc!);
          },
        ),
      ),
    );
  }

  /// Calls `PATCH /creators/:creatorId/fan-club` with `{ enabled: true }`
  /// through the bloc and resolves once the request finishes.
  Future<bool> _connectDiscord(FanClubBloc bloc) async {
    final completer = Completer<bool>();
    late final StreamSubscription<FanClubState> sub;
    sub = bloc.stream.listen((state) {
      if (state is FanClubReady && !state.busy) {
        sub.cancel();
        completer.complete(!(state.message ?? '').contains('تعذر'));
      }
    });
    bloc.add(const FanClubUpdated(enabled: true));
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        sub.cancel();
        return false;
      },
    );
  }

  /// Opens the host settings dialog (name + enabled) → `FanClubUpdated`.
  void _onCopyPressed() {
    _snack('هذه الميزة غير متاحة حالياً');
  }

  Widget _buildBody(FanClubState state) {
    if (state is FanClubLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }
    if (state is FanClubFailure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Color(0xFF777777), size: 40),
              const SizedBox(height: 12),
              const Text(
                'تعذر تحميل البيانات',
                style: TextStyle(color: Colors.black, fontSize: 15),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    _bloc?.add(FanClubLoaded(creatorId: widget.creatorId)),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (state is! FanClubReady) return const SizedBox.shrink();

    final ready = state;
    if (_selectedTab == 0) {
      if (ready.members.isEmpty) return const _FansEmptyState();
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: ready.members.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 64, color: Color(0xFFF3F3F3)),
        itemBuilder: (context, index) =>
            _FansMemberTile(member: ready.members[index], rank: index + 1),
      );
    }

    if (ready.myClubs.isEmpty) return const _FansEmptyState();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: ready.myClubs.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 64, color: Color(0xFFF3F3F3)),
      itemBuilder: (context, index) =>
          _FansClubTile(club: ready.myClubs[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bloc = _bloc;
    if (bloc == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        body: const Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    return BlocProvider.value(
      value: bloc,
      child: BlocConsumer<FanClubBloc, FanClubState>(
        listener: (context, state) {
          if (state is FanClubReady && state.message != null) {
            _snack(state.message!);
            bloc.add(const FanClubMessageShown());
          }
        },
        builder: (context, state) {
          final ready = state is FanClubReady ? state : null;

          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            body: SafeArea(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    _FansHeader(
                      clubName: ready?.club.name ?? 'مجتمع المعجبين',
                      onCopy: _onCopyPressed,
                      onDiscord: () => _openDiscordPage(ready),
                    ),
                    const _FansTicker(),
                    const SizedBox(height: 8),
                    _FansStatsCard(memberCount: ready?.club.memberCount ?? 0),
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
                              onChanged: (index) =>
                                  setState(() => _selectedTab = index),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFF3F3F3),
                            ),
                            Expanded(child: _buildBody(state)),
                          ],
                        ),
                      ),
                    ),
                    // Join/leave button only makes sense when viewing
                    // *someone else's* club. When the page is opened from
                    // the start-live tools (`creatorId` is null) it shows
                    // the signed-in user's own club — subscribing to your
                    // own club returns 400 from the server.
                    if (ready != null && widget.creatorId != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: ready.busy
                                ? null
                                : () => bloc.add(
                                    ready.club.isMember
                                        ? const FanClubUnsubscribed()
                                        : const FanClubSubscribed(),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ready.club.isMember
                                  ? const Color(0xFFE5E5E5)
                                  : Colors.black,
                              foregroundColor: ready.club.isMember
                                  ? Colors.black
                                  : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: Text(
                              ready.busy
                                  ? '...جارٍ التنفيذ'
                                  : (ready.club.isMember
                                        ? 'مغادرة المجتمع'
                                        : 'انضمام إلى المجتمع'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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

class _FansMemberTile extends StatelessWidget {
  const _FansMemberTile({required this.member, required this.rank});

  final FanClubMember member;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final avatar = member.avatarUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF3F3F3),
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? NetworkImage(avatar)
                : null,
            child: avatar == null || avatar.isEmpty
                ? Text(
                    member.displayName.isEmpty
                        ? '?'
                        : member.displayName.substring(0, 1),
                    style: const TextStyle(color: Colors.black54, fontSize: 16),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName.isEmpty
                            ? 'معجب'
                            : member.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (member.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF4E9AF1),
                        size: 16,
                      ),
                    ],
                  ],
                ),
                if (member.joinedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'انضم في ${member.joinedAt}',
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '#$rank',
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FansClubTile extends StatelessWidget {
  const _FansClubTile({required this.club});

  final FanClubSubscription club;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5B45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              club.name.isEmpty ? 'مجتمع المعجبين' : club.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${club.memberCount} عضو',
            style: const TextStyle(color: Color(0xFF999999), fontSize: 12),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: club.isMember
                  ? const Color(0xFFEAF3FF)
                  : const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              club.isMember ? 'عضو' : 'غير عضو',
              style: TextStyle(
                color: club.isMember
                    ? const Color(0xFF2F7FE0)
                    : const Color(0xFF999999),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
