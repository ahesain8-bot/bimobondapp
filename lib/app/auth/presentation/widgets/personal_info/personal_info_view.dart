import 'package:bimobondapp/app/auth/presentation/widgets/personal_info/personal_info_avatar_section.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/personal_info/personal_info_form_section.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class PersonalInfoView extends StatelessWidget {
  const PersonalInfoView({
    required this.formKey,
    required this.l10n,
    required this.avatarUrl,
    required this.fallbackName,
    required this.isUpdating,
    required this.fullNameController,
    required this.usernameController,
    required this.bioController,
    required this.phoneController,
    required this.instagramController,
    required this.youtubeController,
    required this.selectedCountryCode,
    required this.selectedGender,
    required this.selectedCountry,
    required this.onSavePressed,
    required this.onChangePhotoTap,
    required this.onCountryCodeChanged,
    required this.onGenderTap,
    required this.onCountryTap,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final AppLocalizations l10n;
  final String? avatarUrl;
  final String fallbackName;
  final bool isUpdating;
  final TextEditingController fullNameController;
  final TextEditingController usernameController;
  final TextEditingController bioController;
  final TextEditingController phoneController;
  final TextEditingController instagramController;
  final TextEditingController youtubeController;
  final String selectedCountryCode;
  final String? selectedGender;
  final String? selectedCountry;
  final VoidCallback onSavePressed;
  final VoidCallback onChangePhotoTap;
  final ValueChanged<String> onCountryCodeChanged;
  final VoidCallback onGenderTap;
  final VoidCallback onCountryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: l10n.editProfile,
        actions: [
          TextButton(
            onPressed: isUpdating ? null : onSavePressed,
            child: isUpdating
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CustomLoadingWidget(size: 28),
                  )
                : CustomText(
                    l10n.continueAction,
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppSizes.p24),
            PersonalInfoAvatarSection(
              l10n: l10n,
              avatarUrl: avatarUrl,
              fallbackName: fallbackName,
              onChangePhotoTap: onChangePhotoTap,
            ),
            const SizedBox(height: AppSizes.p32),
            Form(
              key: formKey,
              child: PersonalInfoFormSection(
                l10n: l10n,
                fullNameController: fullNameController,
                usernameController: usernameController,
                bioController: bioController,
                phoneController: phoneController,
                instagramController: instagramController,
                youtubeController: youtubeController,
                selectedCountryCode: selectedCountryCode,
                selectedGender: selectedGender,
                selectedCountry: selectedCountry,
                onCountryCodeChanged: onCountryCodeChanged,
                onGenderTap: onGenderTap,
                onCountryTap: onCountryTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
