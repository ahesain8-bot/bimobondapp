import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_text.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/presentation/widgets/profile_follow_button.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class MessagesSuggestionsStrip extends StatelessWidget {
  const MessagesSuggestionsStrip({
    required this.suggestions,
    required this.onFollowToggle,
    this.onSeeAll,
    this.loadingUserIds = const {},
    this.onFollowStateChanged,
    super.key,
  });

  final List<UserSuggestionEntity> suggestions;
  final Future<void> Function(int index) onFollowToggle;
  final VoidCallback? onSeeAll;
  final Set<String> loadingUserIds;
  final void Function(int index, bool isFollowing)? onFollowStateChanged;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MessagesLayoutConstants.sectionHorizontalPadding,
            24,
            MessagesLayoutConstants.sectionHorizontalPadding,
            12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.messagesPeopleYouMayKnow,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    l10n.messagesSeeAll,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: MessagesLayoutConstants.sectionLinkFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: MessagesLayoutConstants.suggestionsStripHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              final isFollowing = suggestion.isFollowing;
              final isLoading = loadingUserIds.contains(suggestion.id);
              final subtitle = messagesSuggestionReason(
                reason: suggestion.reason,
                mutualCount: suggestion.mutualCount,
                l10n: l10n,
              );

              Future<void> openProfile() async {
                final profileIsFollowing = await openUserProfile(
                  context,
                  userId: suggestion.id,
                  username: suggestion.username,
                  fullName: suggestion.fullName,
                  avatarUrl: suggestion.avatarUrl,
                  isFollowing: isFollowing,
                );
                if (profileIsFollowing != null) {
                  onFollowStateChanged?.call(index, profileIsFollowing);
                }
              }

              return Container(
                width: MessagesLayoutConstants.suggestionCardWidth,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(
                    MessagesLayoutConstants.suggestionCardRadius,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: theme.dividerColor.withValues(
                      alpha: MessagesLayoutConstants.dividerAlpha,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: openProfile,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              width: 2,
                            ),
                          ),
                          child: SafeNetworkAvatar(
                            imageUrl: suggestion.avatarUrl,
                            radius:
                                MessagesLayoutConstants.suggestionAvatarRadius,
                            fallbackText: suggestion.displayName,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      GestureDetector(
                        onTap: openProfile,
                        child: Text(
                          suggestion.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: AppSizes.p4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      ProfileFollowButton(
                        isFollowing: isFollowing,
                        isLoading: isLoading,
                        height: MessagesLayoutConstants
                            .suggestionFollowButtonHeight,
                        fontSize: 11,
                        onPressed: () => onFollowToggle(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
