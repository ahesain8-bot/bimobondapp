import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_custom_amount_section.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_top_up_button.dart';
import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';
import 'package:bimobondapp/app/wallets/domain/utils/wallet_coin_pricing.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_inventory_usecase.dart';
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import 'package:bimobondapp/app/wallets/domain/usecases/wallet_usecases.dart';
import 'package:bimobondapp/app/wallets/presentation/di/wallets_injector.dart'
    as wallets_di;
import 'package:bimobondapp/app/wallets/domain/entities/balance_entity.dart';
import 'package:bimobondapp/app/wallets/presentation/data/balance_mock_data.dart';
import 'package:bimobondapp/app/wallets/presentation/widgets/balance_setup_payments_sheet.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/money_format_utils.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
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
  int _balanceCoins = 0;
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    setState(() => _loadingBalance = true);

    final walletResult = await wallets_di.sl<GetMyWalletUseCase>()(NoParams());
    var balance = 0;
    walletResult.fold((_) {}, (wallet) => balance = wallet.balanceCoins);

    if (balance == 0) {
      final inventoryResult = await gifts_di.sl<GetGiftInventoryUseCase>()(
        NoParams(),
      );
      inventoryResult.fold((_) {}, (inv) => balance = inv.balanceCoins);
    }

    if (!mounted) return;
    setState(() {
      _balanceCoins = balance;
      _loadingBalance = false;
    });
  }

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
              balanceLabel: l10n.coinsAvailableBalance,
              coinsAmount: LocaleFormatUtils.localizeDigits(
                _balanceCoins.toString(),
                locale,
              ),
              coinsLabel: l10n.coinsUnit,
              loading: _loadingBalance,
            ),
            const SizedBox(height: 16),
            _BalanceTopUpSection(onBalanceChanged: _refreshBalance),
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
    required this.coinsAmount,
    required this.coinsLabel,
    required this.loading,
  });

  final String balanceLabel;
  final String coinsAmount;
  final String coinsLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161823),
        borderRadius: BorderRadius.circular(12),
      ),
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
          const SizedBox(height: 8),
          if (loading)
            const SizedBox(
              height: 36,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: CustomLoadingWidget(size: 28),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const AppCoinIcon(size: 28),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    coinsAmount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  coinsLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BalanceTopUpSection extends StatefulWidget {
  const _BalanceTopUpSection({required this.onBalanceChanged});

  final VoidCallback onBalanceChanged;

  @override
  State<_BalanceTopUpSection> createState() => _BalanceTopUpSectionState();
}

class _BalanceTopUpSectionState extends State<_BalanceTopUpSection> {
  final _getPackages = wallets_di.sl<GetCoinPackagesUseCase>();
  final _purchaseCoins = wallets_di.sl<PurchaseCoinsUseCase>();
  final _topUpWallet = wallets_di.sl<TopUpWalletUseCase>();
  final _customCoinsController = TextEditingController();

  List<CoinPackageEntity> _packages = [];
  bool _loading = true;
  bool _purchasing = false;
  String? _error;
  int _selectedIndex = 0;

  WalletTopUpQuote get _activeQuote {
    final customCoins = WalletCoinPricing.parseCoinsInput(
      _customCoinsController.text,
    );
    if (customCoins > 0) {
      return WalletCoinPricing.resolveQuote(customCoins, _packages);
    }
    if (_packages.isEmpty) {
      return const WalletTopUpQuote(coins: 0, price: 0);
    }
    return WalletTopUpQuote.fromEntity(_packages[_selectedIndex]);
  }

  @override
  void initState() {
    super.initState();
    _customCoinsController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _customCoinsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final packagesResult = await _getPackages(NoParams());
    if (!mounted) return;

    packagesResult.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (packages) => setState(() {
        _packages = packages.where((p) => p.isActive).toList();
        _loading = false;
        if (_selectedIndex >= _packages.length) _selectedIndex = 0;
      }),
    );
  }

  Future<void> _purchaseCustom(WalletTopUpQuote quote) async {
    final l10n = AppLocalizations.of(context)!;
    final priceLabel = MoneyFormatUtils.formatMoney(
      quote.price,
      quote.currencyCode,
      locale: Localizations.localeOf(context),
    );

    await PopupDialogs.showConfirmDialog(
      context,
      title: l10n.walletTopUpButton,
      message: '${quote.coins} ${l10n.coinsUnit}\n$priceLabel',
      confirmLabel: l10n.walletPayButton(priceLabel),
      cancelLabel: l10n.cancel,
      onConfirm: () async {
        if (!mounted) return;
        setState(() => _purchasing = true);
        final txId = 'app-${DateTime.now().millisecondsSinceEpoch}';
        final result = await _topUpWallet(
          TopUpWalletParams(
            paidPrice: quote.price,
            provider: 'MOCK',
            providerTxId: txId,
            currencyCode: quote.currencyCode,
          ),
        );

        if (!mounted) return;
        setState(() => _purchasing = false);

        result.fold((f) => PopupDialogs.showErrorDialog(context, f.message), (
          _,
        ) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.walletPurchaseSuccess(quote.coins)),
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onBalanceChanged();
          _customCoinsController.clear();
        });
      },
    );
  }

  Future<void> _purchase(CoinPackageEntity pack) async {
    final l10n = AppLocalizations.of(context)!;
    final priceLabel = MoneyFormatUtils.formatMoney(
      pack.price,
      pack.currencyCode,
      locale: Localizations.localeOf(context),
    );

    await PopupDialogs.showConfirmDialog(
      context,
      title: l10n.walletTopUpButton,
      message: '${pack.coinAmount} ${l10n.coinsUnit}\n$priceLabel',
      confirmLabel: l10n.walletPayButton(priceLabel),
      cancelLabel: l10n.cancel,
      onConfirm: () async {
        if (!mounted) return;
        setState(() => _purchasing = true);
        final txId = 'app-${DateTime.now().millisecondsSinceEpoch}';
        final result = await _purchaseCoins(
          PurchaseCoinsParams(
            packageId: pack.id,
            provider: 'MOCK',
            providerTxId: txId,
          ),
        );

        if (!mounted) return;
        setState(() => _purchasing = false);

        result.fold((f) => PopupDialogs.showErrorDialog(context, f.message), (
          _,
        ) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.walletPurchaseSuccess(pack.coinAmount)),
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onBalanceChanged();
          _customCoinsController.clear();
        });
      },
    );
  }

  Future<void> _onPayPressed() async {
    final l10n = AppLocalizations.of(context)!;
    final quote = _activeQuote;
    if (!quote.isValid) {
      PopupDialogs.showErrorDialog(context, l10n.walletCustomAmountInvalid);
      return;
    }

    if (quote.isPackageQuote) {
      CoinPackageEntity? pack;
      for (final candidate in _packages) {
        if (candidate.id == quote.packageId) {
          pack = candidate;
          break;
        }
      }
      if (pack != null) {
        await _purchase(pack);
      }
      return;
    }

    final customCoins = WalletCoinPricing.parseCoinsInput(
      _customCoinsController.text,
    );
    if (customCoins > 0) {
      await _purchaseCustom(quote);
      return;
    }

    if (_packages.isNotEmpty) {
      await _purchase(_packages[_selectedIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CustomLoadingWidget(size: 36)),
      );
    }

    if (_error != null && _packages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: Text(l10n.liveGiftRetry)),
          ],
        ),
      );
    }

    final quote = _activeQuote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WalletCustomAmountSection(
          controller: _customCoinsController,
          packages: _packages,
          currencyCode: _packages.isNotEmpty
              ? _packages.first.currencyCode
              : BalanceMockData.currencyCode,
          onPackageSelected: (pack) {
            setState(() {
              _selectedIndex = _packages.indexOf(pack);
            });
          },
        ),
        const SizedBox(height: AppSizes.p16),
        _purchasing
            ? const Center(child: CustomLoadingWidget(size: 36))
            : WalletTopUpButton(
                quote: quote,
                enabled: quote.isValid,
                onPressed: _onPayPressed,
              ),
      ],
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
