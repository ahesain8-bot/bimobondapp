import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/wallets/domain/entities/balance_entity.dart';
import 'package:bimobondapp/app/wallets/presentation/data/balance_mock_data.dart';
import 'package:bimobondapp/app/wallets/presentation/widgets/balance_setup_payments_sheet.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/money_format_utils.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  List<PayoutSetupStep> _payoutSteps = List<PayoutSetupStep>.from(
    BalanceMockData.payoutSteps,
  );
  int _payoutCarouselIndex = 0;

  String _displayName(AppLocalizations l10n) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      final name = authState.user.fullName?.trim();
      if (name != null && name.isNotEmpty) return name.split(' ').first;
      final username = authState.user.username?.trim();
      if (username != null && username.isNotEmpty) return username;
    }
    return l10n.balanceDefaultUserName;
  }

  void _openSetupPayments() {
    BalanceSetupPaymentsSheet.show(
      context,
      steps: _payoutSteps,
      onStepsChanged: (steps) => setState(() => _payoutSteps = steps),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final name = _displayName(l10n);
    final latestTx = BalanceMockData.transactionById(
      BalanceMockData.latestTransactionId,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.arrowLeft, size: 22),
                  onPressed: () => context.pop(),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.arrowLeftRight, size: 16),
                  label: Text(
                    BalanceMockData.currencyCode,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: Text(
                l10n.balanceUserTitle(name),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            _BalanceMainCard(
              balanceLabel: l10n.balanceEstimatedBalance,
              balanceAmount: MoneyFormatUtils.formatMoney(
                BalanceMockData.estimatedBalanceUsd,
                BalanceMockData.currencyCode,
                locale: locale,
              ),
              coinsLabel: l10n.coinsUnit,
              coinsAmount: LocaleFormatUtils.localizeDigits(
                BalanceMockData.coinBalance.toString(),
                locale,
              ),
              viewLabel: l10n.balanceView,
              getLabel: l10n.balanceGet,
              onGetCoins: () => context.pushNamed('wallet'),
            ),
            const SizedBox(height: 20),
            _SectionHeader(title: l10n.balanceScheduledPayouts),
            const SizedBox(height: 10),
            _ScheduledPayoutCard(
              amount: MoneyFormatUtils.formatMoney(
                BalanceMockData.scheduledPayoutsUsd,
                BalanceMockData.currencyCode,
                locale: locale,
              ),
              scheduleLabel: l10n.balanceViewFullSchedule,
              setupMessage: l10n.balanceSetupPaymentsBanner,
              setupButton: l10n.balanceSetup,
              carouselIndex: _payoutCarouselIndex,
              onSetup: _openSetupPayments,
              onPageChanged: (index) =>
                  setState(() => _payoutCarouselIndex = index),
            ),
            const SizedBox(height: 12),
            ...BalanceMockData.programs.map(
              (program) => _ProgramTile(
                title: _programName(l10n, program.nameKey),
                amount: MoneyFormatUtils.formatMoney(
                  program.amountUsd,
                  BalanceMockData.currencyCode,
                  locale: locale,
                ),
                secondaryAmount: program.secondaryAmountLabel,
                setupRequired: program.setupRequired,
                setupLabel: l10n.balanceSetupRequired,
                onTap: _openSetupPayments,
              ),
            ),
            TextButton(
              onPressed: () => context.pushNamed(
                'balance_transactions',
                queryParameters: {'tab': 'payout'},
              ),
              child: Text(l10n.balancePastPayouts),
            ),
            const SizedBox(height: 8),
            _TransactionsEntry(
              title: l10n.balanceTransactions,
              preview: latestTx == null
                  ? null
                  : l10n.balanceTransactionPreview(
                      latestTx.title,
                      MoneyFormatUtils.formatMoney(
                        latestTx.amountUsd,
                        BalanceMockData.currencyCode,
                        locale: locale,
                      ),
                    ),
              onTap: () => context.pushNamed('balance_transactions'),
            ),
            const SizedBox(height: 16),
            _PromoBanner(
              title: l10n.balanceFirstCoinOfferTitle,
              subtitle: l10n.balanceFirstCoinOfferSubtitle,
              action: l10n.balanceGetNow,
              onTap: () => context.pushNamed('wallet'),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: l10n.balanceMonetization,
              trailing: l10n.balanceViewMore,
              onTrailingTap: _openSetupPayments,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MonetizationTile(
                    icon: LucideIcons.radio,
                    label: l10n.balanceMonetizationLive,
                    onTap: _openSetupPayments,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MonetizationTile(
                    icon: LucideIcons.shield,
                    label: l10n.balanceMonetizationActivities,
                    onTap: _openSetupPayments,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionHeader(title: l10n.balanceServices),
            const SizedBox(height: 10),
            _ServiceTile(
              icon: LucideIcons.wallet,
              title: l10n.balancePaymentMethods,
              badge: l10n.balanceRequired,
              onTap: _openSetupPayments,
            ),
            _ServiceTile(
              icon: LucideIcons.fileCheck,
              title: l10n.balanceTaxInformation,
              onTap: _openSetupPayments,
            ),
            _ServiceTile(
              icon: LucideIcons.badgeCheck,
              title: l10n.balanceIdentityVerification,
              onTap: _openSetupPayments,
            ),
            const SizedBox(height: 16),
            _MonetizationCenterBanner(
              title: l10n.balanceMonetizationCenter,
              action: l10n.balanceExplore,
              onTap: _openSetupPayments,
            ),
          ],
        ),
      ),
    );
  }

  String _programName(AppLocalizations l10n, String key) {
    return switch (key) {
      'balanceProgramCreatorRewards' => l10n.balanceProgramCreatorRewards,
      'balanceProgramTiktokGo' => l10n.balanceProgramTiktokGo,
      'balanceProgramSeries' => l10n.balanceProgramSeries,
      _ => key,
    };
  }
}

class _BalanceMainCard extends StatelessWidget {
  const _BalanceMainCard({
    required this.balanceLabel,
    required this.balanceAmount,
    required this.coinsLabel,
    required this.coinsAmount,
    required this.viewLabel,
    required this.getLabel,
    required this.onGetCoins,
  });

  final String balanceLabel;
  final String balanceAmount;
  final String coinsLabel;
  final String coinsAmount;
  final String viewLabel;
  final String getLabel;
  final VoidCallback onGetCoins;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161823),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        balanceLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        balanceAmount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$viewLabel >',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: AppCoinAmount(
                    iconSize: 14,
                    text: '$coinsAmount $coinsLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onGetCoins,
                  child: Text(
                    '$getLabel >',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduledPayoutCard extends StatelessWidget {
  const _ScheduledPayoutCard({
    required this.amount,
    required this.scheduleLabel,
    required this.setupMessage,
    required this.setupButton,
    required this.carouselIndex,
    required this.onSetup,
    required this.onPageChanged,
  });

  final String amount;
  final String scheduleLabel;
  final String setupMessage;
  final String setupButton;
  final int carouselIndex;
  final VoidCallback onSetup;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            amount,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            scheduleLabel,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    setupMessage,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onSetup,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(72, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(setupButton),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == carouselIndex
                      ? AppTheme.primaryColor
                      : Colors.black.withValues(alpha: 0.15),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ProgramTile extends StatelessWidget {
  const _ProgramTile({
    required this.title,
    required this.amount,
    required this.setupRequired,
    required this.setupLabel,
    required this.onTap,
    this.secondaryAmount,
  });

  final String title;
  final String amount;
  final String? secondaryAmount;
  final bool setupRequired;
  final String setupLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: setupRequired
            ? Text(
                setupLabel,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  amount,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (secondaryAmount != null)
                  Text(
                    secondaryAmount!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
            const DirectionalChevronIcon(size: 18),
          ],
        ),
      ),
    );
  }
}

class _TransactionsEntry extends StatelessWidget {
  const _TransactionsEntry({
    required this.title,
    required this.onTap,
    this.preview,
  });

  final String title;
  final String? preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (preview != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Flexible(
                  child: Text(
                    preview!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
              ],
              const DirectionalChevronIcon(size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.55),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.gift,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        if (trailing != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.45),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MonetizationTile extends StatelessWidget {
  const _MonetizationTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: Colors.black.withValues(alpha: 0.55)),
              const Spacer(),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, size: 22),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null)
              Text(
                badge!,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            const DirectionalChevronIcon(size: 18),
          ],
        ),
      ),
    );
  }
}

class _MonetizationCenterBanner extends StatelessWidget {
  const _MonetizationCenterBanner({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF161823),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      action,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const AppCoinIcon(size: 36),
            ],
          ),
        ),
      ),
    );
  }
}
