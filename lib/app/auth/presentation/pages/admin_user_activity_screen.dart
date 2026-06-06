import 'package:bimobondapp/app/auth/domain/entities/user_activity_entity.dart';
import 'package:bimobondapp/app/auth/domain/usecases/get_admin_user_activity_usecase.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart'
    as auth_di;
import 'package:bimobondapp/core/utils/admin_activity_labels.dart';
import 'package:bimobondapp/core/constants/settings_layout_constants.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AdminUserActivityScreen extends StatefulWidget {
  const AdminUserActivityScreen({this.userId, super.key});

  /// Target user UUID. Falls back to the signed-in admin user.
  final String? userId;

  @override
  State<AdminUserActivityScreen> createState() =>
      _AdminUserActivityScreenState();
}

class _AdminUserActivityScreenState extends State<AdminUserActivityScreen> {
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  final List<UserActivityEntity> _activities = [];

  int _page = 1;
  bool _hasReachedMax = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadActivities(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String? get _targetUserId {
    final fromRoute = widget.userId?.trim();
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return authState.user.id;
    return null;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_hasReachedMax || _isLoading || _isLoadingMore) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      _loadActivities(loadMore: true);
    }
  }

  Future<void> _loadActivities({
    bool refresh = false,
    bool loadMore = false,
  }) async {
    final userId = _targetUserId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasLoaded = true;
      });
      return;
    }

    if (loadMore) {
      if (_hasReachedMax || _isLoadingMore) return;
      setState(() => _isLoadingMore = true);
      _page++;
    } else if (refresh) {
      setState(() {
        _isLoading = _activities.isEmpty;
        _errorMessage = null;
        _page = 1;
        _hasReachedMax = false;
      });
    } else if (_hasLoaded) {
      return;
    } else {
      setState(() => _isLoading = true);
    }

    final result = await auth_di.sl<GetAdminUserActivityUseCase>()(
      GetAdminUserActivityParams(userId: userId, page: _page, limit: _pageSize),
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasLoaded = true;
        _errorMessage = failure.message;
        if (loadMore) _page--;
      }),
      (page) => setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasLoaded = true;
        _errorMessage = null;
        _hasReachedMax = page.hasReachedMax;

        if (refresh || _page == 1) {
          _activities
            ..clear()
            ..addAll(page.activities);
        } else {
          final existingIds = _activities.map((a) => a.id).toSet();
          _activities.addAll(
            page.activities.where((a) => !existingIds.contains(a.id)),
          );
        }
      }),
    );
  }

  void _onActivityTap(UserActivityEntity activity) {
    final postId = activityPostId(activity);
    if (postId != null) {
      openPostById(context, postId);
      return;
    }

    if (activity.type.toUpperCase() == 'SEND_GIFT') {
      final receiverId = activityReceiverId(activity);
      if (receiverId != null) {
        openUserProfile(
          context,
          userId: receiverId,
          username: activity.details['receiverUsername']?.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: l10n.adminActivityTitle,
        showBackButton: true,
        showBottomDivider: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadActivities(refresh: true),
        color: theme.colorScheme.primary,
        child: _buildBody(l10n, theme),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_targetUserId == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Text(
              l10n.loginRequiredMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      );
    }

    if (_isLoading) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: SettingsLayoutConstants.horizontalPadding,
            vertical: AppSizes.p12,
          ),
          child: SkeletonWidget(height: 72, borderRadius: AppSizes.radiusMd),
        ),
      );
    }

    if (_errorMessage != null && _activities.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      );
    }

    if (_activities.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.p32),
            child: Column(
              children: [
                Icon(
                  LucideIcons.activity,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
                const SizedBox(height: AppSizes.p16),
                Text(
                  l10n.adminActivityEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final localeName = l10n.localeName;

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: SettingsLayoutConstants.horizontalPadding,
        vertical: AppSizes.p8,
      ),
      itemCount: _activities.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.p8),
      itemBuilder: (context, index) {
        if (index >= _activities.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSizes.p16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final activity = _activities[index];
        final formatted = formatAdminActivityTime(
          activity.createdAt,
          localeName,
        );
        final timeLabel = formatted == null || formatted.isEmpty
            ? l10n.adminActivityJustNow
            : formatted;

        return _AdminActivityTile(
          activity: activity,
          typeLabel: adminActivityTypeLabel(activity.type, l10n),
          subtitle: adminActivitySubtitle(activity, l10n),
          timeLabel: timeLabel,
          icon: adminActivityIcon(activity.type),
          onTap: () => _onActivityTap(activity),
        );
      },
    );
  }
}

class _AdminActivityTile extends StatelessWidget {
  const _AdminActivityTile({
    required this.activity,
    required this.typeLabel,
    required this.subtitle,
    required this.timeLabel,
    required this.icon,
    required this.onTap,
  });

  final UserActivityEntity activity;
  final String typeLabel;
  final String subtitle;
  final String timeLabel;
  final IconData icon;
  final VoidCallback onTap;

  bool get _isTappable {
    if (activityPostId(activity) != null) return true;
    if (activity.type.toUpperCase() == 'SEND_GIFT' &&
        activityReceiverId(activity) != null) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(SettingsLayoutConstants.groupRadius),
      child: InkWell(
        onTap: _isTappable ? onTap : null,
        borderRadius: BorderRadius.circular(
          SettingsLayoutConstants.groupRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.p10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    SettingsLayoutConstants.iconContainerRadius,
                  ),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 22),
              ),
              const SizedBox(width: AppSizes.p12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CustomText(
                            typeLabel,
                            fontSize: SettingsLayoutConstants.itemTitleFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        CustomText(
                          timeLabel,
                          fontSize: SettingsLayoutConstants.trailingFontSize,
                          variant: TextVariant.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.p6),
                    Text(
                      subtitle,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.75,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isTappable) ...[
                const SizedBox(width: AppSizes.p4),
                Icon(
                  LucideIcons.chevronRight,
                  size: SettingsLayoutConstants.chevronSize,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
