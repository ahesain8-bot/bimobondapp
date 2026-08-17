import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/usecases/get_call_history_usecase.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/app/calls/presentation/di/calls_injector.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  late final GetCallHistoryUseCase _getCallHistoryUseCase;
  
  List<CallEntity> _calls = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _page = 1;

  // Filter selections: 'ALL', 'MISSED', 'AUDIO', 'VIDEO'
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _getCallHistoryUseCase = sl<GetCallHistoryUseCase>();
    _fetchHistory(refresh: true);
  }

  Future<void> _fetchHistory({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _isLoading = true;
        _errorMessage = null;
      });
    }

    String? statusParam;
    String? typeParam;

    if (_selectedFilter == 'MISSED') {
      statusParam = 'MISSED';
    } else if (_selectedFilter == 'AUDIO') {
      typeParam = 'AUDIO';
    } else if (_selectedFilter == 'VIDEO') {
      typeParam = 'VIDEO';
    }

    final result = await _getCallHistoryUseCase(
      page: _page,
      limit: 20,
      status: statusParam,
      type: typeParam,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
      (data) {
        final rawCalls = data['calls'];
        final fetched = (rawCalls is List)
            ? rawCalls.whereType<CallEntity>().toList()
            : <CallEntity>[];
        setState(() {
          _isLoading = false;
          if (refresh) {
            _calls = fetched;
          } else {
            _calls.addAll(fetched);
          }
        });
      },
    );
  }

  void _onSelectFilter(String filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
    });
    _fetchHistory(refresh: true);
  }

  String _formatCallTime(DateTime date, bool isAr) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (diff.inDays == 1) {
      return isAr ? 'أمس' : 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _initiateCall(BuildContext context, CallEntity call, bool isVideo) {
    final authState = context.read<AuthBloc>().state;
    final myId = authState is AuthSuccess ? authState.user.id : '';

    String? peerUserId;
    if (call.chat?.isGroup != true) {
      if (call.participants.isNotEmpty) {
        final matches = call.participants.where((p) => p.userId != myId);
        if (matches.isNotEmpty) {
          peerUserId = matches.first.userId;
        } else {
          peerUserId = call.participants.first.userId;
        }
      }
      peerUserId ??= (call.initiatedBy.id.isNotEmpty && call.initiatedBy.id != myId)
          ? call.initiatedBy.id
          : null;
    }

    context.read<CallBloc>().add(
          StartCallEvent(
            chatId: call.chatId,
            type: isVideo ? 'VIDEO' : 'AUDIO',
            inviteeIds: peerUserId != null && peerUserId.isNotEmpty ? [peerUserId] : null,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final body = RefreshIndicator(
      onRefresh: () => _fetchHistory(refresh: true),
      color: theme.colorScheme.primary,
      child: Column(
        children: [
          // Filter Chips Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: isAr ? 'الكل' : 'All',
                    value: 'ALL',
                    icon: LucideIcons.phone,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: isAr ? 'الفائتة' : 'Missed',
                    value: 'MISSED',
                    icon: LucideIcons.phoneMissed,
                    isDark: isDark,
                    activeColor: Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: isAr ? 'صوتية' : 'Audio',
                    value: 'AUDIO',
                    icon: LucideIcons.phone,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: isAr ? 'فيديو' : 'Video',
                    value: 'VIDEO',
                    icon: LucideIcons.video,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CustomLoadingWidget(size: 60))
                : (_errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : (_calls.isEmpty
                        ? _buildEmptyState(theme, isAr)
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _calls.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: isDark
                                  ? Colors.white10
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                            itemBuilder: (context, index) {
                              final call = _calls[index];
                              return _buildCallItem(context, call, isDark, isAr);
                            },
                          ))),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: isAr ? 'سجل المكالمات' : 'Call History',
        showBackButton: true,
      ),
      body: body,
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    Color? activeColor,
  }) {
    final isSelected = _selectedFilter == value;
    final activeBg = activeColor ?? const Color(0xFF6366F1);

    return InkWell(
      onTap: () => _onSelectFilter(value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeBg
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeBg
                : (isDark ? Colors.white12 : Colors.black12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isAr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
            ),
            child: Icon(
              LucideIcons.phoneOff,
              size: 40,
              color: theme.hintColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isAr ? 'لا توجد مكالمات بعد' : 'No call history yet',
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallItem(
    BuildContext context,
    CallEntity call,
    bool isDark,
    bool isAr,
  ) {
    final authState = context.read<AuthBloc>().state;
    final myId = authState is AuthSuccess ? authState.user.id : '';

    // Determine peer user safely
    final initiator = call.initiatedBy;
    final isInitiator = myId.isNotEmpty && initiator.id == myId;

    CallUserEntity? peerUser;
    if (isInitiator) {
      for (final p in call.participants) {
        if (p.userId != myId && p.user != null) {
          peerUser = p.user;
          break;
        }
      }
      if (peerUser == null && call.participants.isNotEmpty) {
        peerUser = call.participants.first.user;
      }
    } else {
      peerUser = initiator;
    }
    peerUser ??= initiator;

    final name = (call.chat?.name != null && call.chat!.name!.isNotEmpty)
        ? call.chat!.name!
        : ((peerUser.fullName != null && peerUser.fullName!.isNotEmpty)
            ? peerUser.fullName!
            : (peerUser.username.isNotEmpty ? peerUser.username : (isAr ? 'مستخدم' : 'User')));
    final avatarUrl = peerUser.avatarUrl;

    // Status icon & text
    final isMissed = call.status == 'MISSED' || call.status == 'REJECTED';
    final isOutgoing = isInitiator;

    IconData statusIcon;
    Color statusColor;
    String statusText;

    if (isMissed) {
      statusIcon = LucideIcons.phoneMissed;
      statusColor = Colors.redAccent;
      statusText = isAr ? 'مكالمة فائتة' : 'Missed';
    } else if (isOutgoing) {
      statusIcon = LucideIcons.phoneOutgoing;
      statusColor = const Color(0xFF3B82F6);
      statusText = isAr ? 'صادرة' : 'Outgoing';
    } else {
      statusIcon = LucideIcons.phoneIncoming;
      statusColor = const Color(0xFF10B981);
      statusText = isAr ? 'واردة' : 'Incoming';
    }

    final dateStr = _formatCallTime(call.createdAt, isAr);
    final durationSecs = (call.startedAt != null && call.endedAt != null)
        ? call.endedAt!.difference(call.startedAt!).inSeconds
        : null;
    final durationStr = _formatDuration(durationSecs);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF1F5F9),
            backgroundImage:
                avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $dateStr',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    if (durationStr.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '($durationStr)',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons (Voice & Video Call)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _initiateCall(context, call, false),
                icon: const Icon(LucideIcons.phone, size: 20),
                color: const Color(0xFF6366F1),
                tooltip: isAr ? 'مكالمة صوتية' : 'Audio Call',
              ),
              IconButton(
                onPressed: () => _initiateCall(context, call, true),
                icon: const Icon(LucideIcons.video, size: 20),
                color: const Color(0xFF6366F1),
                tooltip: isAr ? 'مكالمة فيديو' : 'Video Call',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
