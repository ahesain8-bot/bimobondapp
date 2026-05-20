import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/phone_text_field.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

class PersonalInfoScreen extends StatefulWidget {
  final UserEntity? user;

  const PersonalInfoScreen({super.key, this.user});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  late TextEditingController _instagramController;
  late TextEditingController _youtubeController;
  String _selectedCountryCode = '+20';
  String? _selectedGender;
  String? _selectedCountry;
  bool _isUpdating = false;

  void _setPhoneData(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _phoneController.text = '';
      return;
    }

    final countryCodes = ['+20', '+966', '+971', '+1', '+44', '+965', '+974'];
    bool found = false;
    for (final code in countryCodes) {
      if (phoneNumber.startsWith(code)) {
        _selectedCountryCode = code;
        _phoneController.text = phoneNumber.substring(code.length);
        found = true;
        break;
      }
    }

    if (!found) {
      _phoneController.text = phoneNumber;
    }
  }

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _phoneController = TextEditingController();
    _instagramController = TextEditingController();
    _youtubeController = TextEditingController();

    final authState = context.read<AuthBloc>().state;
    if (widget.user != null) {
      _fullNameController.text = widget.user!.fullName ?? '';
      _usernameController.text = widget.user!.username ?? '';
      _bioController.text = widget.user!.bio ?? '';
      _setPhoneData(widget.user!.phoneNumber);
      _instagramController.text = widget.user!.instagramUrl ?? '';
      _youtubeController.text = widget.user!.youtubeUrl ?? '';
      _selectedGender = widget.user!.gender;
      _selectedCountry = widget.user!.country;
    } else if (authState is AuthSuccess) {
      _fullNameController.text = authState.user.fullName ?? '';
      _usernameController.text = authState.user.username ?? '';
      _bioController.text = authState.user.bio ?? '';
      _setPhoneData(authState.user.phoneNumber);
      _instagramController.text = authState.user.instagramUrl ?? '';
      _youtubeController.text = authState.user.youtubeUrl ?? '';
      _selectedGender = authState.user.gender;
      _selectedCountry = authState.user.country;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      _isUpdating = true;

      final phoneInput = _phoneController.text.trim();
      final fullPhoneNumber = phoneInput.isNotEmpty
          ? '$_selectedCountryCode$phoneInput'
          : null;

      final data = <String, dynamic>{
        'fullName': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'gender': _selectedGender,
        'country': _selectedCountry,
        'phoneNumber': fullPhoneNumber,
        'instagramUrl': _instagramController.text.trim().isEmpty
            ? null
            : _instagramController.text.trim(),
        'youtubeUrl': _youtubeController.text.trim().isEmpty
            ? null
            : _youtubeController.text.trim(),
      };

      // Remove null values so we don't accidentally overwrite with nulls if not needed
      data.removeWhere((key, value) => value == null);

      context.read<AuthBloc>().add(UpdateProfileRequestedEvent(data));
    }
  }

  String _getLocalizedMessage(AppLocalizations l10n, String key) {
    switch (key) {
      case 'loginFailed':
        return l10n.loginFailed;
      case 'verificationFailed':
        return l10n.verificationFailed;
      case 'invalidOtpCode':
        return l10n.invalidOtpCode;
      case 'facebookLoginFailed':
        return l10n.facebookLoginFailed;
      case 'googleLoginFailed':
        return l10n.googleLoginFailed;
      case 'updateProfileFailed':
        return l10n.updateProfileFailed;
      case 'signupFailed':
        return l10n.signupFailed;
      default:
        return key; // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      appBar: CustomAppBar(
        title: l10n.editProfile,
        actions: [
          TextButton(
            onPressed: _isUpdating ? null : _saveProfile,
            child: CustomText(
              l10n.continueAction,
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            _isUpdating = false;
            PopupDialogs.showSuccessDialog(
              context,
              l10n.profileUpdatedSuccessfully,
            );
            context.pop();
          } else if (state is AuthFailure) {
            _isUpdating = false;
            String message = state.messageKey != null
                ? _getLocalizedMessage(l10n, state.messageKey!)
                : state.message;
            PopupDialogs.showErrorDialog(context, message);
          }
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: AppSizes.p24),
              // Profile Photo Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage:
                              widget.user?.avatarUrl != null &&
                                  widget.user!.avatarUrl!.isNotEmpty &&
                                  MediaUtils.isImage(widget.user!.avatarUrl!)
                              ? NetworkImage(widget.user!.avatarUrl!)
                              : null,
                          child:
                              widget.user?.avatarUrl == null ||
                                  widget.user!.avatarUrl!.isEmpty ||
                                  !MediaUtils.isImage(widget.user!.avatarUrl!)
                              ? Icon(
                                  LucideIcons.camera,
                                  size: 32,
                                  color: Colors.grey.shade600,
                                )
                              : null,
                        ),
                        if (widget.user?.avatarUrl != null)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.camera,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.p12),
                    GestureDetector(
                      onTap: () => context.pushNamed('change_avatar'),
                      child: CustomText(
                        l10n.changePhoto,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.p32),

              // Form Section
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildEditItem(
                      label: l10n.fullNameLabel,
                      controller: _fullNameController,
                      hint: l10n.enterYourName,
                    ),
                    _buildEditItem(
                      label: l10n.usernameLabel,
                      controller: _usernameController,
                      hint: l10n.enterUsername,
                      prefix: '@',
                    ),
                    _buildEditItem(
                      label: l10n.bioLabel,
                      controller: _bioController,
                      hint: l10n.addBioToProfile,
                      maxLines: 3,
                      isRequired: false,
                    ),
                    _buildSelectionItem(
                      label: l10n.genderLabel,
                      value: _selectedGender == 'male'
                          ? l10n.male
                          : _selectedGender == 'female'
                          ? l10n.female
                          : null,
                      hint: l10n.selectGender,
                      onTap: () => _showGenderPicker(context, l10n),
                    ),
                    _buildSelectionItem(
                      label: l10n.countryLabel,
                      value: _getLocalizedCountry(_selectedCountry, l10n),
                      hint: l10n.selectCountry,
                      onTap: () => _showCountryPicker(context, l10n),
                    ),
                    PhoneTextField(
                      controller: _phoneController,
                      initialCountryCode: _selectedCountryCode,
                      labelText: l10n.phoneLabel,
                      isProfileStyle: true,
                      onCountryCodeChanged: (code) {
                        setState(() {
                          _selectedCountryCode = code;
                        });
                      },
                    ),
                    _buildEditItem(
                      label: l10n.instagramLabel,
                      controller: _instagramController,
                      hint: l10n.instagramProfileUrl,
                      isRequired: false,
                    ),
                    _buildEditItem(
                      label: l10n.youtubeLabel,
                      controller: _youtubeController,
                      hint: l10n.youtubeChannelUrl,
                      isRequired: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _getLocalizedCountry(String? code, AppLocalizations l10n) {
    switch (code) {
      case 'Egypt':
        return l10n.egypt;
      case 'Saudi Arabia':
        return l10n.saudiArabia;
      case 'UAE':
        return l10n.uae;
      case 'USA':
        return l10n.usa;
      case 'UK':
        return l10n.uk;
      default:
        return code;
    }
  }

  Widget _buildSelectionItem({
    required String label,
    required String? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p12,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: CustomText(
                label,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: CustomText(
                value ?? hint,
                fontSize: 15,
                color: value == null
                    ? theme.disabledColor.withOpacity(0.5)
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
            Icon(
              isRTL ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
              size: 16,
              color: theme.disabledColor.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenderPicker(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: CustomText(l10n.male),
            onTap: () {
              setState(() => _selectedGender = 'male');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: CustomText(l10n.female),
            onTap: () {
              setState(() => _selectedGender = 'female');
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: AppSizes.p16),
        ],
      ),
    );
  }

  void _showCountryPicker(BuildContext context, AppLocalizations l10n) {
    final countries = [
      {'code': 'Egypt', 'name': l10n.egypt},
      {'code': 'Saudi Arabia', 'name': l10n.saudiArabia},
      {'code': 'UAE', 'name': l10n.uae},
      {'code': 'USA', 'name': l10n.usa},
      {'code': 'UK', 'name': l10n.uk},
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        height: 400,
        padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
        child: Column(
          children: [
            CustomText(
              l10n.selectCountry,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: countries.length,
                itemBuilder: (context, index) => ListTile(
                  title: CustomText(countries[index]['name'] as String),
                  onTap: () {
                    setState(
                      () =>
                          _selectedCountry = countries[index]['code'] as String,
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditItem({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? prefix,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: CustomText(label, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                prefixText: prefix,
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  color: theme.disabledColor.withOpacity(0.5),
                  fontSize: 15,
                ),
              ),
              validator: (value) {
                if (isRequired && (value == null || value.isEmpty)) {
                  return l10n.fieldIsRequired(label);
                }
                return null;
              },
            ),
          ),
          Icon(
            isRTL ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
            size: 16,
            color: theme.disabledColor.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}
