import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_suggestions_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart' as social_di;
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/tag_text_editing.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Bottom sheet to pick a user and insert `@username` into a text field.
class MentionPickerSheet extends StatefulWidget {
  const MentionPickerSheet({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => MentionPickerSheet(controller: controller),
    );
  }

  @override
  State<MentionPickerSheet> createState() => _MentionPickerSheetState();
}

class _MentionPickerSheetState extends State<MentionPickerSheet> {
  late final Future<List<UserSuggestionEntity>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _fetchSuggestions();
  }

  Future<List<UserSuggestionEntity>> _fetchSuggestions() async {
    final useCase = social_di.sl<GetSuggestionsUseCase>();
    final result = await useCase(const GetSuggestionsParams(limit: 30));
    return result.fold((_) => <UserSuggestionEntity>[], (list) => list);
  }

  void _select(UserSuggestionEntity user) {
    final username = user.username?.trim();
    if (username != null && username.isNotEmpty) {
      TagTextEditing.insertMention(widget.controller, username);
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop();
    openUserStoryOrProfile(
      context,
      userId: user.id,
      username: user.username,
      fullName: user.fullName,
      avatarUrl: user.avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.p16,
          AppSizes.p12,
          AppSizes.p16,
          bottom + AppSizes.p16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomText(
              l10n.mentionsLabel,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            const SizedBox(height: AppSizes.p4),
            CustomText(
              l10n.mentionsHint,
              fontSize: 13,
              variant: TextVariant.secondary,
            ),
            const SizedBox(height: AppSizes.p12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: FutureBuilder<List<UserSuggestionEntity>>(
                future: _loadFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final users = snapshot.data ?? const [];
                  if (users.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: CustomText(
                          l10n.messagesSuggestionsEmpty,
                          variant: TextVariant.secondary,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: users.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.5),
                    ),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: StoryProfileAvatar(
                          userId: user.id,
                          imageUrl: user.avatarUrl,
                          radius: 22,
                          fallbackText: user.username ?? user.displayName,
                          username: user.username,
                          fullName: user.fullName,
                          onTap: () => _select(user),
                        ),
                        title: CustomText(
                          user.displayName,
                          fontWeight: FontWeight.w600,
                        ),
                        subtitle: user.username != null
                            ? CustomText(
                                '@${user.username}',
                                fontSize: 13,
                                variant: TextVariant.secondary,
                              )
                            : null,
                        onTap: () => _select(user),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
