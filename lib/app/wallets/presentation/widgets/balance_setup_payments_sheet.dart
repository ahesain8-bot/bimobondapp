import 'package:bimobondapp/app/wallets/domain/entities/balance_entity.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BalanceSetupPaymentsSheet {
  BalanceSetupPaymentsSheet._();

  static Future<void> show(
    BuildContext context, {
    required List<PayoutSetupStep> steps,
    required ValueChanged<List<PayoutSetupStep>> onStepsChanged,
  }) {
    return GlassBottomSheet.showContent<void>(
      context,
      title: AppLocalizations.of(context)!.balanceSetupPaymentsTitle,
      isScrollControlled: true,
      adaptTheme: true,
      child: _BalanceSetupPaymentsBody(
        steps: steps,
        onStepsChanged: onStepsChanged,
      ),
    );
  }
}

class _BalanceSetupPaymentsBody extends StatelessWidget {
  const _BalanceSetupPaymentsBody({
    required this.steps,
    required this.onStepsChanged,
  });

  final List<PayoutSetupStep> steps;
  final ValueChanged<List<PayoutSetupStep>> onStepsChanged;

  String _stepTitle(AppLocalizations l10n, PayoutSetupStep step) {
    return switch (step.titleKey) {
      'balancePayoutMethodTitle' => l10n.balancePayoutMethodTitle,
      'balanceTaxInfoTitle' => l10n.balanceTaxInfoTitle,
      'balanceIdentityTitle' => l10n.balanceIdentityTitle,
      _ => step.titleKey,
    };
  }

  String _stepSubtitle(AppLocalizations l10n, PayoutSetupStep step) {
    if (step.isComplete && step.completedValue != null) {
      return step.completedValue!;
    }
    return switch (step.subtitleKey) {
      'balancePayoutMethodSubtitle' => l10n.balancePayoutMethodSubtitle,
      'balanceTaxInfoSubtitle' => l10n.balanceTaxInfoSubtitle,
      'balanceIdentitySubtitle' => l10n.balanceIdentitySubtitle,
      _ => step.subtitleKey,
    };
  }

  IconData _stepIcon(PayoutSetupStep step) {
    return switch (step.id) {
      'payout_method' => LucideIcons.creditCard,
      'tax' => LucideIcons.fileText,
      _ => LucideIcons.shieldCheck,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            l10n.balanceSetupPaymentsMessage,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
        ...steps.map((step) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Icon(
              step.isComplete ? LucideIcons.circleCheck : _stepIcon(step),
              color: step.isComplete
                  ? const Color(0xFF22C55E)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
            title: Text(
              _stepTitle(l10n, step),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Text(
              _stepSubtitle(l10n, step),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                LucideIcons.pencil,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              onPressed: () async {
                if (step.id == 'payout_method') {
                  final result = await context.pushNamed<String>(
                    'add_payout_method',
                  );
                  if (result != null && context.mounted) {
                    final updated = steps
                        .map(
                          (s) => s.id == step.id
                              ? s.copyWith(
                                  isComplete: true,
                                  completedValue: result,
                                )
                              : s,
                        )
                        .toList();
                    onStepsChanged(updated);
                  }
                }
              },
            ),
            onTap: () async {
              if (step.id == 'payout_method') {
                final result = await context.pushNamed<String>(
                  'add_payout_method',
                );
                if (result != null && context.mounted) {
                  final updated = steps
                      .map(
                        (s) => s.id == step.id
                            ? s.copyWith(
                                isComplete: true,
                                completedValue: result,
                              )
                            : s,
                      )
                      .toList();
                  onStepsChanged(updated);
                }
              }
            },
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }
}
