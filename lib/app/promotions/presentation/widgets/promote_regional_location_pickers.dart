import 'package:bimobondapp/app/promotions/presentation/widgets/promotion_ui.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:countrify/countrify.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _excludedCountryCodes = {'IL'};

class PromoteGlassDropdownField extends StatelessWidget {
  const PromoteGlassDropdownField({
    required this.label,
    required this.hint,
    required this.onTap,
    this.value,
    this.enabled = true,
    this.leading,
    super.key,
  });

  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final bool enabled;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = value ?? hint;
    final isPlaceholder = value == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PromotionUi.fieldLabel(context, enabled: enabled)),
        const SizedBox(height: 8),
        Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: Ink(
                decoration: PromotionUi.dropdownDecoration(context),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.p12,
                  vertical: AppSizes.p12,
                ),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: AppSizes.p10),
                    ],
                    Expanded(
                      child: Text(
                        displayText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PromotionUi.dropdownValue(
                          context,
                          isPlaceholder: isPlaceholder,
                        ),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronDown,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PromoteRegionalLocationPickers extends StatefulWidget {
  const PromoteRegionalLocationPickers({
    required this.onChanged,
    super.key,
  });

  final ValueChanged<CountryStateCitySelection> onChanged;

  @override
  State<PromoteRegionalLocationPickers> createState() =>
      _PromoteRegionalLocationPickersState();
}

class _PromoteRegionalLocationPickersState
    extends State<PromoteRegionalLocationPickers> {
  Country? _country;
  CountryState? _state;
  City? _city;

  void _emit() {
    widget.onChanged(
      CountryStateCitySelection(country: _country, state: _state, city: _city),
    );
  }

  String _countryLabel(Country country) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'en') return country.name;
    return CountryUtils.getCountryNameInLanguage(country, locale);
  }

  Future<void> _pickCountry() async {
    final l10n = AppLocalizations.of(context)!;
    final countries = CountryUtils.getAllCountries()
        .where(
          (country) =>
              !_excludedCountryCodes.contains(country.alpha2Code.toUpperCase()),
        )
        .toList()
      ..sort(
        (a, b) => _countryLabel(a).compareTo(_countryLabel(b)),
      );

    final selected = await _showSearchSheet<Country>(
      title: l10n.promoteSelectCountry,
      searchHint: l10n.promoteSelectCountryHint,
      items: countries,
      labelOf: _countryLabel,
      selected: _country,
      leadingBuilder: (country) => CountryFlag(
        country: country,
        size: const Size(28, 20),
        borderRadius: BorderRadius.circular(4),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() {
      _country = selected;
      _state = null;
      _city = null;
    });
    _emit();
  }

  Future<void> _pickRegion() async {
    if (_country == null) return;
    final l10n = AppLocalizations.of(context)!;
    final states =
        await GeoRepository.instance.statesOf(_country!.alpha2Code);
    if (!mounted) return;
    states.sort((a, b) => a.name.compareTo(b.name));

    final selected = await _showSearchSheet<CountryState>(
      title: l10n.promoteSelectRegion,
      searchHint: l10n.promoteSelectRegionHint,
      items: states,
      labelOf: (state) => state.name,
      selected: _state,
    );

    if (selected == null || !mounted) return;
    setState(() {
      _state = selected;
      _city = null;
    });
    _emit();
  }

  Future<void> _pickTown() async {
    if (_state == null) return;
    final l10n = AppLocalizations.of(context)!;
    final cities = await GeoRepository.instance.citiesOf(_state!.id);
    if (!mounted) return;
    cities.sort((a, b) => a.name.compareTo(b.name));

    final selected = await _showSearchSheet<City>(
      title: l10n.promoteSelectTown,
      searchHint: l10n.promoteSelectTownHint,
      items: cities,
      labelOf: (city) => city.name,
      selected: _city,
    );

    if (selected == null || !mounted) return;
    setState(() => _city = selected);
    _emit();
  }

  Future<T?> _showSearchSheet<T>({
    required String title,
    required String searchHint,
    required List<T> items,
    required String Function(T) labelOf,
    T? selected,
    Widget Function(T)? leadingBuilder,
  }) {
    return GlassBottomSheet.showDraggable<T>(
      context,
      title: title,
      adaptTheme: true,
      builder: (context, scrollController) {
        return _PromoteGeoSearchSheetBody<T>(
          searchHint: searchHint,
          items: items,
          labelOf: labelOf,
          selected: selected,
          scrollController: scrollController,
          leadingBuilder: leadingBuilder,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PromoteGlassDropdownField(
          label: l10n.promoteSelectCountry,
          hint: l10n.promoteSelectCountryHint,
          value: _country == null ? null : _countryLabel(_country!),
          leading: _country == null
              ? null
              : CountryFlag(
                  country: _country!,
                  size: const Size(28, 20),
                  borderRadius: BorderRadius.circular(4),
                ),
          onTap: _pickCountry,
        ),
        const SizedBox(height: 12),
        PromoteGlassDropdownField(
          label: l10n.promoteSelectRegion,
          hint: l10n.promoteSelectRegionHint,
          value: _state?.name,
          enabled: _country != null,
          onTap: _pickRegion,
        ),
        const SizedBox(height: 12),
        PromoteGlassDropdownField(
          label: l10n.promoteSelectTown,
          hint: l10n.promoteSelectTownHint,
          value: _city?.name,
          enabled: _state != null,
          onTap: _pickTown,
        ),
      ],
    );
  }
}

class _PromoteGeoSearchSheetBody<T> extends StatefulWidget {
  const _PromoteGeoSearchSheetBody({
    required this.searchHint,
    required this.items,
    required this.labelOf,
    required this.scrollController,
    this.selected,
    this.leadingBuilder,
  });

  final String searchHint;
  final List<T> items;
  final String Function(T) labelOf;
  final T? selected;
  final ScrollController scrollController;
  final Widget Function(T)? leadingBuilder;

  @override
  State<_PromoteGeoSearchSheetBody<T>> createState() =>
      _PromoteGeoSearchSheetBodyState<T>();
}

class _PromoteGeoSearchSheetBodyState<T>
    extends State<_PromoteGeoSearchSheetBody<T>> {
  final TextEditingController _searchController = TextEditingController();
  late List<T> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = SearchNormalizer.foldAccents(_searchController.text);
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.items;
        return;
      }
      _filtered = widget.items
          .where(
            (item) => SearchNormalizer.foldAccents(widget.labelOf(item))
                .contains(query),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchController,
            style: theme.textTheme.bodyLarge,
            cursorColor: theme.colorScheme.primary,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: Icon(
                LucideIcons.search,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p12,
                vertical: AppSizes.p12,
              ),
            ),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    l10n.messagesNoResults,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.only(bottom: AppSizes.p16),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final item = _filtered[index];
                    final isSelected = identical(item, widget.selected);
                    final leading = widget.leadingBuilder?.call(item);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              if (leading != null) ...[
                                leading,
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Text(
                                  widget.labelOf(item),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  LucideIcons.check,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
