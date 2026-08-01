import 'package:bimobondapp/app/home/presentation/utils/post_filter_label.dart';
import 'package:bimobondapp/core/navigation/camera_filter_navigation.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok Effect House pill: dark capsule + gradient wand badge.
class PostFilterChip extends StatelessWidget {
  const PostFilterChip({
    required this.filterId,
    this.filterLabel,
    this.filterCategory,
    super.key,
  });

  final String filterId;
  final String? filterLabel;
  final String? filterCategory;

  static const LinearGradient _effectBadgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD60A), Color(0xFFFF8C42)],
  );

  Future<void> _onTap(BuildContext context) async {
    await openCameraWithPostFilter(
      context,
      filterId: filterId,
      filterCategory: filterCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isDisplayablePostFilterName(filterId)) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final label = postFilterDisplayLabel(l10n, filterId, apiName: filterLabel);

    return GestureDetector(
      onTap: () => _onTap(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.fromLTRB(3, 4, 9, 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 16,
                decoration: const BoxDecoration(
                  gradient: _effectBadgeGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  LucideIcons.wandSparkles,
                  size: 10,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
