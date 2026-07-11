import 'dart:async';

import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_preview_entity.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/get_auction_pricing_preview_usecase.dart';
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/gifts/data/models/gift_model.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_inventory_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gifts_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/purchase_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_custom_amount_section.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_top_up_button.dart';
import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';
import 'package:bimobondapp/app/wallets/domain/usecases/wallet_usecases.dart';
import 'package:bimobondapp/app/wallets/domain/utils/wallet_coin_pricing.dart';
import 'package:bimobondapp/app/wallets/presentation/di/wallets_injector.dart'
    as wallets_di;
import 'package:bimobondapp/app/wallets/presentation/widgets/wallet_accounting_label.dart';
import 'package:bimobondapp/app/wallets/presentation/widgets/wallet_package_quotes_grid.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/money_format_utils.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CoinsHubScreen extends StatefulWidget {
  const CoinsHubScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<CoinsHubScreen> createState() => _CoinsHubScreenState();
}

class _CoinsHubScreenState extends State<CoinsHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _balanceCoins = 0;
  bool _loadingBalance = true;
  DateTime? _lastRefreshedAt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _tabController.addListener(() => setState(() {}));
    _refreshBalance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    } else if (mounted) {
      // Wallet is source of truth when available.
    }

    if (!mounted) return;
    setState(() {
      _balanceCoins = balance;
      _loadingBalance = false;
      _lastRefreshedAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(title: l10n.coinsHubTitle, showBackButton: true),
      body: Column(
        children: [
          _WalletBalanceHero(
            balanceCoins: _balanceCoins,
            loading: _loadingBalance,
            lastRefreshedAt: _lastRefreshedAt,
            selectedTab: _tabController.index,
            onRefresh: _refreshBalance,
            onTopUp: () => _tabController.animateTo(0),
            onMarket: () => _tabController.animateTo(1),
            onVault: () => _tabController.animateTo(2),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                CoinsBuyTab(onBalanceChanged: _refreshBalance),
                CoinsMarketTab(
                  onBalanceChanged: _refreshBalance,
                  onTopUpRequested: () => _tabController.animateTo(0),
                ),
                CoinsInventoryTab(onBalanceChanged: _refreshBalance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletBalanceHero extends StatelessWidget {
  const _WalletBalanceHero({
    required this.balanceCoins,
    required this.loading,
    required this.selectedTab,
    required this.onRefresh,
    required this.onTopUp,
    required this.onMarket,
    required this.onVault,
    this.lastRefreshedAt,
  });

  final int balanceCoins;
  final bool loading;
  final int selectedTab;
  final DateTime? lastRefreshedAt;
  final VoidCallback onRefresh;
  final VoidCallback onTopUp;
  final VoidCallback onMarket;
  final VoidCallback onVault;

  String _accountTitle(AppLocalizations l10n, UserEntity? user) {
    final name = user?.fullName?.trim();
    if (name != null && name.isNotEmpty) {
      return l10n.coinsWalletAccountName(name);
    }
    final username = user?.username?.trim();
    if (username != null && username.isNotEmpty) {
      return l10n.coinsWalletAccountName(username);
    }
    return l10n.coinsHubTitle;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final balanceText = LocaleFormatUtils.localizeDigits(
      balanceCoins.toString(),
      locale,
    );
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthSuccess ? authState.user : null;
    final glass = _WalletGlassStyle(isDark: isDark, colorScheme: colorScheme);

    final footerDate = lastRefreshedAt != null
        ? DateFormat(
            'MMM d, yyyy',
            l10n.localeName,
          ).format(lastRefreshedAt!.toLocal()).toUpperCase()
        : '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: LiquidGlassSurface(
          borderRadius: BorderRadius.circular(28),
          blurSigma: 24,
          backgroundColor: glass.cardFill,
          borderColor: glass.cardBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SafeNetworkAvatar(
                          imageUrl: user?.avatarUrl?.isNotEmpty == true
                              ? MediaUtils.resolveAbsoluteUrl(user!.avatarUrl!)
                              : null,
                          radius: 22,
                          fallbackText: user?.username ?? user?.fullName ?? 'U',
                          backgroundColor: AppTheme.primaryColor.withValues(
                            alpha: 0.14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _accountTitle(l10n, user),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: glass.primaryText,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          offset: const Offset(0, 40),
                          color: colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (value) {
                            if (value == 'refresh') onRefresh();
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'refresh',
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.refreshCw,
                                    size: 18,
                                    color: colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(l10n.coinsBalanceRefresh),
                                ],
                              ),
                            ),
                          ],
                          child: _BalanceIconChip(
                            icon: LucideIcons.ellipsis,
                            style: glass,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.coinsAvailableBalance,
                      style: TextStyle(
                        color: glass.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    loading
                        ? const SizedBox(
                            height: 40,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: CustomLoadingWidget(size: 28),
                            ),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: Text(
                                  balanceText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: glass.primaryText,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.coinsUnit,
                                style: TextStyle(
                                  color: glass.secondaryText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _BalanceActionButton(
                            icon: LucideIcons.plus,
                            style: glass,
                            selected: selectedTab == 0,
                            onTap: onTopUp,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BalanceActionButton(
                            icon: LucideIcons.store,
                            style: glass,
                            selected: selectedTab == 1,
                            onTap: onMarket,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BalanceActionButton(
                            icon: LucideIcons.archive,
                            style: glass,
                            selected: selectedTab == 2,
                            onTap: onVault,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LiquidGlassSurface(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                blurSigma: 16,
                backgroundColor: glass.footerFill,
                borderColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Text(
                  l10n.coinsBalanceFooter(
                    footerDate,
                    l10n.coinsBalanceFooterHint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: glass.footerText,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletGlassStyle {
  const _WalletGlassStyle({required this.isDark, required this.colorScheme});

  final bool isDark;
  final ColorScheme colorScheme;

  Color get cardFill => isDark
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.white.withValues(alpha: 0.82);

  Color get cardBorder => isDark
      ? Colors.white.withValues(alpha: 0.18)
      : Colors.black.withValues(alpha: 0.06);

  Color get buttonFill => isDark
      ? Colors.white.withValues(alpha: 0.1)
      : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);

  Color get buttonBorder => isDark
      ? Colors.white.withValues(alpha: 0.12)
      : colorScheme.outlineVariant.withValues(alpha: 0.45);

  Color get footerFill => isDark
      ? Colors.black.withValues(alpha: 0.22)
      : colorScheme.surfaceContainerHighest.withValues(alpha: 0.42);

  Color get primaryText => isDark ? Colors.white : const Color(0xDE000000);

  Color get secondaryText =>
      isDark ? Colors.white.withValues(alpha: 0.62) : const Color(0x8A000000);

  Color get footerText => isDark
      ? Colors.white.withValues(alpha: 0.5)
      : colorScheme.onSurfaceVariant.withValues(alpha: 0.85);
}

class _BalanceActionButton extends StatelessWidget {
  const _BalanceActionButton({
    required this.icon,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final _WalletGlassStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidGlassSurface(
              borderRadius: BorderRadius.circular(14),
              blurSigma: 12,
              backgroundColor: style.buttonFill,
              borderColor: style.buttonBorder,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              child: Icon(icon, size: 20, color: style.primaryText),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? dotColor : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceIconChip extends StatelessWidget {
  const _BalanceIconChip({required this.icon, required this.style});

  final IconData icon;
  final _WalletGlassStyle style;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(20),
      blurSigma: 12,
      backgroundColor: style.buttonFill,
      borderColor: style.buttonBorder,
      padding: const EdgeInsets.all(8),
      child: Icon(icon, size: 18, color: style.primaryText),
    );
  }
}

class CoinsBuyTab extends StatefulWidget {
  const CoinsBuyTab({required this.onBalanceChanged, super.key});

  final VoidCallback onBalanceChanged;

  @override
  State<CoinsBuyTab> createState() => _CoinsBuyTabState();
}

class _CoinsBuyTabState extends State<CoinsBuyTab> {
  final _getPackages = wallets_di.sl<GetCoinPackagesUseCase>();
  final _purchaseCoins = wallets_di.sl<PurchaseCoinsUseCase>();
  final _topUpWallet = wallets_di.sl<TopUpWalletUseCase>();
  final _getWallet = wallets_di.sl<GetMyWalletUseCase>();
  final _getPricingPreview = auctions_di.sl<GetAuctionPricingPreviewUseCase>();
  final _customCoinsController = TextEditingController();

  List<CoinPackageEntity> _packages = [];
  WalletEntity? _wallet;
  AuctionPricingPreviewEntity? _pricingPreview;
  Timer? _previewDebounce;
  bool _loading = true;
  bool _purchasing = false;
  bool _loadingPricingPreview = false;
  String? _error;
  int _selectedIndex = 0;
  int? _previewForCoins;

  WalletTopUpQuote get _activeQuote {
    final customCoins = WalletCoinPricing.parseCoinsInput(
      _customCoinsController.text,
    );
    if (customCoins > 0) {
      final packageMatch = WalletCoinPricing.packageForCoins(
        customCoins,
        _packages,
      );
      if (packageMatch != null) {
        return WalletTopUpQuote.fromEntity(packageMatch);
      }
      if (_pricingPreview != null &&
          !_loadingPricingPreview &&
          _previewForCoins == customCoins) {
        return WalletTopUpQuote.fromPricingPreview(
          _pricingPreview!,
          requestedCoins: customCoins,
        );
      }
      return const WalletTopUpQuote(coins: 0, price: 0);
    }
    if (_packages.isEmpty) {
      return const WalletTopUpQuote(coins: 0, price: 0);
    }
    return WalletTopUpQuote.fromEntity(_packages[_selectedIndex]);
  }

  @override
  void initState() {
    super.initState();
    _customCoinsController.addListener(_onCustomCoinsChanged);
    _load();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _customCoinsController.removeListener(_onCustomCoinsChanged);
    _customCoinsController.dispose();
    super.dispose();
  }

  void _onCustomCoinsChanged() {
    final coins = WalletCoinPricing.parseCoinsInput(
      _customCoinsController.text,
    );
    setState(() {});
    _schedulePricingPreview(coins);
  }

  Future<void> _fetchPricingPreview(int coins) async {
    final result = await _getPricingPreview(
      AuctionPricingPreviewParams(targetCoins: coins),
    );
    if (!mounted) return;

    final currentCoins = WalletCoinPricing.parseCoinsInput(
      _customCoinsController.text,
    );
    if (currentCoins != coins) return;

    result.fold(
      (_) => setState(() {
        _loadingPricingPreview = false;
        _pricingPreview = null;
        _previewForCoins = null;
      }),
      (preview) => setState(() {
        _loadingPricingPreview = false;
        _pricingPreview = preview;
        _previewForCoins = coins;
      }),
    );
  }

  void _schedulePricingPreview(int coins) {
    _previewDebounce?.cancel();
    if (coins <= 0) {
      setState(() {
        _pricingPreview = null;
        _previewForCoins = null;
        _loadingPricingPreview = false;
      });
      return;
    }

    if (WalletCoinPricing.packageForCoins(coins, _packages) != null) {
      setState(() {
        _pricingPreview = null;
        _previewForCoins = null;
        _loadingPricingPreview = false;
      });
      return;
    }

    setState(() {
      _pricingPreview = null;
      _previewForCoins = null;
      _loadingPricingPreview = true;
    });
    _previewDebounce = Timer(const Duration(milliseconds: 400), () {
      _fetchPricingPreview(coins);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final packagesResult = await _getPackages(NoParams());
    final walletResult = await _getWallet(NoParams());

    if (!mounted) return;

    packagesResult.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (packages) {
        walletResult.fold((_) {}, (wallet) => _wallet = wallet);
        setState(() {
          _packages = packages;
          _loading = false;
          if (_selectedIndex >= packages.length) _selectedIndex = 0;
        });
      },
    );
  }

  Future<void> _purchaseCustom(WalletTopUpQuote quote) async {
    final l10n = AppLocalizations.of(context)!;
    if (!quote.isValid) {
      PopupDialogs.showErrorDialog(context, l10n.walletCustomAmountInvalid);
      return;
    }

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
          _load();
        });
      },
    );
  }

  Future<void> _onTopUpPressed() async {
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
          _load();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Center(child: CustomLoadingWidget(size: 48));
    }

    if (_error != null && _packages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: Text(l10n.notificationsRetry),
              ),
            ],
          ),
        ),
      );
    }

    final accountings = _wallet?.accountings ?? [];
    final quote = _activeQuote;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.p16),
        children: [
          WalletCustomAmountSection(
            controller: _customCoinsController,
            packages: _packages,
            pricingPreview: _pricingPreview,
            previewForCoins: _previewForCoins,
            loadingPricingPreview: _loadingPricingPreview,
            currencyCode: _packages.isNotEmpty
                ? _packages.first.currencyCode
                : 'USD',
            onPackageSelected: (pack) {
              setState(() {
                _selectedIndex = _packages.indexOf(pack);
                _pricingPreview = null;
                _previewForCoins = null;
                _loadingPricingPreview = false;
              });
            },
          ),
          const SizedBox(height: AppSizes.p20),
          CustomText(
            l10n.walletChoosePackage,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          const SizedBox(height: AppSizes.p12),
          WalletPackageQuotesGrid(
            packages: _packages,
            selectedIndex: _selectedIndex,
            onPackageSelected: (index) {
              setState(() {
                _selectedIndex = index;
                _customCoinsController.text = '${_packages[index].coinAmount}';
                _pricingPreview = null;
                _previewForCoins = null;
                _loadingPricingPreview = false;
              });
            },
          ),
          const SizedBox(height: AppSizes.p16),
          _purchasing
              ? const Center(child: CustomLoadingWidget(size: 36))
              : WalletTopUpButton(
                  quote: quote,
                  enabled: quote.isValid && !_loadingPricingPreview,
                  onPressed: _onTopUpPressed,
                ),
          if (accountings.isNotEmpty) ...[
            const SizedBox(height: AppSizes.p24),
            CustomText(
              l10n.coinsHistoryTitle,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            const SizedBox(height: AppSizes.p8),
            ...accountings
                .take(20)
                .map((entry) => _LedgerEntryTile(entry: entry)),
          ],
        ],
      ),
    );
  }
}

class _LedgerEntryTile extends StatelessWidget {
  const _LedgerEntryTile({required this.entry});

  final WalletAccountingEntity entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCredit = entry.action != 'DEBIT';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isCredit ? colorScheme.primary : colorScheme.error)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _ledgerIcon(entry.type),
              color: isCredit ? colorScheme.primary : colorScheme.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  walletAccountingLabel(l10n, entry.type),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (entry.reason?.isNotEmpty == true)
                  Text(
                    entry.reason!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${entry.amountCoins}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isCredit ? colorScheme.primary : colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  IconData _ledgerIcon(String type) {
    switch (type) {
      case 'GIFT_PURCHASE':
        return LucideIcons.gift;
      case 'GIFT_RECEIVED':
        return LucideIcons.heart;
      case 'AD_PROMOTION_PURCHASE':
        return LucideIcons.megaphone;
      default:
        return LucideIcons.coins;
    }
  }
}

class CoinsMarketTab extends StatefulWidget {
  const CoinsMarketTab({
    required this.onBalanceChanged,
    this.onTopUpRequested,
    super.key,
  });

  final VoidCallback onBalanceChanged;
  final VoidCallback? onTopUpRequested;

  @override
  State<CoinsMarketTab> createState() => _CoinsMarketTabState();
}

class _CoinsMarketTabState extends State<CoinsMarketTab> {
  final _getGifts = gifts_di.sl<GetGiftsUseCase>();
  final _getInventory = gifts_di.sl<GetGiftInventoryUseCase>();
  final _purchaseGift = gifts_di.sl<PurchaseGiftUseCase>();

  List<GiftEntity> _catalog = [];
  GiftInventoryEntity? _inventory;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final giftsResult = await _getGifts(NoParams());
    final inventoryResult = await _getInventory(NoParams());

    if (!mounted) return;

    GiftInventoryEntity? inventory;
    inventoryResult.fold((_) {}, (value) => inventory = value);

    giftsResult.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (gifts) => setState(() {
        _catalog = gifts;
        _inventory = inventory;
        _loading = false;
      }),
    );
  }

  Future<void> _buyGift(GiftEntity gift) async {
    final l10n = AppLocalizations.of(context)!;
    final balance = _inventory?.balanceCoins ?? 0;
    if (balance < gift.priceCoins) {
      await PopupDialogs.showConfirmDialog(
        context,
        title: l10n.coinsInsufficientBalance,
        message: '',
        confirmLabel: l10n.coinsTabBuy,
        cancelLabel: l10n.cancel,
        onConfirm: () => widget.onTopUpRequested?.call(),
      );
      return;
    }

    setState(() => _busy = true);
    final result = await _purchaseGift(
      PurchaseGiftParams(giftId: gift.id, quantity: 1),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    result.fold((f) => PopupDialogs.showErrorDialog(context, f.message), (
      inventory,
    ) {
      final update = inventory is GiftInventoryModel
          ? inventory
          : GiftInventoryModel(
              balanceCoins: inventory.balanceCoins,
              items: inventory.items,
            );
      setState(() {
        _inventory = GiftInventoryModel.merge(_inventory, update);
      });
      widget.onBalanceChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.coinsMarketSuccess)));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CustomLoadingWidget(size: 48));
    }

    if (_error != null && _catalog.isEmpty) {
      return Center(child: Text(_error!));
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSizes.p16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _catalog.length,
            itemBuilder: (context, index) {
              final gift = _catalog[index];
              return _MarketGiftTile(
                gift: gift,
                onBuy: _busy ? null : () => _buyGift(gift),
              );
            },
          ),
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CustomLoadingWidget(size: 48)),
            ),
          ),
      ],
    );
  }
}

class _MarketGiftTile extends StatelessWidget {
  const _MarketGiftTile({required this.gift, this.onBuy});

  final GiftEntity gift;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onBuy,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(child: _GiftVisual(gift: gift)),
              const SizedBox(height: 6),
              Text(
                gift.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Text(
                '${gift.priceCoinsLabel(locale)} ${l10n.coinsUnit}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoinsInventoryTab extends StatefulWidget {
  const CoinsInventoryTab({required this.onBalanceChanged, super.key});

  final VoidCallback onBalanceChanged;

  @override
  State<CoinsInventoryTab> createState() => _CoinsInventoryTabState();
}

class _CoinsInventoryTabState extends State<CoinsInventoryTab> {
  final _getInventory = gifts_di.sl<GetGiftInventoryUseCase>();

  GiftInventoryEntity? _inventory;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _getInventory(NoParams());
    if (!mounted) return;

    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (inventory) => setState(() {
        _inventory = inventory;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Center(child: CustomLoadingWidget(size: 48));
    }

    final items = _inventory?.items.where((i) => i.quantity > 0).toList() ?? [];

    if (_error != null && items.isEmpty) {
      return Center(child: Text(_error!));
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.4,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.coinsVaultEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.p16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final gift = item.gift;
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
            tileColor: Theme.of(context).cardColor,
            leading: SizedBox(
              width: 48,
              height: AppSizes.buttonHeightSm,
              child: gift != null
                  ? _GiftVisual(gift: gift)
                  : const Icon(LucideIcons.gift),
            ),
            title: Text(gift?.name ?? item.giftId),
            subtitle: Text(l10n.coinsVaultOwned),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '×${item.quantity}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GiftVisual extends StatelessWidget {
  const _GiftVisual({required this.gift});

  final GiftEntity gift;

  @override
  Widget build(BuildContext context) {
    if (gift.hasNetworkIcon) {
      final url = gift.imageUrl ?? gift.icon;
      return SafeNetworkImage(
        imageUrl: MediaUtils.resolveAbsoluteUrl(url),
        fit: BoxFit.contain,
      );
    }

    return Center(child: Text(gift.icon, style: const TextStyle(fontSize: 32)));
  }
}
