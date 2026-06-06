import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' as auth_di;
import 'package:bimobondapp/app/home/presentation/utils/active_stories_registry.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_image_preview.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum _ProfileAvatarChoice { photo, story }

/// Profile-screen avatar tap: choose profile photo and/or active story.
Future<void> handleProfileScreenAvatarTap(
  BuildContext context, {
  required String userId,
  String? avatarUrl,
}) async {
  final id = userId.trim();
  if (id.isEmpty) return;

  final l10n = AppLocalizations.of(context)!;
  final stories = auth_di.sl<ActiveStoriesRegistry>().activeStoriesFor(id);
  final hasStories = stories.isNotEmpty;
  final photoUrl = avatarUrl?.trim() ?? '';
  final hasPhoto =
      photoUrl.isNotEmpty && MediaUtils.isImage(photoUrl);

  if (hasStories && hasPhoto) {
    final choice = await showModalBottomSheet<_ProfileAvatarChoice>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.person_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.profileAvatarViewPhoto),
                onTap: () =>
                    Navigator.pop(ctx, _ProfileAvatarChoice.photo),
              ),
              ListTile(
                leading: Icon(
                  Icons.auto_stories_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.profileAvatarViewStory),
                onTap: () =>
                    Navigator.pop(ctx, _ProfileAvatarChoice.story),
              ),
              const SizedBox(height: AppSizes.p8),
            ],
          ),
        );
      },
    );

    if (!context.mounted || choice == null) return;
    switch (choice) {
      case _ProfileAvatarChoice.photo:
        await showChatImagePreview(context, imageUrl: photoUrl);
      case _ProfileAvatarChoice.story:
        await openUserActiveStories(context, id);
    }
    return;
  }

  if (hasStories) {
    await openUserActiveStories(context, id);
    return;
  }

  if (hasPhoto) {
    await showChatImagePreview(context, imageUrl: photoUrl);
    return;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.profileAvatarNoPhoto)),
    );
  }
}
