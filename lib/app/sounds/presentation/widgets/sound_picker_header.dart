import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Tabs + search / upload actions for the sound catalog sheet.
class SoundPickerHeader extends StatelessWidget {
  const SoundPickerHeader({
    super.key,
    required this.tabController,
    required this.tabLabels,
    required this.showSearch,
    required this.searchController,
    required this.uploading,
    required this.onToggleSearch,
    required this.onPickFromDevice,
    required this.onSearchSubmitted,
  });

  final TabController tabController;
  final List<String> tabLabels;
  final bool showSearch;
  final TextEditingController searchController;
  final bool uploading;
  final VoidCallback onToggleSearch;
  final VoidCallback onPickFromDevice;
  final VoidCallback onSearchSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: onSurface,
                  unselectedLabelColor: onSurface.withValues(alpha: 0.45),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  indicatorColor: onSurface,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  tabs: [
                    for (final label in tabLabels) Tab(text: label),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleSearch,
                icon: Icon(
                  showSearch ? LucideIcons.x : LucideIcons.search,
                  size: 22,
                  color: onSurface.withValues(alpha: 0.87),
                ),
              ),
              IconButton(
                onPressed: uploading ? null : onPickFromDevice,
                tooltip: l10n.soundPickFromFiles,
                icon: uploading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: onSurface.withValues(alpha: 0.87),
                        ),
                      )
                    : Icon(
                        LucideIcons.folderOpen,
                        size: 22,
                        color: onSurface.withValues(alpha: 0.87),
                      ),
              ),
            ],
          ),
        ),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.soundSearchHint,
                prefixIcon: Icon(
                  LucideIcons.search,
                  size: 20,
                  color: onSurface.withValues(alpha: 0.45),
                ),
                isDense: true,
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSearchSubmitted(),
            ),
          ),
        Divider(
          height: 1,
          color: onSurface.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}
