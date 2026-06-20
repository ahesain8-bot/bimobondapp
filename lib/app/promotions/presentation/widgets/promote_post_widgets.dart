import 'package:bimobondapp/app/promotions/domain/entities/promotion_entities.dart';
import 'package:bimobondapp/app/promotions/presentation/widgets/promote_radius_map.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum PromoteStep { goal, audience, budget, overview }

String formatPromoteViews(int value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  }
  return value.toString();
}

class PromoteStepHeader extends StatelessWidget {
  const PromoteStepHeader({required this.stepLabel});

  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        stepLabel,
        style: theme.textTheme.titleSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Step 1: Goal ───────────────────────────────────────────────────────────

class PromoteGoalStep extends StatelessWidget {
  const PromoteGoalStep({
    super.key,
    required this.options,
    required this.selected,
    required this.packages,
    required this.onSelected,
    required this.onQuickPack,
  });

  final PromotionOptionsEntity? options;
  final String? selected;
  final List<PromotionPackageEntity> packages;
  final ValueChanged<String> onSelected;
  final VoidCallback onQuickPack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final objectives = options?.objectives ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (packages.length > 1)
          PromoteBorderedTile(
            onTap: onQuickPack,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.promoteQuickPack,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DirectionalChevronIcon(
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        if (packages.length > 1) const SizedBox(height: 20),
        Text(
          l10n.promoteStepGoalHeading,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.promoteStepGoalSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        PromoteBorderedGroup(
          children: [
            for (var i = 0; i < objectives.length; i++) ...[
              if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
              PromoteGoalRow(
                icon: promoteObjectiveIcon(objectives[i].value),
                title: objectives[i].label,
                subtitle: objectives[i].description,
                selected: objectives[i].value == selected,
                onTap: () => onSelected(objectives[i].value),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class PromoteGoalRow extends StatelessWidget {
  const PromoteGoalRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: scheme.onSurface),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            PromoteRadio(selected: selected),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: Audience ───────────────────────────────────────────────────────

class PromoteAudienceStep extends StatelessWidget {
  const PromoteAudienceStep({
    super.key,
    required this.options,
    required this.useCustom,
    required this.genders,
    required this.languages,
    required this.categoryIds,
    required this.ageMin,
    required this.ageMax,
    required this.useGeo,
    required this.radiusKm,
    required this.onModeChanged,
    required this.onGenderToggle,
    required this.onLanguageToggle,
    required this.onCategoryToggle,
    required this.onAgeChanged,
    required this.onGeoChanged,
    required this.onRadiusChanged,
  });

  final PromotionOptionsEntity? options;
  final bool useCustom;
  final Set<String> genders;
  final Set<String> languages;
  final Set<String> categoryIds;
  final int ageMin;
  final int ageMax;
  final bool useGeo;
  final int radiusKm;
  final ValueChanged<bool> onModeChanged;
  final void Function(String, bool) onGenderToggle;
  final void Function(String, bool) onLanguageToggle;
  final void Function(String, bool) onCategoryToggle;
  final void Function(int, int) onAgeChanged;
  final ValueChanged<bool> onGeoChanged;
  final ValueChanged<int> onRadiusChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          l10n.promoteAudienceTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.promoteStepAudienceSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        PromoteBorderedGroup(
          children: [
            InkWell(
              onTap: () => onModeChanged(false),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.promoteAudienceDefault,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.promoteAudienceDefaultHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PromoteRadio(selected: !useCustom),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            InkWell(
              onTap: () => onModeChanged(true),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.promoteAudienceCreateOwn,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DirectionalChevronIcon(
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    PromoteRadio(selected: useCustom),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (useCustom) ...[
          const SizedBox(height: 16),
          PromoteBorderedGroup(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: PromoteAudiencePanel(
                options: options,
                genders: genders,
                languages: languages,
                categoryIds: categoryIds,
                ageMin: ageMin,
                ageMax: ageMax,
                useGeo: useGeo,
                radiusKm: radiusKm,
                onGenderToggle: onGenderToggle,
                onLanguageToggle: onLanguageToggle,
                onCategoryToggle: onCategoryToggle,
                onAgeChanged: onAgeChanged,
                onGeoChanged: onGeoChanged,
                onRadiusChanged: onRadiusChanged,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Step 3: Budget ─────────────────────────────────────────────────────────

class PromoteBudgetStep extends StatelessWidget {
  const PromoteBudgetStep({
    super.key,
    required this.packages,
    required this.selectedId,
    required this.onSelected,
  });

  final List<PromotionPackageEntity> packages;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    PromotionPackageEntity? selected;
    for (final p in packages) {
      if (p.id == selectedId) {
        selected = p;
        break;
      }
    }

    final minViews = selected == null
        ? '0'
        : formatPromoteViews((selected.impressionCount * 0.75).round());
    final maxViews =
        selected == null ? '0' : formatPromoteViews(selected.impressionCount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (selected != null) ...[
          Text(
            l10n.promoteBudgetTotal(
              '\$${selected.priceUsd.toStringAsFixed(0)}',
            ),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.promoteEstimatedViews(minViews, maxViews),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            l10n.promoteEstimatedViewsLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          l10n.promoteBudgetTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.promoteStepBudgetSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        PromoteBorderedGroup(
          children: [
            for (var i = 0; i < packages.length; i++) ...[
              if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
              PromoteBudgetRow(
                package: packages[i],
                selected: packages[i].id == selectedId,
                showPopular: i == 1,
                onTap: () => onSelected(packages[i].id),
              ),
            ],
          ],
        ),
      ],
    );
  }

}

// ─── Step 4: Overview ───────────────────────────────────────────────────────

class PromoteOverviewStep extends StatelessWidget {
  const PromoteOverviewStep({
    super.key,
    required this.goalLabel,
    required this.audienceLabel,
    required this.package,
    required this.onEditGoal,
    required this.onEditAudience,
    required this.onEditBudget,
  });

  final String goalLabel;
  final String audienceLabel;
  final PromotionPackageEntity? package;
  final VoidCallback onEditGoal;
  final VoidCallback onEditAudience;
  final VoidCallback onEditBudget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final minViews = package == null
        ? '0'
        : formatPromoteViews((package!.impressionCount * 0.75).round());
    final maxViews = package == null
        ? '0'
        : formatPromoteViews(package!.impressionCount);
    final price = package?.priceUsd ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          l10n.promoteOverviewTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.promoteEstimatedViews(minViews, maxViews),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          l10n.promoteEstimatedViewsLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        PromoteBorderedGroup(
          children: [
            PromoteOverviewRow(
              label: l10n.promoteOverviewGoal,
              value: goalLabel,
              onTap: onEditGoal,
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            PromoteOverviewRow(
              label: l10n.promoteOverviewAudience,
              value: audienceLabel,
              onTap: onEditAudience,
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            PromoteOverviewRow(
              label: l10n.promoteOverviewBudget,
              value: package == null
                  ? '—'
                  : '\$${price.toStringAsFixed(0)} · ${package!.name}',
              onTap: onEditBudget,
            ),
          ],
        ),
        const SizedBox(height: 16),
        PromoteBorderedGroup(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                PromotePriceLine(
                  label: l10n.promoteOverviewSubtotal,
                  value: '\$${price.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 10),
                PromotePriceLine(
                  label: l10n.promoteOverviewTotal,
                  value: '\$${price.toStringAsFixed(2)}',
                  bold: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PromoteBudgetRow extends StatelessWidget {
  const PromoteBudgetRow({
    required this.package,
    required this.selected,
    required this.showPopular,
    required this.onTap,
  });

  final PromotionPackageEntity package;
  final bool selected;
  final bool showPopular;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '\$${package.priceUsd.toStringAsFixed(0)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (showPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.promotePopularBadge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    l10n.promoteImpressions(package.impressionCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PromoteRadio(selected: selected),
          ],
        ),
      ),
    );
  }
}

// ─── Overview rows ──────────────────────────────────────────────────────────

class PromoteOverviewRow extends StatelessWidget {
  const PromoteOverviewRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            DirectionalChevronIcon(
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class PromotePriceLine extends StatelessWidget {
  const PromotePriceLine({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: (bold
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyLarge)
              ?.copyWith(fontWeight: bold ? FontWeight.w800 : FontWeight.w500),
        ),
        Text(
          value,
          style: (bold
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyLarge)
              ?.copyWith(fontWeight: bold ? FontWeight.w800 : FontWeight.w500),
        ),
      ],
    );
  }
}

// ─── Shared widgets ─────────────────────────────────────────────────────────

class PromoteRadio extends StatelessWidget {
  const PromoteRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outline,
          width: selected ? 6 : 1.5,
        ),
        color: scheme.surface,
      ),
    );
  }
}

class PromoteBorderedGroup extends StatelessWidget {
  const PromoteBorderedGroup({this.child, this.children})
      : assert(child != null || children != null);

  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child ?? Column(children: children!),
    );
  }
}

class PromoteBorderedTile extends StatelessWidget {
  const PromoteBorderedTile({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: child,
      )),
    );
  }
}

class PromoteAudiencePanel extends StatelessWidget {
  const PromoteAudiencePanel({
    required this.options,
    required this.genders,
    required this.languages,
    required this.categoryIds,
    required this.ageMin,
    required this.ageMax,
    required this.useGeo,
    required this.radiusKm,
    required this.onGenderToggle,
    required this.onLanguageToggle,
    required this.onCategoryToggle,
    required this.onAgeChanged,
    required this.onGeoChanged,
    required this.onRadiusChanged,
  });

  final PromotionOptionsEntity? options;
  final Set<String> genders;
  final Set<String> languages;
  final Set<String> categoryIds;
  final int ageMin;
  final int ageMax;
  final bool useGeo;
  final int radiusKm;
  final void Function(String, bool) onGenderToggle;
  final void Function(String, bool) onLanguageToggle;
  final void Function(String, bool) onCategoryToggle;
  final void Function(int, int) onAgeChanged;
  final ValueChanged<bool> onGeoChanged;
  final ValueChanged<int> onRadiusChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.promoteAudienceGender,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (options?.genders ?? const []).map((g) {
            final selected = genders.contains(g.value);
            return PromotePill(
              label: g.label,
              selected: selected,
              onTap: () => onGenderToggle(g.value, !selected),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.promoteAgeRange,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$ageMin – $ageMax',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        RangeSlider(
          values: RangeValues(ageMin.toDouble(), ageMax.toDouble()),
          min: (options?.ageMin ?? 13).toDouble(),
          max: (options?.ageMax ?? 100).toDouble(),
          divisions: 20,
          activeColor: scheme.primary,
          onChanged: (v) => onAgeChanged(v.start.round(), v.end.round()),
        ),
        if ((options?.languages ?? const []).isNotEmpty) ...[
          Text(
            l10n.promoteLanguages,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (options?.languages ?? const []).map((lang) {
              final selected = languages.contains(lang.value);
              return PromotePill(
                label: lang.label,
                selected: selected,
                onTap: () => onLanguageToggle(lang.value, !selected),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if ((options?.categories ?? const []).isNotEmpty) ...[
          Text(
            l10n.promoteInterests,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (options?.categories ?? const []).map((cat) {
              final selected = categoryIds.contains(cat.id);
              return PromotePill(
                label: cat.name,
                selected: selected,
                onTap: () => onCategoryToggle(cat.id, !selected),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.promoteGeoTarget),
          subtitle: Text(
            l10n.promoteGeoTargetHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          value: useGeo,
          activeThumbColor: scheme.primary,
          onChanged: onGeoChanged,
        ),
        if (useGeo) ...[
          const SizedBox(height: 12),
          PromoteRadiusMapPreview(radiusKm: radiusKm),
          const SizedBox(height: 8),
          Text(
            l10n.promoteRadiusKm(radiusKm),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Slider(
            value: radiusKm.toDouble(),
            min: 1,
            max: 500,
            divisions: 49,
            activeColor: scheme.primary,
            onChanged: (v) => onRadiusChanged(v.round()),
          ),
        ],
      ],
    );
  }
}

class PromotePill extends StatelessWidget {
  const PromotePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? scheme.onSurface : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class PromoteBottomBar extends StatelessWidget {
  const PromoteBottomBar({
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: isLoading ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.45),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData promoteObjectiveIcon(String value) {
  switch (value) {
    case 'FOLLOWERS':
      return LucideIcons.userPlus;
    case 'ENGAGEMENT':
      return LucideIcons.heart;
    case 'CHALLENGES':
      return LucideIcons.trophy;
    case 'PROFILE_VISITS':
      return LucideIcons.user;
    case 'SALES':
      return LucideIcons.shoppingBag;
    case 'VIEWS':
    default:
      return LucideIcons.play;
  }
}
