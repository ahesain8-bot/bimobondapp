import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/presentation/services/mention_friends_source.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/mention_compose.dart';
import 'package:bimobondapp/core/utils/tag_text_editing.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Lays out the optional suggestions panel and the [TextField].
typedef MentionComposerLayoutBuilder = Widget Function(
  BuildContext context,
  Widget? suggestions,
  Widget textField,
);

/// Text field that shows a friends list while typing `@` + letters.
class MentionComposerField extends StatefulWidget {
  const MentionComposerField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.layoutBuilder,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final MentionComposerLayoutBuilder? layoutBuilder;

  @override
  State<MentionComposerField> createState() => _MentionComposerFieldState();
}

class _MentionComposerFieldState extends State<MentionComposerField> {
  ActiveMentionQuery? _activeQuery;
  List<SocialUserEntity> _suggestions = const [];
  bool _loadingFriends = false;
  List<SocialUserEntity> _friends = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _preloadPeople();
  }

  @override
  void didUpdateWidget(covariant MentionComposerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  Future<void> _preloadPeople() async {
    final people = await MentionFriendsSource.ensureLoaded();
    if (!mounted) return;
    setState(() => _friends = people);
    final active = _activeQuery;
    if (active != null) {
      _applyFilter(active);
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    var cursor = selection.isValid ? selection.baseOffset : text.length;
    if (cursor < 0) cursor = 0;

    final active = MentionCompose.activeAt(text, cursor);

    if (active == null) {
      if (_activeQuery != null) {
        setState(() {
          _activeQuery = null;
          _suggestions = const [];
        });
      }
      return;
    }

    final queryChanged = _activeQuery?.query != active.query ||
        _activeQuery?.start != active.start;
    setState(() => _activeQuery = active);

    if (_friends.isNotEmpty) {
      _applyFilter(active);
      return;
    }

    if (queryChanged || _suggestions.isEmpty) {
      _refreshSuggestions(active);
    }
  }

  void _applyFilter(ActiveMentionQuery active) {
    if (!mounted) return;
    setState(
      () => _suggestions = MentionFriendsSource.filter(_friends, active.query),
    );
  }

  Future<void> _refreshSuggestions(ActiveMentionQuery active) async {
    if (!_loadingFriends) {
      setState(() => _loadingFriends = true);
      _friends = await MentionFriendsSource.ensureLoaded();
      if (!mounted) return;
      setState(() => _loadingFriends = false);
    }

    if (_activeQuery?.start != active.start || _activeQuery?.query != active.query) {
      return;
    }
    _applyFilter(active);
  }

  void _pickUser(SocialUserEntity user) {
    final active = _activeQuery;
    final username = user.username?.trim();
    if (active == null || username == null || username.isEmpty) return;

    TagTextEditing.completeMention(
      widget.controller,
      mentionStart: active.start,
      mentionEnd: active.end,
      username: username,
    );
    setState(() {
      _activeQuery = null;
      _suggestions = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final showList = _activeQuery != null;

    final suggestions = showList
        ? _MentionSuggestionsList(
            loading: _loadingFriends && _suggestions.isEmpty,
            suggestions: _suggestions,
            emptyLabel: _friends.isEmpty && !_loadingFriends
                ? l10n.connectionsEmptyFriends
                : l10n.messagesNoResults,
            theme: theme,
            onPick: _pickUser,
          )
        : null;

    final textField = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      style: widget.style,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      decoration: widget.decoration,
    );

    final layout = widget.layoutBuilder;
    if (layout != null) {
      return layout(context, suggestions, textField);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suggestions != null) suggestions,
        textField,
      ],
    );
  }
}

class _MentionSuggestionsList extends StatelessWidget {
  const _MentionSuggestionsList({
    required this.loading,
    required this.suggestions,
    required this.emptyLabel,
    required this.theme,
    required this.onPick,
  });

  final bool loading;
  final List<SocialUserEntity> suggestions;
  final String emptyLabel;
  final ThemeData theme;
  final void Function(SocialUserEntity user) onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(AppSizes.p12),
      color: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(AppSizes.p16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : suggestions.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSizes.p12),
                child: CustomText(
                  emptyLabel,
                  fontSize: 13,
                  variant: TextVariant.secondary,
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.p4),
                itemCount: suggestions.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, index) {
                  final user = suggestions[index];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: StoryProfileAvatar(
                      userId: user.id,
                      imageUrl: user.avatarUrl,
                      radius: 18,
                      fallbackText: user.username ?? user.displayName,
                      username: user.username,
                      fullName: user.fullName,
                      onTap: () => onPick(user),
                    ),
                    title: CustomText(
                      user.displayName,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    subtitle: user.username != null
                        ? CustomText(
                            '@${user.username}',
                            fontSize: 12,
                            variant: TextVariant.secondary,
                          )
                        : null,
                    onTap: () => onPick(user),
                  );
                },
              ),
      ),
    );
  }
}
