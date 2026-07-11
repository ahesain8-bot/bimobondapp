import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/password_strength.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatefulWidget {
  const PasswordStrengthIndicator({
    required this.controller,
    required this.l10n,
    super.key,
  });

  final TextEditingController controller;
  final AppLocalizations l10n;

  @override
  State<PasswordStrengthIndicator> createState() =>
      _PasswordStrengthIndicatorState();
}

class _PasswordStrengthIndicatorState extends State<PasswordStrengthIndicator> {
  PasswordStrengthResult _result = const PasswordStrengthResult(
    level: PasswordStrengthLevel.none,
    filledSegments: 0,
  );

  @override
  void initState() {
    super.initState();
    _result = PasswordStrength.evaluate(widget.controller.text);
    widget.controller.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPasswordChanged);
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      _result = PasswordStrength.evaluate(widget.controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _colorForLevel(_result.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_result.level != PasswordStrengthLevel.none) ...[
          Row(
            children: List.generate(PasswordStrength.maxSegments, (index) {
              final isFilled = index < _result.filledSegments;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < PasswordStrength.maxSegments - 1
                        ? AppSizes.p6
                        : 0,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    decoration: BoxDecoration(
                      color: isFilled
                          ? activeColor
                          : const Color(0xFFE3E3E3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSizes.p8),
          CustomText(
            '${widget.l10n.passwordStrengthLabel}: ${_labelForLevel(widget.l10n)}',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: activeColor,
          ),
        ],
      ],
    );
  }

  String _labelForLevel(AppLocalizations l10n) {
    return switch (_result.level) {
      PasswordStrengthLevel.none => '',
      PasswordStrengthLevel.weak => l10n.passwordStrengthWeak,
      PasswordStrengthLevel.fair => l10n.passwordStrengthFair,
      PasswordStrengthLevel.good => l10n.passwordStrengthGood,
      PasswordStrengthLevel.strong => l10n.passwordStrengthStrong,
    };
  }

  Color _colorForLevel(PasswordStrengthLevel level) {
    return switch (level) {
      PasswordStrengthLevel.none => const Color(0xFFE3E3E3),
      PasswordStrengthLevel.weak => const Color(0xFFE53935),
      PasswordStrengthLevel.fair => const Color(0xFFFB8C00),
      PasswordStrengthLevel.good => const Color(0xFFFDD835),
      PasswordStrengthLevel.strong => const Color(0xFF43A047),
    };
  }
}
