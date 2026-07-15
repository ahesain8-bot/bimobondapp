import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum SearchResultsTab { top, users, videos, live, sounds, places }

/// TikTok-style result filter tabs under the search field.
class SearchResultsTabs extends StatelessWidget {
  const SearchResultsTabs({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final SearchResultsTab selected;
  final ValueChanged<SearchResultsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.45);

    final tabs = <(SearchResultsTab, String)>[
      (SearchResultsTab.top, l10n.searchTabTop),
      (SearchResultsTab.users, l10n.searchTabUsers),
      (SearchResultsTab.videos, l10n.searchTabVideos),
      (SearchResultsTab.live, l10n.searchTabLive),
      (SearchResultsTab.sounds, l10n.searchTabSounds),
      (SearchResultsTab.places, l10n.searchTabPlaces),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final (tab, label) = tabs[index];
          final isSelected = tab == selected;
          return GestureDetector(
            onTap: () => onChanged(tab),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? onSurface : muted,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 3,
                  width: isSelected ? 28 : 0,
                  decoration: BoxDecoration(
                    color: onSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
