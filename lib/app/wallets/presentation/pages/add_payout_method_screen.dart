import 'package:bimobondapp/app/wallets/domain/entities/balance_entity.dart';
import 'package:bimobondapp/app/wallets/presentation/data/balance_mock_data.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddPayoutMethodScreen extends StatefulWidget {
  const AddPayoutMethodScreen({super.key});

  @override
  State<AddPayoutMethodScreen> createState() => _AddPayoutMethodScreenState();
}

class _AddPayoutMethodScreenState extends State<AddPayoutMethodScreen> {
  String _selectedCountry = 'Vietnam';
  PayoutMethodType? _selectedMethod;

  String _methodTitle(AppLocalizations l10n, PayoutMethodOption option) {
    return switch (option.titleKey) {
      'balancePayoutZaloPay' => l10n.balancePayoutZaloPay,
      'balancePayoutBank' => l10n.balancePayoutBank,
      'balancePayoutPayPal' => l10n.balancePayoutPayPal,
      _ => option.titleKey,
    };
  }

  String _methodSubtitle(AppLocalizations l10n, PayoutMethodOption option) {
    return switch (option.subtitleKey) {
      'balancePayoutZaloPayDetails' => l10n.balancePayoutZaloPayDetails,
      'balancePayoutBankDetails' => l10n.balancePayoutBankDetails,
      'balancePayoutPayPalDetails' => l10n.balancePayoutPayPalDetails,
      _ => option.subtitleKey,
    };
  }

  void _confirmSelection(PayoutMethodOption option) {
    setState(() => _selectedMethod = option.type);

    final email = switch (option.type) {
      PayoutMethodType.paypal => 'tinsleyfolk@paypal.com',
      PayoutMethodType.bank => 'Bank account ending 4821',
      PayoutMethodType.zaloPay => 'ZaloPay account ending 9012',
    };

    context.pop(email);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: CustomAppBar(title: l10n.balanceAddPayoutMethod),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            l10n.balanceCountryRegion,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCountry,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Vietnam', child: Text('Vietnam')),
                  DropdownMenuItem(
                    value: 'United States',
                    child: Text('United States'),
                  ),
                  DropdownMenuItem(
                    value: 'Saudi Arabia',
                    child: Text('Saudi Arabia'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedCountry = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.balanceCountryRegionNote,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.45),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.balanceChoosePayoutMethod,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ...BalanceMockData.payoutMethods.map((option) {
            final selected = _selectedMethod == option.type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _confirmSelection(option),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primaryColor
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _methodTitle(l10n, option)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _methodTitle(l10n, option),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _methodSubtitle(l10n, option),
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const DirectionalChevronIcon(size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
