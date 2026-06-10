import 'dart:async';

import 'package:bimobondapp/app/notifications/data/models/notification_model.dart';
import 'package:bimobondapp/app/notifications/data/datasources/notification_socket_service.dart';
import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/domain/usecases/notifications_usecases.dart';
import 'package:bimobondapp/app/notifications/presentation/di/notifications_injector.dart'
    as notifications_di;
import 'package:bimobondapp/app/notifications/presentation/services/notification_unread_badge.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_admin_helper.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_navigation.dart';
import 'package:bimobondapp/app/notifications/presentation/widgets/notification_list_tile.dart';
import 'package:bimobondapp/app/notifications/presentation/widgets/notifications_filter_tabs.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<NotificationEntity> _items = [];

  int _page = 1;
  bool _hasReachedMax = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  NotificationsReadFilter _readFilter = NotificationsReadFilter.all;
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
        if (_matchesFilter(notification)) {
          _items.insert(0, notification);
        }
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

  bool _matchesFilter(NotificationEntity notification) {
    return switch (_readFilter) {
      NotificationsReadFilter.all => true,
      NotificationsReadFilter.unread => !notification.isRead,
      NotificationsReadFilter.read => notification.isRead,
    };
  }

  bool? get _isReadQuery {
    return switch (_readFilter) {
      NotificationsReadFilter.all => null,
      NotificationsReadFilter.unread => false,
      NotificationsReadFilter.read => true,
    };
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
        GetNotificationsParams(
          page: 1,
          limit: _pageSize,
          isRead: _isReadQuery,
        ),
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
            notifications_di
                .sl<NotificationUnreadBadge>()
                .setCount(page.unreadCount);
            _hasReachedMax = page.hasReachedMax;
            _isLoading = false;
          });
        },
      );
      return;
    }

    final result = await notifications_di.sl<GetNotificationsUseCase>()(
      GetNotificationsParams(
        page: _page,
        limit: _pageSize,
        isRead: _isReadQuery,
      ),
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
          notifications_di.sl<NotificationUnreadBadge>().setCount(page.unreadCount);
          _hasReachedMax = page.hasReachedMax;
          _isLoadingMore = false;
        });
      },
    );
  }

  void _onFilterSelected(NotificationsReadFilter filter) {
    if (_readFilter == filter) return;
    setState(() {
      _readFilter = filter;
      _items.clear();
      _errorMessage = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _load(refresh: true);
  }

  Future<void> _markAllRead() async {
    final result =
        await notifications_di.sl<MarkAllNotificationsReadUseCase>()();
    if (!mounted) return;
    result.fold(
      (failure) => PopupDialogs.showErrorDialog(context, failure.message),
      (count) {
        setState(() {
          _unreadCount = count;
          for (var i = 0; i < _items.length; i++) {
            if (!_items[i].isRead) {
              _items[i] = _items[i].copyWith(isRead: true);
            }
          }
          if (_readFilter == NotificationsReadFilter.unread) {
            _items.clear();
          }
        });
        notifications_di.sl<NotificationUnreadBadge>().setCount(count);
      },
    );
  }

  Future<void> _onTap(NotificationEntity notification) async {
    if (!notification.isRead) {
      await notifications_di.sl<MarkNotificationReadUseCase>()(notification.id);
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((e) => e.id == notification.id);
        if (index != -1) {
          if (_readFilter == NotificationsReadFilter.unread) {
            _items.removeAt(index);
          } else if (_readFilter == NotificationsReadFilter.read) {
            _items[index] = _items[index].copyWith(isRead: true);
          } else {
            _items[index] = _items[index].copyWith(isRead: true);
          }
          if (_unreadCount > 0) _unreadCount--;
        }
      });
      notifications_di.sl<NotificationUnreadBadge>().setCount(_unreadCount);
    }

    if (!mounted) return;
    if (NotificationAdminHelper.isAdminNotificationEntity(notification)) {
      return;
    }
    await handleNotificationTap(context, notification);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.light
          ? Colors.white
          : theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: l10n.settingsNotifications,
        showBackButton: true,
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: Icon(
                LucideIcons.checkCheck,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              label: Text(
                l10n.notificationsMarkAllRead,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.p16,
                0,
                AppSizes.p16,
                AppSizes.p4,
              ),
              child: Text(
                l10n.notificationsFilterUnreadCount(_unreadCount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          NotificationsFilterTabs(
            filter: _readFilter,
            unreadCount: _unreadCount,
            onFilterSelected: _onFilterSelected,
          ),
          Expanded(child: _buildBody(l10n, theme)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_isLoading && !_isLoadingMore) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p8,
        ),
        itemCount: 8,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: AppSizes.p10),
          child: SkeletonWidget(height: 88, borderRadius: 18),
        ),
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return _NotificationsEmptyState(
        icon: LucideIcons.circleAlert,
        title: l10n.notificationsLoadError,
        subtitle: _errorMessage!,
        actionLabel: l10n.notificationsRetry,
        onAction: () => _load(refresh: true),
      );
    }

    if (_items.isEmpty) {
      final subtitle = switch (_readFilter) {
        NotificationsReadFilter.unread => l10n.notificationsEmptyUnread,
        NotificationsReadFilter.read => l10n.notificationsEmptyRead,
        NotificationsReadFilter.all => l10n.notificationsEmptySubtitle,
      };
      return _NotificationsEmptyState(
        icon: LucideIcons.bellOff,
        title: l10n.notificationsEmpty,
        subtitle: subtitle,
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
        padding: const EdgeInsets.fromLTRB(
          AppSizes.p16,
          0,
          AppSizes.p16,
          AppSizes.p24,
        ),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
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

          final notification = _items[index];
          return NotificationListTile(
            notification: notification,
            onTap: () => _onTap(notification),
          );
        },
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState({
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
    final theme = Theme.of(context);

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
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.65),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 30,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
