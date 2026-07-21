import 'dart:async';

import 'package:bimobondapp/app/countries/domain/entities/country_entity.dart';
import 'package:bimobondapp/app/countries/domain/usecases/get_countries_usecase.dart';
import 'package:bimobondapp/app/countries/domain/usecases/get_country_cities_usecase.dart';
import 'package:bimobondapp/app/countries/presentation/di/countries_injector.dart'
    as countries_di;
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddPostLocationSelection {
  const AddPostLocationSelection({required this.country, required this.city});

  final CountryEntity country;
  final CityEntity city;

  String get displayLabel => '${city.name}, ${country.name}';
}

/// Full-screen location picker: search countries/cities by text.
class AddPostLocationSearchScreen extends StatefulWidget {
  const AddPostLocationSearchScreen({this.initial, super.key});

  final AddPostLocationSelection? initial;

  static Future<AddPostLocationSelection?> open(
    BuildContext context, {
    AddPostLocationSelection? initial,
  }) {
    return Navigator.of(context).push<AddPostLocationSelection>(
      MaterialPageRoute(
        builder: (_) => AddPostLocationSearchScreen(initial: initial),
      ),
    );
  }

  @override
  State<AddPostLocationSearchScreen> createState() =>
      _AddPostLocationSearchScreenState();
}

class _AddPostLocationSearchScreenState
    extends State<AddPostLocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<CountryEntity> _countries = [];
  bool _loadingCountries = true;
  String? _countriesError;

  /// When set, the list shows cities for this country.
  CountryEntity? _selectedCountry;
  List<CityEntity> _cities = [];
  bool _loadingCities = false;
  String? _citiesError;

  /// Cache so typing can surface cities from matched countries.
  final Map<String, List<CityEntity>> _citiesCache = {};
  final Set<String> _citiesLoadingCodes = {};

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_loadCountries());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {});
      if (_selectedCountry == null) {
        unawaited(_prefetchCitiesForQuery());
      }
    });
  }

  Future<void> _loadCountries() async {
    setState(() {
      _loadingCountries = true;
      _countriesError = null;
    });

    final result = await countries_di.sl<GetCountriesUseCase>()(NoParams());
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loadingCountries = false;
        _countriesError = failure.message;
      }),
      (countries) {
        setState(() {
          _countries = countries;
          _loadingCountries = false;
        });
        final initial = widget.initial;
        if (initial != null) {
          unawaited(_openCountry(initial.country, keepInitialCity: true));
        }
      },
    );
  }

  Future<void> _openCountry(
    CountryEntity country, {
    bool keepInitialCity = false,
  }) async {
    setState(() {
      _selectedCountry = country;
      _cities = _citiesCache[country.code] ?? const [];
      _loadingCities = !_citiesCache.containsKey(country.code);
      _citiesError = null;
      if (!keepInitialCity) {
        _searchController.clear();
      }
    });
    _searchFocusNode.requestFocus();

    if (_citiesCache.containsKey(country.code)) {
      setState(() {
        _cities = _citiesCache[country.code]!;
        _loadingCities = false;
      });
      return;
    }

    final result = await countries_di.sl<GetCountryCitiesUseCase>()(
      GetCountryCitiesParams(code: country.code),
    );
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loadingCities = false;
        _citiesError = failure.message;
      }),
      (page) {
        _citiesCache[country.code] = page.cities;
        setState(() {
          _cities = page.cities;
          _loadingCities = false;
        });
      },
    );
  }

  Future<void> _prefetchCitiesForQuery() async {
    final query = _searchController.text.trim().toLowerCase();
    if (query.length < 2) return;

    final matched = _countries
        .where((c) => _countryMatches(c, query))
        .take(3)
        .toList();

    for (final country in matched) {
      await _ensureCitiesCached(country.code);
    }
    if (mounted) setState(() {});
  }

  Future<void> _ensureCitiesCached(String code) async {
    if (_citiesCache.containsKey(code) || _citiesLoadingCodes.contains(code)) {
      return;
    }
    _citiesLoadingCodes.add(code);
    final result = await countries_di.sl<GetCountryCitiesUseCase>()(
      GetCountryCitiesParams(code: code),
    );
    result.fold((_) {}, (page) => _citiesCache[code] = page.cities);
    _citiesLoadingCodes.remove(code);
  }

  bool _countryMatches(CountryEntity country, String query) {
    if (query.isEmpty) return true;
    return country.name.toLowerCase().contains(query) ||
        country.code.toLowerCase().contains(query) ||
        (country.capital?.toLowerCase().contains(query) ?? false);
  }

  bool _cityMatches(CityEntity city, String query) {
    if (query.isEmpty) return true;
    return city.name.toLowerCase().contains(query) ||
        (city.stateCode?.toLowerCase().contains(query) ?? false);
  }

  List<CountryEntity> get _filteredCountries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _countries;
    return _countries.where((c) => _countryMatches(c, query)).toList();
  }

  List<CityEntity> get _filteredCities {
    final query = _searchController.text.trim().toLowerCase();
    return _cities.where((c) => _cityMatches(c, query)).toList();
  }

  List<_CityHit> get _crossCountryCityHits {
    final query = _searchController.text.trim().toLowerCase();
    if (query.length < 2 || _selectedCountry != null) return const [];

    final hits = <_CityHit>[];
    for (final country in _filteredCountries.take(5)) {
      final cities = _citiesCache[country.code];
      if (cities == null) continue;
      for (final city in cities) {
        if (_cityMatches(city, query)) {
          hits.add(_CityHit(country: country, city: city));
          if (hits.length >= 40) return hits;
        }
      }
    }
    return hits;
  }

  void _onBack() {
    if (_selectedCountry != null) {
      setState(() {
        _selectedCountry = null;
        _cities = [];
        _citiesError = null;
        _loadingCities = false;
        _searchController.clear();
      });
      _searchFocusNode.requestFocus();
      return;
    }
    Navigator.of(context).pop();
  }

  void _selectCity(CountryEntity country, CityEntity city) {
    Navigator.of(
      context,
    ).pop(AddPostLocationSelection(country: country, city: city));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.45);
    final fieldFill = theme.brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF1F1F2);
    final inCityMode = _selectedCountry != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _onBack,
                    icon: const DirectionalBackIcon(),
                  ),
                  Expanded(
                    child: Text(
                      inCityMode
                          ? (_selectedCountry!.emoji != null &&
                                    _selectedCountry!.emoji!.isNotEmpty
                                ? '${_selectedCountry!.emoji} ${_selectedCountry!.name}'
                                : _selectedCountry!.name)
                          : l10n.addLocationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: fieldFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(LucideIcons.search, size: 18, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(fontSize: 15, color: onSurface),
                        decoration: InputDecoration(
                          isDense: true,
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: inCityMode
                              ? l10n.selectCityHint
                              : l10n.locationSearchHint,
                          hintStyle: TextStyle(fontSize: 15, color: muted),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          child: Icon(LucideIcons.x, size: 18, color: muted),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildBody(l10n, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_selectedCountry != null) {
      return _buildCitiesBody(l10n, theme);
    }
    return _buildCountriesBody(l10n, theme);
  }

  Widget _buildCountriesBody(AppLocalizations l10n, ThemeData theme) {
    if (_loadingCountries) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_countriesError != null) {
      return _ErrorState(
        message: _countriesError!,
        retryLabel: l10n.retry,
        onRetry: _loadCountries,
      );
    }

    final countries = _filteredCountries;
    final cityHits = _crossCountryCityHits;
    final query = _searchController.text.trim();

    if (countries.isEmpty && cityHits.isEmpty) {
      return Center(
        child: Text(
          l10n.messagesNoResults,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.p24),
      children: [
        if (cityHits.isNotEmpty) ...[
          _SectionHeader(label: l10n.selectCity),
          for (final hit in cityHits)
            _LocationTile(
              title: hit.city.name,
              subtitle: hit.country.name,
              leading: Icon(
                LucideIcons.mapPin,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              onTap: () => _selectCity(hit.country, hit.city),
            ),
          if (countries.isNotEmpty) _SectionHeader(label: l10n.selectCountry),
        ],
        for (final country in countries)
          _LocationTile(
            title: country.name,
            subtitle: [
              if (country.capital != null && country.capital!.isNotEmpty)
                country.capital!,
              country.code,
            ].join(' · '),
            leading: country.emoji != null && country.emoji!.isNotEmpty
                ? Text(country.emoji!, style: const TextStyle(fontSize: 22))
                : Icon(
                    LucideIcons.globe,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
            trailing: const DirectionalChevronIcon(size: 18),
            onTap: () => unawaited(_openCountry(country)),
          ),
        if (query.length >= 2 &&
            countries.isNotEmpty &&
            _citiesLoadingCodes.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCitiesBody(AppLocalizations l10n, ThemeData theme) {
    if (_loadingCities) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_citiesError != null) {
      return _ErrorState(
        message: _citiesError!,
        retryLabel: l10n.retry,
        onRetry: () {
          final country = _selectedCountry;
          if (country != null) unawaited(_openCountry(country));
        },
      );
    }

    final cities = _filteredCities;
    if (cities.isEmpty) {
      return Center(
        child: Text(
          l10n.messagesNoResults,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    final initialCityId = widget.initial?.city.id;
    final country = _selectedCountry!;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSizes.p24),
      itemCount: cities.length,
      itemBuilder: (context, index) {
        final city = cities[index];
        final selected =
            initialCityId == city.id &&
            widget.initial?.country.code == country.code;
        return _LocationTile(
          title: city.name,
          subtitle: city.stateCode,
          leading: Icon(
            LucideIcons.mapPin,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          trailing: selected
              ? Icon(
                  LucideIcons.check,
                  size: 18,
                  color: theme.colorScheme.primary,
                )
              : null,
          onTap: () => _selectCity(country, city),
        );
      },
    );
  }
}

class _CityHit {
  const _CityHit({required this.country, required this.city});

  final CountryEntity country;
  final CityEntity city;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(width: 28, child: Center(child: leading)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
