import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comment_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_user_comments_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/social/presentation/widgets/user_comment_list_tile.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class UserCommentsScreen extends StatefulWidget {
  const UserCommentsScreen({
    this.userId,
    this.title,
    this.authorName,
    this.authorUsername,
    this.authorAvatarUrl,
    super.key,
  });

  final String? userId;
  final String? title;
  final String? authorName;
  final String? authorUsername;
  final String? authorAvatarUrl;

  @override
  State<UserCommentsScreen> createState() => _UserCommentsScreenState();
}

class _UserCommentsScreenState extends State<UserCommentsScreen> {
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  final List<UserCommentEntity> _comments = [];

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
    _loadComments(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String? get _targetUserId {
    final userId = widget.userId?.trim();
    if (userId == null || userId.isEmpty) return null;
    return userId;
  }

  SocialUserEntity? get _authorFallback {
    if (_targetUserId != null) {
      return SocialUserEntity(
        id: _targetUserId!,
        username: widget.authorUsername,
        fullName: widget.authorName,
        avatarUrl: widget.authorAvatarUrl,
      );
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      final user = authState.user;
      return SocialUserEntity(
        id: user.id,
        username: user.username,
        fullName: user.fullName,
        avatarUrl: user.avatarUrl,
      );
    }

    return null;
  }

  bool _ensureLoggedIn() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return true;

    final l10n = AppLocalizations.of(context)!;
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_hasReachedMax || _isLoading || _isLoadingMore) return;

    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent -
            ProfileLayoutConstants.scrollLoadMoreThreshold) {
      _loadComments(loadMore: true);
    }
  }

  Future<void> _loadComments({bool refresh = false, bool loadMore = false}) async {
    if (!_ensureLoggedIn()) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    if (loadMore) {
      if (_hasReachedMax || _isLoadingMore) return;
      setState(() => _isLoadingMore = true);
      _page++;
    } else if (refresh) {
      setState(() {
        _isLoading = _comments.isEmpty;
        _errorMessage = null;
        _page = 1;
        _hasReachedMax = false;
      });
    } else if (_hasLoaded) {
      return;
    } else {
      setState(() => _isLoading = true);
    }

    final result = await social_di.sl<GetUserCommentsUseCase>()(
      GetUserCommentsParams(
        userId: _targetUserId,
        page: _page,
        limit: _pageSize,
      ),
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

        if (refresh) {
          _comments
            ..clear()
            ..addAll(page.comments);
        } else {
          final existingIds = _comments.map((c) => c.id).toSet();
          _comments.addAll(
            page.comments.where((c) => !existingIds.contains(c.id)),
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : l10n.userCommentsTitle;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.light
          ? Colors.white
          : theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: title,
        showBackButton: true,
        backgroundColor: theme.brightness == Brightness.light
            ? Colors.white
            : theme.scaffoldBackgroundColor,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadComments(refresh: true),
        color: theme.colorScheme.primary,
        child: _buildBody(l10n, theme),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_isLoading) {
      return const UserCommentsListSkeleton();
    }

    if (_errorMessage != null && _comments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    if (_comments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l10n.userCommentsEmpty,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.5,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _comments.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _comments.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return UserCommentListTile(
          comment: _comments[index],
          authorFallback: _authorFallback,
          showDivider: index < _comments.length - 1,
        );
      },
    );
  }
}
