import 'package:bimobondapp/app/auth/presentation/widgets/personal_info/personal_info_edit_field.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/personal_info/personal_info_selection_field.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/personal_info/personal_info_utils.dart';
import 'package:bimobondapp/core/widgets/phone_text_field.dart';
import 'package:bimobondapp/core/widgets/profile_bio_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class PersonalInfoFormSection extends StatelessWidget {
  const PersonalInfoFormSection({
    required this.l10n,
    required this.fullNameController,
    required this.usernameController,
    required this.bioController,
    required this.phoneController,
    required this.instagramController,
    required this.youtubeController,
    required this.selectedCountryCode,
    required this.selectedGender,
    required this.selectedCountry,
    required this.onCountryCodeChanged,
    required this.onGenderTap,
    required this.onCountryTap,
    super.key,
  });

  final AppLocalizations l10n;
  final TextEditingController fullNameController;
  final TextEditingController usernameController;
  final TextEditingController bioController;
  final TextEditingController phoneController;
  final TextEditingController instagramController;
  final TextEditingController youtubeController;
  final String selectedCountryCode;
  final String? selectedGender;
  final String? selectedCountry;
  final ValueChanged<String> onCountryCodeChanged;
  final VoidCallback onGenderTap;
  final VoidCallback onCountryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PersonalInfoEditField(
          label: l10n.fullNameLabel,
          controller: fullNameController,
          hint: l10n.enterYourName,
          l10n: l10n,
          maxLength: ProfileFullName.maxLength,
        ),
        PersonalInfoEditField(
          label: l10n.usernameLabel,
          controller: usernameController,
          hint: l10n.enterUsername,
          l10n: l10n,
          prefix: '@',
        ),
        PersonalInfoEditField(
          label: l10n.bioLabel,
          controller: bioController,
          hint: l10n.addBioToProfile,
          l10n: l10n,
          minLines: 1,
          maxLines: 2,
          maxLength: ProfileBioText.maxLength,
          isRequired: false,
        ),
        PersonalInfoSelectionField(
          label: l10n.genderLabel,
          value: selectedGender == 'male'
              ? l10n.male
              : selectedGender == 'female'
              ? l10n.female
              : null,
          hint: l10n.selectGender,
          onTap: onGenderTap,
        ),
        PersonalInfoSelectionField(
          label: l10n.countryLabel,
          value: localizedPersonalInfoCountry(selectedCountry, l10n),
          hint: l10n.selectCountry,
          onTap: onCountryTap,
        ),
        PhoneTextField(
          controller: phoneController,
          initialCountryCode: selectedCountryCode,
          labelText: l10n.phoneLabel,
          isProfileStyle: true,
          onCountryCodeChanged: onCountryCodeChanged,
        ),
        PersonalInfoEditField(
          label: l10n.instagramLabel,
          controller: instagramController,
          hint: l10n.instagramProfileUrl,
          l10n: l10n,
          isRequired: false,
        ),
        PersonalInfoEditField(
          label: l10n.youtubeLabel,
          controller: youtubeController,
          hint: l10n.youtubeChannelUrl,
          l10n: l10n,
          isRequired: false,
        ),
      ],
    );
  }
}
