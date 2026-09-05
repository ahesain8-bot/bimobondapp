import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:bimobondapp/app/promotions/presentation/widgets/promotion_ui.dart';
import 'package:bimobondapp/app/promotions/presentation/widgets/promote_radius_map.dart';
import '../../domain/live_promotion_models.dart';
import '../controllers/live_promotions_controller.dart';

class LivePromotionForm extends StatefulWidget {
  const LivePromotionForm({
    super.key,
    required this.controller,
    required this.state,
    required this.liveId,
    this.initial,
    this.editing = false,
    this.onSaved,
  });
  final LivePromotionsController controller;
  final LivePromotionsState state;
  final String liveId;
  final LivePromotionDraft? initial;
  final bool editing;
  final VoidCallback? onSaved;
  @override
  State<LivePromotionForm> createState() => _LivePromotionFormState();
}

class _LivePromotionFormState extends State<LivePromotionForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _budget, _min, _max, _lat, _lng, _radius;
  late LivePromotionObjective _objective;
  late bool _automatic, _packageMode;
  bool _showMap = false;
  String? _packageId;
  late int _duration;
  late Set<String> _genders, _countries, _languages, _categories;
  @override
  void initState() {
    super.initState();
    final d =
        widget.initial ??
        const LivePromotionDraft(budgetCoins: 5, durationDays: 1);
    _objective = d.objective;
    _automatic = d.automaticAudience;
    _packageMode = d.packageId != null;
    _packageId = d.packageId;
    _duration = d.durationDays ?? 1;
    _budget = TextEditingController(text: d.budgetCoins?.toString() ?? '5');
    _min = TextEditingController(text: d.targetAgeMin?.toString() ?? '');
    _max = TextEditingController(text: d.targetAgeMax?.toString() ?? '');
    _lat = TextEditingController(text: d.targetLatitude?.toString() ?? '');
    _lng = TextEditingController(text: d.targetLongitude?.toString() ?? '');
    _radius = TextEditingController(text: d.targetRadiusKm?.toString() ?? '');
    _genders = d.targetGenders.toSet();
    _countries = d.targetCountryCodes.toSet();
    _languages = d.targetLanguages.toSet();
    _categories = d.targetCategoryIds.toSet();
  }

  @override
  void dispose() {
    for (final c in [_budget, _min, _max, _lat, _lng, _radius]) {
      c.dispose();
    }
    super.dispose();
  }

  // Accept Arabic/Persian digits while sending locale-independent JSON numbers.
  String _digits(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩', fa = '۰۱۲۳۴۵۶۷۸۹';
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(ar[i], '$i').replaceAll(fa[i], '$i');
    }
    return s.replaceAll('٫', '.').trim();
  }

  int? _int(TextEditingController c) => int.tryParse(_digits(c.text));
  double? _double(TextEditingController c) => double.tryParse(_digits(c.text));
  LivePromotionDraft get _draft => LivePromotionDraft(
    objective: _objective,
    automaticAudience: _automatic,
    packageId: _packageMode ? _packageId : null,
    budgetCoins: _packageMode ? null : _int(_budget),
    durationDays: _packageMode ? null : _duration,
    targetGenders: _genders.toList(),
    targetAgeMin: _int(_min),
    targetAgeMax: _int(_max),
    targetCountryCodes: _countries.toList(),
    targetLanguages: _languages.toList(),
    targetCategoryIds: _categories.toList(),
    targetLatitude: _double(_lat),
    targetLongitude: _double(_lng),
    targetRadiusKm: _double(_radius),
  );
  void _changed() {
    setState(() {});
    widget.controller.schedulePreview(_draft);
  }

  void _automaticChanged(bool value) {
    _automatic = value;
    if (value) {
      _genders.clear();
      _countries.clear();
      _languages.clear();
      _categories.clear();
      for (final c in [_min, _max, _lat, _lng, _radius]) {
        c.clear();
      }
      _showMap = false;
    }
    _changed();
  }

  Widget _section(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: PromotionUi.sectionDecoration(context),
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget _number(
    String label,
    TextEditingController c, {
    bool integer = false,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(
        decimal: !integer,
        signed: !integer,
      ),
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => _changed(),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return required ? AppLocalizations.of(context)!.lpInteger : null;
        }
        if (integer) {
          return _int(c) == null
              ? AppLocalizations.of(context)!.lpInteger
              : null;
        }
        final n = _double(c);
        return n == null || !n.isFinite
            ? AppLocalizations.of(context)!.lpNumber
            : null;
      },
    ),
  );
  Widget _choices(
    String title,
    List<LivePromotionOption> options,
    Set<String> selected,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title),
      Wrap(
        spacing: 8,
        children: [
          for (final o in options)
            FilterChip(
              label: Text(o.label),
              selected: selected.contains(o.value),
              onSelected: (v) {
                v ? selected.add(o.value) : selected.remove(o.value);
                _changed();
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = widget.state;
    final n = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    final options = s.options;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section(l.lpObjective, [
            Wrap(
              spacing: 8,
              children: [
                for (final o in LivePromotionObjective.values)
                  ChoiceChip(
                    label: Text(
                      o == LivePromotionObjective.views
                          ? l.lpViews
                          : l.lpFollowers,
                    ),
                    selected: _objective == o,
                    onSelected: (_) {
                      _objective = o;
                      _changed();
                    },
                  ),
              ],
            ),
          ]),
          _section(l.lpAudience, [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l.lpAutomatic),
              subtitle: Text(l.lpAutomaticHint),
              value: _automatic,
              onChanged: _automaticChanged,
            ),
            if (!_automatic) ...[
              if (options == null)
                Text(l.lpOptionsUnavailable)
              else ...[
                _choices(l.lpGenders, options.genders, _genders),
                _choices(l.lpCountries, options.countries, _countries),
                _choices(l.lpLanguages, options.languages, _languages),
                _choices(l.lpCategories, options.categories, _categories),
              ],
              const SizedBox(height: 12),
              _number(l.lpAgeMin, _min, integer: true),
              _number(l.lpAgeMax, _max, integer: true),
              Text(l.lpGeo),
              const SizedBox(height: 12),
              _number(l.lpLatitude, _lat),
              _number(l.lpLongitude, _lng),
              _number(l.lpRadius, _radius),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _showMap = !_showMap),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(l.lpPickMap),
                  ),
                  TextButton(
                    onPressed: () {
                      _lat.clear();
                      _lng.clear();
                      _radius.clear();
                      _changed();
                    },
                    child: Text(l.lpClearGeo),
                  ),
                ],
              ),
              if (_showMap)
                SizedBox(
                  height: 230,
                  child: PromoteRadiusMapPreview(
                    radiusKm: (_double(_radius) ?? 1).clamp(1, 10000).round(),
                    latitude: _double(_lat),
                    longitude: _double(_lng),
                    detectLocation: false,
                    onCenterChanged: (point) {
                      _lat.text = '${point.latitude}';
                      _lng.text = '${point.longitude}';
                      _changed();
                    },
                  ),
                ),
            ],
          ]),
          _section(l.lpBudget, [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l.lpCustomBudget),
                  selected: !_packageMode,
                  onSelected: (_) {
                    _packageMode = false;
                    _packageId = null;
                    _changed();
                  },
                ),
                ChoiceChip(
                  label: Text(l.lpPackage),
                  selected: _packageMode,
                  onSelected: (_) {
                    _packageMode = true;
                    _changed();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_packageMode) ...[
              if (s.packages.isEmpty) Text(l.lpPackagesUnavailable),
              for (final p in s.packages)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name),
                  subtitle: Text(
                    '${p.budgetCoins == null ? l.lpUnknown : n.format(p.budgetCoins)} ${l.lpCoins} · ${p.durationDays == null ? l.lpUnknown : n.format(p.durationDays)} ${l.lpDuration}',
                  ),
                  leading: Icon(
                    _packageId == p.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onTap: () {
                    _packageId = p.id;
                    _changed();
                  },
                ),
            ] else ...[
              _number(l.lpCoins, _budget, integer: true, required: true),
              Text(l.lpDuration),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in [1, 3, 7, 14])
                    ChoiceChip(
                      label: Text(n.format(d)),
                      selected: _duration == d,
                      onSelected: (_) {
                        _duration = d;
                        _changed();
                      },
                    ),
                ],
              ),
            ],
          ]),
          _section(l.lpEstimates, [
            if (s.previewLoading) const LinearProgressIndicator(),
            if (s.preview == null) Text(l.lpNoEstimates),
            if (s.preview?.estimatedViewers != null)
              Text('${l.lpViews}: ${n.format(s.preview!.estimatedViewers)}'),
            if (s.preview?.estimatedFollowers != null)
              Text(
                '${l.lpFollowers}: ${n.format(s.preview!.estimatedFollowers)}',
              ),
            if (s.preview?.estimatedImpressions != null)
              Text(
                '${l.lpImpressions}: ${n.format(s.preview!.estimatedImpressions)}',
              ),
            Text(l.lpEstimateHint),
            TextButton(
              onPressed: () => widget.controller.schedulePreview(_draft),
              child: Text(l.lpRetry),
            ),
          ]),
          Text(l.lpCreateHint),
          const SizedBox(height: 12),
          if (!widget.controller.responseContractVerified)
            Text(l.lpUnavailable),
          if (s.eligibility?.canCreate != true && !widget.editing)
            Text(l.lpEligibility),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                s.mutating ||
                    s.loading ||
                    !widget.controller.responseContractVerified ||
                    (!widget.editing && s.eligibility?.canCreate != true)
                ? null
                : () async {
                    if (!_form.currentState!.validate()) return;
                    if (_draft.validate().isNotEmpty) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l.lpValidation)));
                      return;
                    }
                    if (widget.editing) {
                      await widget.controller.edit(_draft);
                      if (mounted && widget.controller.state.error == null) {
                        widget.onSaved?.call();
                      }
                    } else {
                      await widget.controller.create(widget.liveId, _draft);
                    }
                  },
            icon: const Icon(Icons.campaign_outlined),
            label: Text(widget.editing ? l.lpSave : l.lpCreate),
          ),
        ],
      ),
    );
  }
}
