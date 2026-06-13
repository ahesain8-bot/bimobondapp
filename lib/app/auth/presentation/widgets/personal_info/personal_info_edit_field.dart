import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PersonalInfoEditField extends StatelessWidget {
  const PersonalInfoEditField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.l10n,
    this.prefix,
    this.maxLines = 1,
    this.isRequired = true,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final AppLocalizations l10n;
  final String? prefix;
  final int maxLines;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
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
                  color: theme.disabledColor.withValues(alpha: 0.5),
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
            color: theme.disabledColor.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
