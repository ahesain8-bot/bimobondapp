import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_my_mentions_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/social/presentation/widgets/user_mention_list_tile.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class UserMentionsScreen extends StatefulWidget {
  const UserMentionsScreen({super.key});

  @override
  State<UserMentionsScreen> createState() => _UserMentionsScreenState();
}

class _UserMentionsScreenState extends State<UserMentionsScreen> {
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  final List<UserMentionEntity> _mentions = [];

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
    _loadMentions(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
      _loadMentions(loadMore: true);
    }
  }

  Future<void> _loadMentions({
    bool refresh = false,
    bool loadMore = false,
  }) async {
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
        _isLoading = _mentions.isEmpty;
        _errorMessage = null;
        _page = 1;
        _hasReachedMax = false;
      });
    } else if (_hasLoaded) {
      return;
    } else {
      setState(() => _isLoading = true);
    }

    final result = await social_di.sl<GetMyMentionsUseCase>()(
      GetMyMentionsParams(
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
          _mentions
            ..clear()
            ..addAll(page.mentions);
        } else {
          final existingIds = _mentions.map((m) => m.id).toSet();
          _mentions.addAll(
            page.mentions.where((m) => !existingIds.contains(m.id)),
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(title: l10n.userMentionsTitle),
      body: RefreshIndicator(
        onRefresh: () => _loadMentions(refresh: true),
        color: theme.colorScheme.primary,
        child: _buildBody(l10n, theme),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_isLoading) {
      return const UserMentionsListSkeleton();
    }

    if (_errorMessage != null && _mentions.isEmpty) {
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

    if (_mentions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              l10n.userMentionsEmpty,
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

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: _mentions.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (context, _) => Divider(
        height: 1,
        color: theme.dividerColor.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, index) {
        if (index >= _mentions.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return UserMentionListTile(mention: _mentions[index]);
      },
    );
  }
}
