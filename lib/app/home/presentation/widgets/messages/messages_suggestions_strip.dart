import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_text.dart';
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
    this.loadingIndexes = const {},
    super.key,
  });

  final List<Map<String, dynamic>> suggestions;
  final Future<void> Function(int index) onFollowToggle;
  final Set<int> loadingIndexes;

  @override
  Widget build(BuildContext context) {
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
              Text(
                l10n.messagesSeeAll,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: MessagesLayoutConstants.sectionLinkFontSize,
                  fontWeight: FontWeight.w700,
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
              final user = suggestions[index];
              final isFollowing = user['isFollowing'] as bool? ?? false;
              final isLoading = loadingIndexes.contains(index);
              final userId = user['userId'] as String? ?? '';
              final name = user['name'] as String;
              final image = user['image'] as String;
              final bio = messagesSuggestionBio(
                user['bioKey'] as String?,
                l10n,
              );

              void openProfile() {
                if (userId.isEmpty) return;
                openUserProfile(
                  context,
                  userId: userId,
                  username: name,
                  avatarUrl: image,
                  isFollowing: isFollowing,
                );
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          PositionedDirectional(
                            top: -6,
                            end: -6,
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.2),
                            ),
                          ),
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
                                imageUrl: image,
                                radius: MessagesLayoutConstants
                                    .suggestionAvatarRadius,
                                fallbackText: name,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.p12),
                      GestureDetector(
                        onTap: openProfile,
                        child: Text(
                          name,
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
                        bio,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: MessagesLayoutConstants
                            .suggestionFollowButtonHeight,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () => onFollowToggle(index),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing
                                ? theme.dividerColor.withValues(alpha: 0.05)
                                : theme.colorScheme.primary,
                            foregroundColor: isFollowing
                                ? theme.textTheme.bodyLarge?.color
                                : Colors.white,
                            disabledBackgroundColor: isFollowing
                                ? theme.dividerColor.withValues(alpha: 0.05)
                                : theme.colorScheme.primary.withValues(
                                    alpha: 0.5,
                                  ),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isFollowing
                                        ? theme.textTheme.bodyLarge?.color
                                        : Colors.white,
                                  ),
                                )
                              : Text(
                                  isFollowing
                                      ? l10n.messagesFollowing
                                      : l10n.messagesFollow,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
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
