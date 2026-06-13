import 'package:flutter/material.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_auth_widgets.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PhoneTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? initialCountryCode;
  final Function(String countryCode)? onCountryCodeChanged;
  final String? hintText;
  final String? labelText;
  final String? Function(String?)? validator;
  final bool isProfileStyle;
  final bool isGlassStyle;

  const PhoneTextField({
    super.key,
    required this.controller,
    this.initialCountryCode = '+20',
    this.onCountryCodeChanged,
    this.hintText,
    this.labelText,
    this.validator,
    this.isProfileStyle = false,
    this.isGlassStyle = false,
  });

  @override
  State<PhoneTextField> createState() => _PhoneTextFieldState();
}

class _PhoneTextFieldState extends State<PhoneTextField> {
  late String _selectedCountryCode;

  final List<Map<String, String>> _countries = [
    {'code': '+20', 'name': 'Egypt', 'flag': '🇪🇬'},
    {'code': '+966', 'name': 'Saudi Arabia', 'flag': '🇸🇦'},
    {'code': '+971', 'name': 'UAE', 'flag': '🇦🇪'},
    {'code': '+1', 'name': 'USA', 'flag': '🇺🇸'},
    {'code': '+44', 'name': 'UK', 'flag': '🇬🇧'},
    {'code': '+965', 'name': 'Kuwait', 'flag': '🇰🇼'},
    {'code': '+974', 'name': 'Qatar', 'flag': '🇶🇦'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCountryCode = widget.initialCountryCode ?? '+20';
  }

  String _flagForCode(String code) {
    switch (code) {
      case '+20':
        return '🇪🇬';
      case '+966':
        return '🇸🇦';
      case '+971':
        return '🇦🇪';
      case '+1':
        return '🇺🇸';
      case '+44':
        return '🇬🇧';
      case '+965':
        return '🇰🇼';
      case '+974':
        return '🇶🇦';
      default:
        return '';
    }
  }

  void _showCountryPicker() {
    final l10n = AppLocalizations.of(context)!;
    final List<Map<String, String>> localizedCountries = [
      {'code': '+20', 'name': l10n.egypt, 'flag': '🇪🇬'},
      {'code': '+966', 'name': l10n.saudiArabia, 'flag': '🇸🇦'},
      {'code': '+971', 'name': l10n.uae, 'flag': '🇦🇪'},
      {'code': '+1', 'name': l10n.usa, 'flag': '🇺🇸'},
      {'code': '+44', 'name': l10n.uk, 'flag': '🇬🇧'},
      {'code': '+965', 'name': l10n.kuwait, 'flag': '🇰🇼'},
      {'code': '+974', 'name': l10n.qatar, 'flag': '🇶🇦'},
    ];

    GlassBottomSheet.showActions<void>(
      context,
      title: l10n.selectCountry,
      scrollable: true,
      children: [
        for (final country in localizedCountries)
          GlassBottomSheetListTile(
            label: '${country['flag']} ${country['name']}',
            isSelected: _selectedCountryCode == country['code'],
            onTap: () {
              setState(() {
                _selectedCountryCode = country['code']!;
              });
              widget.onCountryCodeChanged?.call(country['code']!);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    if (widget.isProfileStyle) {
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.labelText != null)
              SizedBox(
                width: 100,
                child: CustomText(widget.labelText!, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            InkWell(
              onTap: _showCountryPicker,
              child: Row(
                children: [
                  CustomText(
                    _selectedCountryCode,
                    fontSize: 15,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  Icon(Icons.arrow_drop_down, size: 20, color: theme.disabledColor.withOpacity(0.5)),
                  const SizedBox(width: AppSizes.p8),
                ],
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: widget.hintText ?? l10n.phoneHint,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(
                    color: theme.disabledColor.withOpacity(0.5),
                    fontSize: 15,
                  ),
                ),
                validator: widget.validator,
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

    if (widget.isGlassStyle) {
      final style = AuthGlassStyle.of(context);

      return FormField<String>(
        validator: widget.validator,
        initialValue: widget.controller.text,
        builder: (field) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidGlassSurface(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                backgroundColor: style.glassFill,
                borderColor: field.hasError
                    ? AppTheme.errorAccent.withValues(alpha: 0.55)
                    : style.glassBorder,
                child: Row(
                  children: [
                    InkWell(
                      onTap: _showCountryPicker,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(AppSizes.radiusLg),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.p12,
                          vertical: AppSizes.p16,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _flagForCode(_selectedCountryCode),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: AppSizes.p6),
                            CustomText(
                              _selectedCountryCode,
                              fontWeight: FontWeight.bold,
                              color: style.textColor,
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 20,
                              color: style.iconColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: style.glassBorder,
                    ),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        keyboardType: TextInputType.phone,
                        onChanged: (value) {
                          field.didChange(value);
                          if (field.hasError) field.validate();
                        },
                        style: TextStyle(color: style.textColor, fontSize: 16),
                        cursorColor: AppTheme.primaryColor,
                        decoration: InputDecoration(
                          hintText: widget.hintText ?? l10n.phoneHint,
                          hintStyle: TextStyle(color: style.hintColor),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.p12,
                            vertical: AppSizes.p16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (field.hasError && field.errorText != null)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSizes.p6,
                    left: AppSizes.p4,
                  ),
                  child: Text(
                    field.errorText!,
                    style: const TextStyle(
                      color: AppTheme.errorAccent,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          CustomText(
            widget.labelText!,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          const SizedBox(height: AppSizes.p8),
        ],
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(AppSizes.p12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              // Country Code Picker
              InkWell(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.p12,
                    vertical: AppSizes.p12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _flagForCode(_selectedCountryCode),
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: AppSizes.p4),
                      CustomText(
                        _selectedCountryCode,
                        fontWeight: FontWeight.bold,
                      ),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
              ),
              // Phone Number Input
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? l10n.phoneHint,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p12,
                    ),
                    hintStyle: TextStyle(
                      color: theme.disabledColor.withOpacity(0.5),
                    ),
                  ),
                  validator: widget.validator,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}