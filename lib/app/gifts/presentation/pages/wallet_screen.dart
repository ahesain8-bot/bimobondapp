import 'dart:async';

import 'package:bimobondapp/app/auctions/domain/entities/auction_pricing_preview_entity.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/get_auction_pricing_preview_usecase.dart';
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_inventory_usecase.dart';
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_balance_card.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_custom_amount_section.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_glow_blob.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_payment_sheet.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/wallet/wallet_top_up_button.dart';
import 'package:bimobondapp/app/wallets/domain/entities/wallet_entity.dart';
import 'package:bimobondapp/app/wallets/domain/usecases/wallet_usecases.dart';
import 'package:bimobondapp/app/wallets/domain/utils/wallet_coin_pricing.dart';
import 'package:bimobondapp/app/wallets/presentation/di/wallets_injector.dart'
    as wallets_di;
import 'package:bimobondapp/app/wallets/presentation/widgets/wallet_package_quotes_grid.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  final GetGiftInventoryUseCase _getInventory =
      gifts_di.sl<GetGiftInventoryUseCase>();
  final GetCoinPackagesUseCase _getPackages =
      wallets_di.sl<GetCoinPackagesUseCase>();
  final PurchaseCoinsUseCase _purchaseCoins =
      wallets_di.sl<PurchaseCoinsUseCase>();
  final TopUpWalletUseCase _topUpWallet = wallets_di.sl<TopUpWalletUseCase>();
  final GetAuctionPricingPreviewUseCase _getPricingPreview =
      auctions_di.sl<GetAuctionPricingPreviewUseCase>();
  final SharedPreferences _prefs = gifts_di.sl<SharedPreferences>();
  final TextEditingController _customCoinsController = TextEditingController();

  int _coinBalance = 0;
  bool _loading = true;
  String? _errorMessage;
  List<CoinPackageEntity> _packages = [];
  AuctionPricingPreviewEntity? _pricingPreview;
  Timer? _previewDebounce;
  bool _loadingPricingPreview = false;
  int _selectedPackageIndex = 0;
  int? _previewForCoins;
  late AnimationController _pulseController;

  WalletTopUpQuote get _activeQuote {
    final customCoins =
        WalletCoinPricing.parseCoinsInput(_customCoinsController.text);
    if (customCoins > 0) {
      final packageMatch =
          WalletCoinPricing.packageForCoins(customCoins, _packages);
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
    return WalletTopUpQuote.fromEntity(_packages[_selectedPackageIndex]);
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _customCoinsController.addListener(_onCustomCoinsChanged);
    _load();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _customCoinsController.removeListener(_onCustomCoinsChanged);
    _pulseController.dispose();
    _customCoinsController.dispose();
    super.dispose();
  }

  void _onCustomCoinsChanged() {
    final coins = WalletCoinPricing.parseCoinsInput(_customCoinsController.text);
    setState(() {});
    _schedulePricingPreview(coins);
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

  Future<void> _fetchPricingPreview(int coins) async {
    final result = await _getPricingPreview(
      AuctionPricingPreviewParams(targetCoins: coins),
    );
    if (!mounted) return;

    final currentCoins =
        WalletCoinPricing.parseCoinsInput(_customCoinsController.text);
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final inventoryResult = await _getInventory(NoParams());
    final packagesResult = await _getPackages(NoParams());

    if (!mounted) return;

    packagesResult.fold((_) {}, (packages) {
      _packages = packages;
      if (_selectedPackageIndex >= packages.length) {
        _selectedPackageIndex = 0;
      }
    });

    inventoryResult.fold(
      (failure) => setState(() {
        _loading = false;
        _errorMessage = failure.message;
      }),
      (inventory) => setState(() {
        _coinBalance = inventory.balanceCoins;
        _loading = false;
      }),
    );
  }

  Future<void> _topUp(WalletTopUpQuote quote) async {
    final l10n = AppLocalizations.of(context)!;
    if (!quote.isValid) {
      PopupDialogs.showErrorDialog(
        context,
        l10n.walletCustomAmountInvalid,
      );
      return;
    }

    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) =>
          WalletPaymentSheet(quote: quote, l10n: l10n),
    );

    if (success != true || !mounted) return;

    final txId = 'app-${DateTime.now().millisecondsSinceEpoch}';

    if (quote.isPackageQuote) {
      final result = await _purchaseCoins(
        PurchaseCoinsParams(
          packageId: quote.packageId!,
          provider: 'MOCK',
          providerTxId: txId,
        ),
      );
      if (!mounted) return;
      result.fold(
        (failure) => PopupDialogs.showErrorDialog(context, failure.message),
        (_) => _onTopUpSuccess(quote.coins),
      );
      return;
    }

    final result = await _topUpWallet(
      TopUpWalletParams(
        paidPrice: quote.price,
        provider: 'MOCK',
        providerTxId: txId,
        currencyCode: quote.currencyCode,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) => PopupDialogs.showErrorDialog(context, failure.message),
      (_) => _onTopUpSuccess(quote.coins),
    );
  }

  Future<void> _onTopUpSuccess(int coins) async {
    final l10n = AppLocalizations.of(context)!;
    final currentOffset = _prefs.getInt('MOCK_COIN_PURCHASED_OFFSET') ?? 0;
    await _prefs.setInt('MOCK_COIN_PURCHASED_OFFSET', currentOffset + coins);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.walletPurchaseSuccess(coins)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade600,
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quote = _activeQuote;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(title: l10n.walletTitle, showBackButton: true),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: WalletGlowBlob(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.15 : 0.08,
              ),
              size: 300,
            ),
          ),
          Positioned(
            bottom: 50,
            left: -120,
            child: WalletGlowBlob(
              color: Colors.amber.withValues(alpha: isDark ? 0.08 : 0.04),
              size: 280,
            ),
          ),
          _loading && _coinBalance == 0
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  color: theme.colorScheme.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p16,
                      vertical: AppSizes.p12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WalletBalanceCard(
                          balance: _coinBalance,
                          pulseAnimation: _pulseController,
                          errorMessage: _errorMessage,
                        ),
                        const SizedBox(height: AppSizes.p20),
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
                              _selectedPackageIndex = _packages.indexOf(pack);
                              _pricingPreview = null;
                              _previewForCoins = null;
                              _loadingPricingPreview = false;
                            });
                          },
                        ),
                        const SizedBox(height: AppSizes.p20),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, right: 4),
                          child: CustomText(
                            l10n.walletChoosePackage,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSizes.p10),
                        WalletPackageQuotesGrid(
                          packages: _packages,
                          selectedIndex: _selectedPackageIndex,
                          onPackageSelected: (index) {
                            setState(() {
                              _selectedPackageIndex = index;
                              _customCoinsController.text =
                                  '${_packages[index].coinAmount}';
                              _pricingPreview = null;
                              _previewForCoins = null;
                              _loadingPricingPreview = false;
                            });
                          },
                        ),
                        const SizedBox(height: AppSizes.p20),
                        WalletTopUpButton(
                          quote: quote,
                          enabled: quote.isValid && !_loadingPricingPreview,
                          onPressed: () => _topUp(quote),
                        ),
                        const SizedBox(height: AppSizes.p24),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
