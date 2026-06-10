import 'dart:async';

import 'package:bimobondapp/app/posts/domain/entities/hashtag_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_hashtags_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/app/posts/presentation/widgets/hashtag_suggestions_ui.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/hashtag_compose.dart';
import 'package:bimobondapp/core/utils/tag_text_editing.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class HashtagPickerSheet extends StatefulWidget {
  const HashtagPickerSheet({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
  }) {
    return GlassBottomSheet.showContent<void>(
      context,
      isScrollControlled: true,
      adaptTheme: true,
      child: HashtagPickerSheet(controller: controller),
    );
  }

  @override
  State<HashtagPickerSheet> createState() => _HashtagPickerSheetState();
}

class _HashtagPickerSheetState extends State<HashtagPickerSheet> {
  static const _debounce = Duration(milliseconds: 300);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<HashtagEntity> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_loadTags());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _loadTags());
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    final useCase = posts_di.sl<GetHashtagsUseCase>();
    final query = _searchController.text.trim();
    final result = await useCase(
      GetHashtagsParams(
        page: 1,
        limit: 30,
        search: query.isEmpty ? null : query,
        sort: query.isEmpty ? HashtagSort.popular : HashtagSort.name,
      ),
    );

    if (!mounted) return;

    result.fold(
      (_) => setState(() {
        _tags = [];
        _isLoading = false;
      }),
      (page) => setState(() {
        _tags = page.hashtags;
        _isLoading = false;
      }),
    );
  }

  void _select(HashtagEntity tag) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    var cursor = selection.isValid ? selection.baseOffset : text.length;
    if (cursor < 0) cursor = 0;

    final active = HashtagCompose.activeAt(text, cursor);
    if (active != null) {
      TagTextEditing.completeHashtag(
        widget.controller,
        hashtagStart: active.start,
        hashtagEnd: active.end,
        name: tag.name,
      );
    } else {
      TagTextEditing.insertHashtag(widget.controller, tag.name);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HashtagSuggestionsHeader(
            title: l10n.trendingHashtags,
            subtitle: l10n.searchHashtagsHint,
          ),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          HashtagSearchField(
            controller: _searchController,
            hintText: l10n.searchHashtagsHint,
          ),
          Flexible(
            child: HashtagSuggestionsBody(
              loading: _isLoading,
              tags: _tags,
              emptyLabel: l10n.noHashtagsFound,
              l10n: l10n,
              onSelect: _select,
              maxHeight: maxHeight * 0.5,
              padding: const EdgeInsets.fromLTRB(
                AppSizes.p12,
                0,
                AppSizes.p12,
                AppSizes.p16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
