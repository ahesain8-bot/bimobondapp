import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/utils/auth_message_localizer.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/personal_info/personal_info_pickers.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/personal_info/personal_info_utils.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/personal_info/personal_info_view.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/profile_bio_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PersonalInfoScreen extends StatefulWidget {
  final UserEntity? user;
  final bool isOnboarding;

  const PersonalInfoScreen({
    super.key,
    this.user,
    this.isOnboarding = false,
  });

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
    var found = false;
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
      _fullNameController.text =
          ProfileFullName.clamp(widget.user!.fullName ?? '');
      _usernameController.text = widget.user!.username ?? '';
      _bioController.text = widget.user!.bio ?? '';
      _setPhoneData(widget.user!.phoneNumber);
      _instagramController.text = widget.user!.instagramUrl ?? '';
      _youtubeController.text = widget.user!.youtubeUrl ?? '';
      _selectedGender = widget.user!.gender;
      _selectedCountry = widget.user!.country;
    } else if (authState is AuthSuccess) {
      _fullNameController.text =
          ProfileFullName.clamp(authState.user.fullName ?? '');
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
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isUpdating = true);

    final phoneInput = _phoneController.text.trim();
    final fullPhoneNumber = phoneInput.isNotEmpty
        ? '$_selectedCountryCode$phoneInput'
        : null;

    final bioText = _bioController.text.trim();
    final cappedBio = bioText.length > ProfileBioText.maxLength
        ? bioText.substring(0, ProfileBioText.maxLength)
        : bioText;

    final data = <String, dynamic>{
      'fullName': ProfileFullName.clamp(_fullNameController.text),
      'username': _usernameController.text.trim(),
      'bio': cappedBio,
      'gender': _selectedGender,
      'country': _selectedCountry,
      'phoneNumber': fullPhoneNumber,
      // Accept username or full link — no client URL-format validation.
      'instagramUrl': _normalizeSocialLink(
        _instagramController.text,
        fallbackHost: 'instagram.com',
      ),
      'youtubeUrl': _normalizeSocialLink(
        _youtubeController.text,
        fallbackHost: 'youtube.com',
        youtubeStyle: true,
      ),
    };

    data.removeWhere((key, value) => value == null);

    context.read<AuthBloc>().add(UpdateProfileRequestedEvent(data));
  }

  /// Allows free text on Instagram/YouTube fields.
  /// If the user already pasted a link, keep it; otherwise build a safe URL
  /// so backend URL validators don't reject plain usernames.
  String? _normalizeSocialLink(
    String raw, {
    required String fallbackHost,
    bool youtubeStyle = false,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return trimmed;
    }

    var handle = trimmed;
    if (handle.startsWith('@')) {
      handle = handle.substring(1).trim();
    }
    if (handle.isEmpty) return null;

    // Already a domain path without scheme.
    if (handle.contains(fallbackHost) || handle.contains('/')) {
      return 'https://${handle.replaceFirst(RegExp(r'^/+'), '')}';
    }

    if (youtubeStyle) {
      return 'https://$fallbackHost/@$handle';
    }
    return 'https://$fallbackHost/$handle';
  }

  void _showGenderPicker(AppLocalizations l10n) {
    PersonalInfoPickers.showGenderPicker(
      context,
      l10n: l10n,
      selectedGender: _selectedGender,
      onSelected: (gender) => setState(() => _selectedGender = gender),
    );
  }

  void _showCountryPicker(AppLocalizations l10n) {
    PersonalInfoPickers.showCountryPicker(
      context,
      l10n: l10n,
      selectedCountry: _selectedCountry,
      onSelected: (country) {
        setState(() {
          _selectedCountry = country;
          final dial = dialCodeForPersonalInfoCountry(country);
          if (dial != null) {
            _selectedCountryCode = dial;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthSuccess || current is AuthFailure,
      listener: (context, state) {
        if (!_isUpdating) return;

        if (state is AuthSuccess) {
          setState(() => _isUpdating = false);
          PopupDialogs.showSuccessDialog(
            context,
            l10n.profileUpdatedSuccessfully,
          );
          if (widget.isOnboarding) {
            // Signup onboarding: profile first, then mandatory interests (min 3).
            context.goNamed('interest_selection');
            return;
          }
          if (context.canPop()) {
            context.pop();
          }
        } else if (state is AuthFailure) {
          setState(() => _isUpdating = false);
          final message = state.messageKey != null
              ? localizeAuthMessage(l10n, state.messageKey!)
              : state.message;
          PopupDialogs.showErrorDialog(context, message);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final avatarUrl = resolvePersonalInfoAvatarUrl(
            state: state,
            user: widget.user,
          );
          final fallbackName = _fullNameController.text.trim().isNotEmpty
              ? _fullNameController.text.trim()
              : _usernameController.text.trim();

          return PersonalInfoView(
            formKey: _formKey,
            l10n: l10n,
            avatarUrl: avatarUrl,
            fallbackName: fallbackName,
            isUpdating: _isUpdating || state is AuthLoading,
            fullNameController: _fullNameController,
            usernameController: _usernameController,
            bioController: _bioController,
            phoneController: _phoneController,
            instagramController: _instagramController,
            youtubeController: _youtubeController,
            selectedCountryCode: _selectedCountryCode,
            selectedGender: _selectedGender,
            selectedCountry: _selectedCountry,
            onSavePressed: _saveProfile,
            onChangePhotoTap: () => context.pushNamed('change_avatar'),
            onCountryCodeChanged: (code) {
              setState(() {
                _selectedCountryCode = code;
                final country = personalInfoCountryForDialCode(code);
                if (country != null) {
                  _selectedCountry = country;
                }
              });
            },
            onGenderTap: () => _showGenderPicker(l10n),
            onCountryTap: () => _showCountryPicker(l10n),
          );
        },
      ),
    );
  }
}
