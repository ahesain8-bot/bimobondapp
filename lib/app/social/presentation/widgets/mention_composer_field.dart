import 'dart:async';

import 'package:bimobondapp/app/posts/domain/entities/hashtag_entity.dart';
import 'package:bimobondapp/app/posts/presentation/services/hashtag_suggestions_source.dart';
import 'package:bimobondapp/app/posts/presentation/widgets/hashtag_suggestions_ui.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/presentation/services/mention_friends_source.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/hashtag_compose.dart';
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

enum _ComposeSuggestionMode { mention, hashtag }

/// Text field with inline `@` people and `#` hashtag suggestions.
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
  static const _hashtagDebounce = Duration(milliseconds: 280);

  _ComposeSuggestionMode? _mode;
  ActiveMentionQuery? _mentionQuery;
  ActiveHashtagQuery? _hashtagQuery;
  List<SocialUserEntity> _mentionSuggestions = const [];
  List<HashtagEntity> _hashtagSuggestions = const [];
  bool _loadingFriends = false;
  bool _loadingHashtags = false;
  List<SocialUserEntity> _friends = const [];
  Timer? _hashtagDebounceTimer;
  int _hashtagRequestId = 0;

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
    _hashtagDebounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  Future<void> _preloadPeople() async {
    final people = await MentionFriendsSource.ensureLoaded();
    if (!mounted) return;
    setState(() => _friends = people);
    final active = _mentionQuery;
    if (_mode == _ComposeSuggestionMode.mention && active != null) {
      _applyMentionFilter(active);
    }
  }

  void _clearSuggestions() {
    _hashtagDebounceTimer?.cancel();
    setState(() {
      _mode = null;
      _mentionQuery = null;
      _hashtagQuery = null;
      _mentionSuggestions = const [];
      _hashtagSuggestions = const [];
    });
  }

  _ComposeSuggestionMode? _resolveMode(
    ActiveMentionQuery? mention,
    ActiveHashtagQuery? hashtag,
  ) {
    if (mention == null && hashtag == null) return null;
    if (mention == null) return _ComposeSuggestionMode.hashtag;
    if (hashtag == null) return _ComposeSuggestionMode.mention;
    return mention.start >= hashtag.start
        ? _ComposeSuggestionMode.mention
        : _ComposeSuggestionMode.hashtag;
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    var cursor = selection.isValid ? selection.baseOffset : text.length;
    if (cursor < 0) cursor = 0;

    final mention = MentionCompose.activeAt(text, cursor);
    final hashtag = HashtagCompose.activeAt(text, cursor);
    final mode = _resolveMode(mention, hashtag);

    if (mode == null) {
      if (_mode != null) _clearSuggestions();
      return;
    }

    if (mode == _ComposeSuggestionMode.mention && mention != null) {
      _hashtagDebounceTimer?.cancel();
      final queryChanged = _mentionQuery?.query != mention.query ||
          _mentionQuery?.start != mention.start ||
          _mode != mode;
      setState(() {
        _mode = mode;
        _mentionQuery = mention;
        _hashtagQuery = null;
        _hashtagSuggestions = const [];
      });

      if (_friends.isNotEmpty) {
        _applyMentionFilter(mention);
        return;
      }

      if (queryChanged || _mentionSuggestions.isEmpty) {
        _refreshMentionSuggestions(mention);
      }
      return;
    }

    if (mode == _ComposeSuggestionMode.hashtag && hashtag != null) {
      final queryChanged = _hashtagQuery?.query != hashtag.query ||
          _hashtagQuery?.start != hashtag.start ||
          _mode != mode;
      setState(() {
        _mode = mode;
        _hashtagQuery = hashtag;
        _mentionQuery = null;
        _mentionSuggestions = const [];
      });

      if (queryChanged || _hashtagSuggestions.isEmpty) {
        _scheduleHashtagRefresh(hashtag);
      }
    }
  }

  void _applyMentionFilter(ActiveMentionQuery active) {
    if (!mounted) return;
    setState(
      () => _mentionSuggestions =
          MentionFriendsSource.filter(_friends, active.query),
    );
  }

  Future<void> _refreshMentionSuggestions(ActiveMentionQuery active) async {
    if (!_loadingFriends) {
      setState(() => _loadingFriends = true);
      _friends = await MentionFriendsSource.ensureLoaded();
      if (!mounted) return;
      setState(() => _loadingFriends = false);
    }

    if (_mentionQuery?.start != active.start ||
        _mentionQuery?.query != active.query) {
      return;
    }
    _applyMentionFilter(active);
  }

  void _scheduleHashtagRefresh(ActiveHashtagQuery active) {
    _hashtagDebounceTimer?.cancel();
    _hashtagDebounceTimer = Timer(_hashtagDebounce, () {
      unawaited(_refreshHashtagSuggestions(active));
    });
  }

  Future<void> _refreshHashtagSuggestions(ActiveHashtagQuery active) async {
    final requestId = ++_hashtagRequestId;
    setState(() => _loadingHashtags = true);

    final tags = await HashtagSuggestionsSource.search(active.query);

    if (!mounted || requestId != _hashtagRequestId) return;
    if (_hashtagQuery?.start != active.start ||
        _hashtagQuery?.query != active.query) {
      setState(() => _loadingHashtags = false);
      return;
    }

    setState(() {
      _hashtagSuggestions = tags;
      _loadingHashtags = false;
    });
  }

  void _pickUser(SocialUserEntity user) {
    final active = _mentionQuery;
    final username = user.username?.trim();
    if (active == null || username == null || username.isEmpty) return;

    TagTextEditing.completeMention(
      widget.controller,
      mentionStart: active.start,
      mentionEnd: active.end,
      username: username,
    );
    _clearSuggestions();
  }

  void _pickHashtag(HashtagEntity tag) {
    final active = _hashtagQuery;
    if (active == null) return;

    TagTextEditing.completeHashtag(
      widget.controller,
      hashtagStart: active.start,
      hashtagEnd: active.end,
      name: tag.name,
    );
    _clearSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final Widget? suggestions;
    if (_mode == _ComposeSuggestionMode.mention) {
      suggestions = _MentionSuggestionsList(
        loading: _loadingFriends && _mentionSuggestions.isEmpty,
        suggestions: _mentionSuggestions,
        emptyLabel: _friends.isEmpty && !_loadingFriends
            ? l10n.connectionsEmptyFriends
            : l10n.messagesNoResults,
        theme: theme,
        onPick: _pickUser,
      );
    } else if (_mode == _ComposeSuggestionMode.hashtag) {
      suggestions = _HashtagSuggestionsList(
        loading: _loadingHashtags && _hashtagSuggestions.isEmpty,
        suggestions: _hashtagSuggestions,
        emptyLabel: l10n.noHashtagsFound,
        l10n: l10n,
        onPick: _pickHashtag,
      );
    } else {
      suggestions = null;
    }

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

class _HashtagSuggestionsList extends StatelessWidget {
  const _HashtagSuggestionsList({
    required this.loading,
    required this.suggestions,
    required this.emptyLabel,
    required this.l10n,
    required this.onPick,
  });

  final bool loading;
  final List<HashtagEntity> suggestions;
  final String emptyLabel;
  final AppLocalizations l10n;
  final void Function(HashtagEntity tag) onPick;

  @override
  Widget build(BuildContext context) {
    return HashtagSuggestionsCard(
      margin: const EdgeInsets.only(bottom: AppSizes.p6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HashtagSuggestionsHeader(
            title: l10n.trendingHashtags,
            compact: true,
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          HashtagSuggestionsBody(
            loading: loading,
            tags: suggestions,
            emptyLabel: emptyLabel,
            l10n: l10n,
            onSelect: onPick,
          ),
        ],
      ),
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
