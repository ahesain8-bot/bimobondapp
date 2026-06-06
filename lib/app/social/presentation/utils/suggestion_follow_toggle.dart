import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/presentation/utils/social_follow_toggle.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:flutter/material.dart';

Future<void> toggleSuggestionFollow({
  required BuildContext context,
  required UserSuggestionEntity suggestion,
  required void Function(UserSuggestionEntity updated) onUpdate,
  required void Function(String userId, {required bool isLoading}) onLoadingChanged,
}) async {
  final previousFollowing = suggestion.isFollowing;

  onLoadingChanged(suggestion.id, isLoading: true);
  onUpdate(
    UserSuggestionEntity.from(suggestion).copyWith(
      isFollowing: !previousFollowing,
    ),
  );

  final result = await toggleSocialUserFollow(
    userId: suggestion.id,
    wasFollowing: previousFollowing,
  );

  if (!context.mounted) return;

  if (result.failure != null) {
    onUpdate(
      UserSuggestionEntity.from(suggestion).copyWith(
        isFollowing: previousFollowing,
      ),
    );
    onLoadingChanged(suggestion.id, isLoading: false);
    PopupDialogs.showErrorDialog(context, result.failure!.message);
    return;
  }

  onUpdate(
    UserSuggestionEntity.from(suggestion).copyWith(
      isFollowing: result.isFollowing!,
    ),
  );
  onLoadingChanged(suggestion.id, isLoading: false);
}
