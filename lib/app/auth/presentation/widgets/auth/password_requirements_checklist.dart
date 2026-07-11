import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/password_strength.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class PasswordRequirementsChecklist extends StatefulWidget {
  const PasswordRequirementsChecklist({
    required this.controller,
    required this.l10n,
    super.key,
  });

  final TextEditingController controller;
  final AppLocalizations l10n;

  @override
  State<PasswordRequirementsChecklist> createState() =>
      _PasswordRequirementsChecklistState();
}

class _PasswordRequirementsChecklistState
    extends State<PasswordRequirementsChecklist> {
  PasswordRequirements _requirements = const PasswordRequirements(
    hasValidLength: false,
    hasLetter: false,
    hasNumber: false,
    hasSpecialChar: false,
  );

  @override
  void initState() {
    super.initState();
    _requirements = PasswordRequirements.evaluate(widget.controller.text);
    widget.controller.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPasswordChanged);
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      _requirements = PasswordRequirements.evaluate(widget.controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RequirementRow(
          met: _requirements.hasValidLength,
          label: widget.l10n.passwordReqLength,
        ),
        const SizedBox(height: AppSizes.p6),
        _RequirementRow(
          met: _requirements.hasLetter,
          label: widget.l10n.passwordReqLetter,
        ),
        const SizedBox(height: AppSizes.p6),
        _RequirementRow(
          met: _requirements.hasNumber,
          label: widget.l10n.passwordReqNumber,
        ),
        const SizedBox(height: AppSizes.p6),
        _RequirementRow(
          met: _requirements.hasSpecialChar,
          label: widget.l10n.passwordReqSpecialChar,
        ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.met,
    required this.label,
  });

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF43A047);
    final inactiveColor = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: 0.45,
        );

    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 16,
          color: met ? activeColor : inactiveColor,
        ),
        const SizedBox(width: AppSizes.p8),
        Expanded(
          child: CustomText(
            label,
            fontSize: 12,
            color: met ? activeColor : inactiveColor,
            fontWeight: met ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
