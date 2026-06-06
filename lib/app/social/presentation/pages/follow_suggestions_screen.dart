import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_text.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_suggestions_usecase.dart';
import 'package:bimobondapp/app/social/presentation/utils/suggestion_follow_toggle.dart';
import 'package:bimobondapp/app/social/presentation/widgets/profile_follow_button.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FollowSuggestionsScreen extends StatefulWidget {
  const FollowSuggestionsScreen({super.key});

  @override
  State<FollowSuggestionsScreen> createState() =>
      _FollowSuggestionsScreenState();
}

class _FollowSuggestionsScreenState extends State<FollowSuggestionsScreen> {
  static const int _limit = 50;

  List<UserSuggestionEntity> _suggestions = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _followLoadingIds = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await social_di.sl<GetSuggestionsUseCase>()(
      const GetSuggestionsParams(limit: _limit),
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      }),
      (suggestions) => setState(() {
        _isLoading = false;
        _suggestions = suggestions
            .map(UserSuggestionEntity.from)
            .toList(growable: true);
      }),
    );
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

  Future<void> _toggleFollow(int index) async {
    if (!_ensureLoggedIn()) return;

    final suggestion = _suggestions[index];
    if (_followLoadingIds.contains(suggestion.id)) return;

    await toggleSuggestionFollow(
      context: context,
      suggestion: suggestion,
      onLoadingChanged: (userId, {required isLoading}) {
        setState(() {
          if (isLoading) {
            _followLoadingIds.add(userId);
          } else {
            _followLoadingIds.remove(userId);
          }
        });
      },
      onUpdate: (updated) {
        setState(() => _suggestions[index] = updated);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(title: l10n.messagesPeopleYouMayKnow),
      body: RefreshIndicator(
        onRefresh: _loadSuggestions,
        color: theme.colorScheme.primary,
        child: _buildBody(l10n, theme),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_isLoading) {
      return const FollowSuggestionsListSkeleton();
    }

    if (_errorMessage != null) {
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

    if (_suggestions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(
            height: 240,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 48,
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.messagesSuggestionsEmpty,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.4,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _suggestions.length,
      separatorBuilder: (context, _) => Divider(
        height: 1,
        indent: 72,
        color: theme.dividerColor.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        final isLoading = _followLoadingIds.contains(suggestion.id);
        final subtitle = messagesSuggestionReason(
          reason: suggestion.reason,
          mutualCount: suggestion.mutualCount,
          l10n: l10n,
        );

        Future<void> openProfile() async {
          final isFollowing = await openUserStoryOrProfile(
            context,
            userId: suggestion.id,
            username: suggestion.username,
            fullName: suggestion.fullName,
            avatarUrl: suggestion.avatarUrl,
            isFollowing: suggestion.isFollowing,
          );
          if (isFollowing != null && mounted) {
            setState(() {
              _suggestions[index] = suggestion.copyWith(
                isFollowing: isFollowing,
              );
            });
          }
        }

        return ListTile(
          onTap: openProfile,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: AppSizes.p4,
          ),
          leading: StoryProfileAvatar(
            userId: suggestion.id,
            imageUrl: suggestion.avatarUrl,
            radius: 24,
            fallbackText: suggestion.displayName,
            username: suggestion.username,
            fullName: suggestion.fullName,
            isFollowing: suggestion.isFollowing,
            onTap: openProfile,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  suggestion.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (suggestion.isVerified)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4),
                  child: Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          subtitle: subtitle.isNotEmpty
              ? Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.5,
                    ),
                  ),
                )
              : null,
          trailing: ProfileFollowButton.listTile(
            isFollowing: suggestion.isFollowing,
            isFollowedBy: suggestion.isFollowedBy,
            isLoading: isLoading,
            onPressed: () => _toggleFollow(index),
          ),
        );
      },
    );
  }
}
