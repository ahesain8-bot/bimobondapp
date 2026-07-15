import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/messages/activity_filter_tabs.dart';
import 'package:bimobondapp/app/notifications/data/datasources/notification_socket_service.dart';
import 'package:bimobondapp/app/notifications/data/models/notification_model.dart';
import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/domain/usecases/notifications_usecases.dart';
import 'package:bimobondapp/app/notifications/presentation/di/notifications_injector.dart'
    as notifications_di;
import 'package:bimobondapp/app/notifications/presentation/services/notification_unread_badge.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_admin_helper.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_navigation.dart';
import 'package:bimobondapp/app/notifications/presentation/widgets/notification_list_tile.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Typical TikTok-style Activity hub: all notifications, comments/likes filters,
/// mark-all-read and clear-read actions.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<NotificationEntity> _items = [];

  int _page = 1;
  bool _hasReachedMax = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  ActivityHubTab _tab = ActivityHubTab.all;
  int _unreadCount = 0;
  String? _errorMessage;
  int _refreshGeneration = 0;

  StreamSubscription<NotificationModel>? _notificationSub;
  StreamSubscription<int>? _unreadSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _listenRealtime();
    _load(refresh: true);
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _unreadSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _listenRealtime() {
    final socket = notifications_di.sl<NotificationSocketService>();
    _notificationSub = socket.onNotification.listen((notification) {
      if (!mounted) return;
      setState(() {
        _items.removeWhere((item) => item.id == notification.id);
        _items.insert(0, notification);
        if (!notification.isRead) _unreadCount++;
      });
    });
    _unreadSub = socket.onUnreadCount.listen((count) {
      if (!mounted) return;
      setState(() => _unreadCount = count);
      notifications_di.sl<NotificationUnreadBadge>().setCount(count);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _hasReachedMax || _isLoadingMore) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent -
            ProfileLayoutConstants.scrollLoadMoreThreshold) {
      _load(loadMore: true);
    }
  }

  List<NotificationEntity> get _visibleItems {
    return _items.where((n) => _tab.matches(n.type)).toList(growable: false);
  }

  Future<void> _load({bool refresh = false, bool loadMore = false}) async {
    if (loadMore) {
      if (_hasReachedMax || _isLoadingMore || _isLoading) return;
      setState(() {
        _isLoadingMore = true;
        _page++;
      });
    } else {
      final generation = ++_refreshGeneration;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _page = 1;
        _hasReachedMax = false;
        if (refresh) _items.clear();
      });

      final result = await notifications_di.sl<GetNotificationsUseCase>()(
        const GetNotificationsParams(page: 1, limit: _pageSize),
      );

      if (!mounted || generation != _refreshGeneration) return;

      result.fold(
        (failure) => setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        }),
        (page) {
          setState(() {
            _items
              ..clear()
              ..addAll(page.notifications);
            _unreadCount = page.unreadCount;
            notifications_di.sl<NotificationUnreadBadge>().setCount(
              page.unreadCount,
            );
            _hasReachedMax = page.hasReachedMax;
            _isLoading = false;
          });
        },
      );
      return;
    }

    final result = await notifications_di.sl<GetNotificationsUseCase>()(
      GetNotificationsParams(page: _page, limit: _pageSize),
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isLoadingMore = false;
        if (_page > 1) _page--;
      }),
      (page) {
        setState(() {
          final existing = _items.map((e) => e.id).toSet();
          _items.addAll(
            page.notifications.where((e) => !existing.contains(e.id)),
          );
          _unreadCount = page.unreadCount;
          notifications_di.sl<NotificationUnreadBadge>().setCount(
            page.unreadCount,
          );
          _hasReachedMax = page.hasReachedMax;
          _isLoadingMore = false;
        });
      },
    );
  }

  void _onTabSelected(ActivityHubTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _markAllRead() async {
    final result = await notifications_di
        .sl<MarkAllNotificationsReadUseCase>()();
    if (!mounted) return;
    result.fold(
      (failure) => PopupDialogs.showErrorDialog(context, failure.message),
      (_) {
        setState(() {
          _unreadCount = 0;
          for (var i = 0; i < _items.length; i++) {
            if (!_items[i].isRead) {
              _items[i] = _items[i].copyWith(isRead: true);
            }
          }
        });
        notifications_di.sl<NotificationUnreadBadge>().setCount(0);
      },
    );
  }

  Future<void> _clearReadNotifications() async {
    final l10n = AppLocalizations.of(context)!;
    await PopupDialogs.showConfirmDialog(
      context,
      title: l10n.notificationsClearRead,
      message: l10n.activityClearNotificationsMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.notificationsClearRead,
      destructive: true,
      onConfirm: () async {
        final result =
            await notifications_di.sl<ClearReadNotificationsUseCase>()();
        if (!mounted) return;
        result.fold(
          (failure) => PopupDialogs.showErrorDialog(context, failure.message),
          (_) {
            setState(() {
              _items.removeWhere((n) => n.isRead);
            });
            _load(refresh: true);
          },
        );
      },
    );
  }

  Future<void> _markRead(NotificationEntity notification) async {
    if (notification.isRead) return;
    await notifications_di.sl<MarkNotificationReadUseCase>()(notification.id);
    if (!mounted) return;
    setState(() {
      final index = _items.indexWhere((e) => e.id == notification.id);
      if (index != -1) {
        _items[index] = _items[index].copyWith(isRead: true);
        if (_unreadCount > 0) _unreadCount--;
      }
    });
    notifications_di.sl<NotificationUnreadBadge>().setCount(_unreadCount);
  }

  Future<void> _onTap(NotificationEntity notification) async {
    await _markRead(notification);
    if (!mounted) return;
    if (NotificationAdminHelper.isAdminNotificationEntity(notification)) {
      return;
    }
    await handleNotificationTap(context, notification);
  }

  void _showActionsMenu() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  LucideIcons.checkCheck,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.notificationsMarkAllRead),
                enabled: _unreadCount > 0,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _markAllRead();
                },
              ),
              ListTile(
                leading: Icon(
                  LucideIcons.trash2,
                  color: theme.colorScheme.error,
                ),
                title: Text(l10n.notificationsClearRead),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _clearReadNotifications();
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.messageCircle),
                title: Text(l10n.messagesActivityComments),
                subtitle: Text(l10n.activityOpenCommentsSubtitle),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.pushNamed('user_comments');
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.atSign),
                title: Text(l10n.messagesActivityMentions),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.pushNamed('user_mentions');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final screenBackground = theme.brightness == Brightness.light
        ? Colors.white
        : theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: screenBackground,
      appBar: CustomAppBar(
        title: l10n.messagesActivityTitle,
        showBackButton: true,
        backgroundColor: screenBackground,
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: MessagesLayoutConstants.activityBadgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: _showActionsMenu,
            tooltip: l10n.notificationsClearRead,
            icon: Icon(
              LucideIcons.ellipsis,
              size: 22,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSizes.p8),
          ActivityFilterTabs(selected: _tab, onSelected: _onTabSelected),
          const SizedBox(height: AppSizes.p8),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MessagesLayoutConstants.horizontalPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _unreadCount > 0
                        ? l10n.notificationsFilterUnreadCount(_unreadCount)
                        : l10n.activityAllCaughtUp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: chatTheme.inboxSecondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_unreadCount > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    child: Text(l10n.notificationsMarkAllRead),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildBody(l10n, theme)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_isLoading && !_isLoadingMore) {
      return const NotificationsListSkeleton();
    }

    if (_errorMessage != null && _items.isEmpty) {
      return _ActivityEmptyState(
        icon: LucideIcons.circleAlert,
        title: l10n.notificationsLoadError,
        subtitle: _errorMessage!,
        actionLabel: l10n.notificationsRetry,
        onAction: () => _load(refresh: true),
      );
    }

    final visibleItems = _visibleItems;
    if (visibleItems.isEmpty) {
      return _ActivityEmptyState(
        icon: LucideIcons.heart,
        title: l10n.notificationsEmpty,
        subtitle: l10n.notificationsEmptySubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      edgeOffset: 12,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: AppSizes.p8),
        itemCount: visibleItems.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= visibleItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.p16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final notification = visibleItems[index];
          final isLast = index == visibleItems.length - 1;

          return NotificationListTile(
            notification: notification,
            onTap: () => _onTap(notification),
            onAccept: notification.type == 'FOLLOW_REQUEST'
                ? () async {
                    await _markRead(notification);
                    if (!mounted) return;
                    await handleNotificationTap(context, notification);
                  }
                : null,
            onDecline: notification.type == 'FOLLOW_REQUEST'
                ? () => _markRead(notification)
                : null,
            showDivider: !isLast,
          );
        },
      ),
    );
  }
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: MessagesLayoutConstants.activityLikesColor.withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 30,
                color: MessagesLayoutConstants.activityLikesColor,
              ),
            ),
            const SizedBox(height: AppSizes.p16),
            CustomText(
              title,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.p8),
            CustomText(
              subtitle,
              variant: TextVariant.secondary,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSizes.p20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
