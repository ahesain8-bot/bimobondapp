import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
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

  final result = await social_di.sl<ToggleFollowUseCase>()(
    ToggleFollowParams(suggestion.id),
  );

  if (!context.mounted) return;

  result.fold(
    (failure) {
      onUpdate(
        UserSuggestionEntity.from(suggestion).copyWith(
          isFollowing: previousFollowing,
        ),
      );
      onLoadingChanged(suggestion.id, isLoading: false);
      PopupDialogs.showErrorDialog(context, failure.message);
    },
    (_) {
      onLoadingChanged(suggestion.id, isLoading: false);
    },
  );
}
