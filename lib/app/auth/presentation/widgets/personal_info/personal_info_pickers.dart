import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class PersonalInfoPickers {
  PersonalInfoPickers._();

  static void showGenderPicker(
    BuildContext context, {
    required AppLocalizations l10n,
    required String? selectedGender,
    required ValueChanged<String> onSelected,
  }) {
    GlassBottomSheet.showActions<void>(
      context,
      title: l10n.selectGender,
      children: [
        GlassBottomSheetListTile(
          label: l10n.male,
          isSelected: selectedGender == 'male',
          onTap: () {
            onSelected('male');
            Navigator.pop(context);
          },
        ),
        GlassBottomSheetListTile(
          label: l10n.female,
          isSelected: selectedGender == 'female',
          onTap: () {
            onSelected('female');
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  static void showCountryPicker(
    BuildContext context, {
    required AppLocalizations l10n,
    required String? selectedCountry,
    required ValueChanged<String> onSelected,
  }) {
    final countries = [
      {'code': 'Egypt', 'name': l10n.egypt},
      {'code': 'Saudi Arabia', 'name': l10n.saudiArabia},
      {'code': 'UAE', 'name': l10n.uae},
      {'code': 'USA', 'name': l10n.usa},
      {'code': 'UK', 'name': l10n.uk},
    ];

    GlassBottomSheet.showActions<void>(
      context,
      title: l10n.selectCountry,
      scrollable: true,
      children: [
        for (final country in countries)
          GlassBottomSheetListTile(
            label: country['name']!,
            isSelected: selectedCountry == country['code'],
            onTap: () {
              onSelected(country['code'] as String);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}
