import 'package:flutter/material.dart';

class LanguageToggleButton extends StatelessWidget {
  final String currentLanguage;
  final ValueChanged<String> onChanged;

  const LanguageToggleButton({
    super.key,
    required this.currentLanguage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = currentLanguage == 'ar';
    
    return IconButton(
      icon: Text(
        isArabic ? 'EN' : 'عربي',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () {
        onChanged(isArabic ? 'en' : 'ar');
      },
    );
  }
}
