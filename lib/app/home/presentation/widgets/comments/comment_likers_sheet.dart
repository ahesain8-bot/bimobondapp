import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_comment_likes_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/presentation/utils/social_follow_toggle.dart';
import 'package:bimobondapp/app/social/presentation/widgets/social_user_list_tile.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sheet listing users who liked a comment (for the comment author).
class CommentLikersSheet extends StatefulWidget {
  const CommentLikersSheet({required this.commentId, super.key});

  final String commentId;

  static Future<void> show(BuildContext context, {required String commentId}) {
    return GlassBottomSheet.showContent<void>(
      context,
      isScrollControlled: true,
      title: AppLocalizations.of(context)!.likes,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: CommentLikersSheet(commentId: commentId),
      ),
    );
  }

  @override
  State<CommentLikersSheet> createState() => _CommentLikersSheetState();
}

class _CommentLikersSheetState extends State<CommentLikersSheet> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<SocialUserEntity> _users = [];
  final Set<String> _followLoadingIds = {};

  int _page = 1;
  bool _hasReachedMax = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return authState.user.id;
    return null;
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _hasReachedMax || _isLoadingMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      _load(loadMore: true);
    }
  }

  Future<void> _load({bool refresh = false, bool loadMore = false}) async {
    if (_isLoading || _isLoadingMore) return;
    if (loadMore && _hasReachedMax) return;

    if (refresh) {
      _page = 1;
      _hasReachedMax = false;
      _errorMessage = null;
    }

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = _users.isEmpty;
      }
    });

    final result = await posts_di.sl<GetCommentLikesUseCase>()(
      GetCommentLikesParams(
        commentId: widget.commentId,
        page: _page,
        limit: _pageSize,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = failure.message;
        if (refresh) _users.clear();
      }),
      (page) => setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
        _hasReachedMax = page.page >= page.lastPage;
        if (refresh) {
          _users
            ..clear()
            ..addAll(page.users);
        } else {
          final existing = _users.map((u) => u.id).toSet();
          _users.addAll(page.users.where((u) => !existing.contains(u.id)));
        }
        if (!loadMore || page.users.isNotEmpty) {
          _page++;
        }
      }),
    );
  }

  Future<void> _toggleFollow(int index, SocialUserEntity user) async {
    if (user.id == _currentUserId || _followLoadingIds.contains(user.id)) {
      return;
    }

    final previous = user.isFollowing;
    setState(() {
      _followLoadingIds.add(user.id);
      _users[index] = user.copyWith(isFollowing: !previous);
    });

    final result = await toggleSocialUserFollow(
      userId: user.id,
      wasFollowing: previous,
    );
    if (!mounted) return;

    setState(() {
      _followLoadingIds.remove(user.id);
      if (result.failure != null) {
        _users[index] = user.copyWith(isFollowing: previous);
      } else if (result.isFollowing != null) {
        _users[index] = user.copyWith(isFollowing: result.isFollowing!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final skeletonTone = theme.brightness == Brightness.dark
        ? LiquidGlassSkeletonTone.standard
        : LiquidGlassSkeletonTone.light;

    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p12,
        ),
        itemCount: 8,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.p16),
          child: Row(
            children: [
              LiquidGlassSkeletonBox.circular(size: 44, tone: skeletonTone),
              const SizedBox(width: AppSizes.p12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LiquidGlassSkeletonBox(
                      height: 14,
                      width: 120,
                      tone: skeletonTone,
                    ),
                    const SizedBox(height: 6),
                    LiquidGlassSkeletonBox(
                      height: 12,
                      width: 80,
                      tone: skeletonTone,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomText(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _load(refresh: true),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(child: CustomText(l10n.postLikesEmpty));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        AppSizes.p8,
        AppSizes.p16,
        AppSizes.p24,
      ),
      itemCount: _users.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _users.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final user = _users[index];
        final isSelf = user.id == _currentUserId;
        return SocialUserListTile(
          user: user,
          isSelf: isSelf,
          hideFollowButton: isSelf,
          isFollowLoading: _followLoadingIds.contains(user.id),
          onFollowTap: isSelf ? null : () => _toggleFollow(index, user),
          onProfileFollowStateChanged: (isFollowing) {
            setState(() {
              _users[index] = user.copyWith(isFollowing: isFollowing);
            });
          },
        );
      },
    );
  }
}
