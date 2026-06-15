import 'package:bimobondapp/app/posts/domain/entities/hashtag_entity.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const hashtagAccent = Color(0xFF2ECC71);

/// White card shell for hashtag suggestion lists (inline or sheet).
class HashtagSuggestionsCard extends StatelessWidget {
  const HashtagSuggestionsCard({
    required this.child,
    this.margin = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTransparentSurface = theme.colorScheme.surface == Colors.transparent;

    final dropdownBgColor = isTransparentSurface
        ? Colors.black.withValues(alpha: 0.85)
        : (isDark ? const Color(0xFF1F1F1F) : Colors.white);

    final dropdownBorderColor = isTransparentSurface
        ? Colors.white.withValues(alpha: 0.15)
        : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: dropdownBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dropdownBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class HashtagSuggestionsHeader extends StatelessWidget {
  const HashtagSuggestionsHeader({
    required this.title,
    this.subtitle,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTransparentSurface = theme.colorScheme.surface == Colors.transparent;
    final iconSize = compact ? 28.0 : 36.0;

    final titleColor = isTransparentSurface || isDark ? Colors.white : theme.colorScheme.onSurface;
    final subtitleColor = isTransparentSurface || isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSizes.p10 : AppSizes.p16,
        compact ? AppSizes.p8 : AppSizes.p12,
        compact ? AppSizes.p10 : AppSizes.p16,
        compact ? AppSizes.p6 : AppSizes.p8,
      ),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hashtagAccent.withValues(alpha: 0.12),
              border: Border.all(
                color: hashtagAccent.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              LucideIcons.hash,
              color: hashtagAccent,
              size: compact ? 14 : 18,
            ),
          ),
          const SizedBox(width: AppSizes.p8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 12 : 15,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: compact ? 10 : 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HashtagSearchField extends StatelessWidget {
  const HashtagSearchField({
    required this.controller,
    required this.hintText,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTransparentSurface = theme.colorScheme.surface == Colors.transparent;

    final textColor = isTransparentSurface || isDark ? Colors.white : theme.colorScheme.onSurface;
    final hintColor = isTransparentSurface || isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant;
    final fillColor = isTransparentSurface
        ? Colors.white.withValues(alpha: 0.08)
        : (isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade50);
    final borderClr = isTransparentSurface
        ? Colors.white.withValues(alpha: 0.1)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p12,
        0,
        AppSizes.p12,
        AppSizes.p8,
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: hintColor,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            size: 16,
            color: hintColor,
          ),
          isDense: true,
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p10,
            vertical: AppSizes.p8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderClr),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderClr),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hashtagAccent.withValues(alpha: 0.65),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class HashtagSuggestionsBody extends StatelessWidget {
  const HashtagSuggestionsBody({
    required this.loading,
    required this.tags,
    required this.emptyLabel,
    required this.l10n,
    required this.onSelect,
    this.maxHeight = 168,
    this.padding = const EdgeInsets.fromLTRB(
      AppSizes.p8,
      0,
      AppSizes.p8,
      AppSizes.p8,
    ),
    super.key,
  });

  final bool loading;
  final List<HashtagEntity> tags;
  final String emptyLabel;
  final AppLocalizations l10n;
  final ValueChanged<HashtagEntity> onSelect;
  final double maxHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (loading && tags.isEmpty) {
      return Padding(
        padding: padding,
        child: const SizedBox(
          height: 72,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: hashtagAccent,
              ),
            ),
          ),
        ),
      );
    }

    if (tags.isEmpty) {
      return Padding(
        padding: padding,
        child: SizedBox(
          height: 64,
          child: Center(
            child: CustomText(
              emptyLabel,
              fontSize: 13,
              variant: TextVariant.secondary,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: tags.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSizes.p4),
          itemBuilder: (context, index) {
            return HashtagSuggestionTile(
              tag: tags[index],
              postCountLabel: l10n.hashtagPostCount(tags[index].postCount),
              onTap: () => onSelect(tags[index]),
            );
          },
        ),
      ),
    );
  }
}

class HashtagSuggestionTile extends StatelessWidget {
  const HashtagSuggestionTile({
    required this.tag,
    required this.postCountLabel,
    required this.onTap,
    super.key,
  });

  final HashtagEntity tag;
  final String postCountLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTransparentSurface = theme.colorScheme.surface == Colors.transparent;

    final tileBgColor = isTransparentSurface
        ? Colors.white.withValues(alpha: 0.08)
        : (isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade50);

    final tileBorderColor = isTransparentSurface
        ? Colors.white.withValues(alpha: 0.1)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200);

    final textColor = isTransparentSurface || isDark ? Colors.white : theme.colorScheme.onSurface;
    final postCountColor = isTransparentSurface || isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: hashtagAccent.withValues(alpha: 0.08),
        highlightColor: isTransparentSurface || isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        child: Ink(
          decoration: BoxDecoration(
            color: tileBgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tileBorderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.p8,
              vertical: AppSizes.p6,
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: hashtagAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.hash,
                    size: 13,
                    color: hashtagAccent,
                  ),
                ),
                const SizedBox(width: AppSizes.p8),
                Expanded(
                  child: Text(
                    '#${tag.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.p6),
                Text(
                  postCountLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: postCountColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
