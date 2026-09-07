import 'dart:async';

import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/shop/domain/entities/live_product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/domain/repositories/shop_repository.dart';
import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart'
    as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/product_details_screen.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_price.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Live shopping gallery — products pinned to the current live room.
class LiveProductSheet {
  LiveProductSheet._();

  static Future<void> show(
    BuildContext context, {
    required String liveId,
    bool isHost = false,
  }) {
    return GlassBottomSheet.open<void>(
      context,
      isScrollControlled: true,
      builder: (_) => _LiveProductSheetBody(liveId: liveId, isHost: isHost),
    );
  }
}

class _LiveProductSheetBody extends StatefulWidget {
  const _LiveProductSheetBody({required this.liveId, required this.isHost});

  final String liveId;
  final bool isHost;

  @override
  State<_LiveProductSheetBody> createState() => _LiveProductSheetBodyState();
}

class _LiveProductSheetBodyState extends State<_LiveProductSheetBody> {
  final _getLiveProducts = shop_di.sl<GetLiveProductsUseCase>();
  final _addLiveProduct = shop_di.sl<AddLiveProductUseCase>();
  final _pinLiveProduct = shop_di.sl<PinLiveProductUseCase>();
  final _removeLiveProduct = shop_di.sl<RemoveLiveProductUseCase>();
  final _setLiveProductDeal = shop_di.sl<SetLiveProductDealUseCase>();
  final _browseProducts = shop_di.sl<BrowseProductsUseCase>();

  List<LiveProductPinEntity> _items = const [];
  bool _loading = true;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _liveProductSub;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeLiveProductSocket();
  }

  void _subscribeLiveProductSocket() {
    try {
      final socket = auctions_di.sl<AuctionSocketService>();
      _liveProductSub = socket.onLiveProduct.listen((payload) {
        final liveId =
            payload['liveId']?.toString() ??
            payload['roomId']?.toString() ??
            '';
        if (liveId.isNotEmpty && liveId != widget.liveId) return;
        if (!mounted) return;
        _load();
      });
    } catch (_) {
      // Socket DI optional if auctions not initialized.
    }
  }

  @override
  void dispose() {
    _liveProductSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _getLiveProducts(widget.liveId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (items) => setState(() {
        _items = items;
        _loading = false;
      }),
    );
  }

  void _openProduct(LiveProductPinEntity pin) {
    Navigator.of(context).pop();
    context.pushNamed(
      ProductDetailsScreen.routeName,
      pathParameters: {'productId': pin.productId},
      queryParameters: {'liveId': widget.liveId},
    );
  }

  Future<void> _togglePin(LiveProductPinEntity pin) async {
    final result = await _pinLiveProduct(
      liveId: widget.liveId,
      productId: pin.productId,
      isPinned: !pin.isPinned,
    );
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => _load(),
    );
  }

  /// Host flash price + coupon for one bag item. The server owns the resulting
  /// price: this only sends what the host typed and reloads the bag.
  Future<void> _editDeal(LiveProductPinEntity pin) async {
    final l10n = AppLocalizations.of(context)!;
    final request = await showModalBottomSheet<_LiveDealRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LiveDealSheet(pin: pin),
    );
    if (request == null || !mounted) return;
    final result = await _setLiveProductDeal(
      liveId: widget.liveId,
      productId: pin.productId,
      flashPriceCoins: request.flashPriceCoins,
      flashEndsAt: request.flashEndsAt,
      couponCode: request.couponCode,
      couponOffCoins: request.couponOffCoins,
      clearFlash: request.clearFlash,
      clearCoupon: request.clearCoupon,
    );
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.shopLiveDealSaved)));
        // The socket also pushes `liveProduct` action `deal`; reloading here
        // keeps the host's own sheet correct even if that push is missed.
        _load();
      },
    );
  }

  Future<void> _removeProduct(LiveProductPinEntity pin) async {
    final result = await _removeLiveProduct(
      liveId: widget.liveId,
      productId: pin.productId,
    );
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => _load(),
    );
  }

  Future<void> _showAddProductDialog() async {
    final theme = ShopTheme.forBrightness(
      Theme.of(context).brightness,
      Theme.of(context).colorScheme,
    );
    final catalogResult = await _browseProducts(
      const BrowseProductsParams(page: 1, limit: 50),
    );
    if (!mounted) return;

    final catalog = catalogResult.fold(
      (_) => <ProductEntity>[],
      (p) => p.items,
    );
    final existingIds = _items.map((e) => e.productId).toSet();
    final available = catalog
        .where((p) => !existingIds.contains(p.id))
        .toList();

    if (available.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.shopLiveNoProductsToAdd)));
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<ProductEntity>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text(
          l10n.shopLiveAddProduct,
          style: TextStyle(color: theme.onSurface),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (_, index) {
              final product = available[index];
              return ListTile(
                title: Text(
                  product.title,
                  style: TextStyle(color: theme.onSurface),
                ),
                subtitle: Text(
                  l10n.shopCoinsLabel(product.priceCoins),
                  style: TextStyle(color: theme.mutedText),
                ),
                onTap: () => Navigator.pop(ctx, product),
              );
            },
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;

    final result = await _addLiveProduct(
      liveId: widget.liveId,
      productId: selected.id,
    );
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => _load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.forBrightness(
      Theme.of(context).brightness,
      Theme.of(context).colorScheme,
    );
    final l10n = AppLocalizations.of(context)!;
    final height = MediaQuery.sizeOf(context).height * 0.55;

    return ShopThemeScope(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.p16,
                AppSizes.p8,
                AppSizes.p8,
                AppSizes.p8,
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.shoppingBag, color: theme.primary, size: 22),
                  const SizedBox(width: AppSizes.p10),
                  Expanded(
                    child: Text(
                      l10n.shopTitle,
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(LucideIcons.x, color: theme.mutedText),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(theme, l10n)),
            if (widget.isHost)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.p16,
                  AppSizes.p8,
                  AppSizes.p16,
                  AppSizes.p16 + MediaQuery.paddingOf(context).bottom,
                ),
                child: FilledButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: Text(l10n.shopLiveAddProduct),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: theme.onAccent,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ShopTheme theme, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.mutedText),
              ),
              const SizedBox(height: AppSizes.p12),
              TextButton(
                onPressed: _load,
                child: Text(
                  l10n.shopRetry,
                  style: TextStyle(color: theme.primary),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          widget.isHost ? l10n.shopLiveEmptyHost : l10n.shopLiveEmptyViewer,
          style: TextStyle(color: theme.mutedText),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        0,
        AppSizes.p16,
        AppSizes.p24,
      ),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.p10),
      itemBuilder: (context, index) {
        final pin = _items[index];
        final product = pin.product;
        return Material(
          color: theme.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            onTap: () => _openProduct(pin),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.p10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: SafeNetworkImage(
                        imageUrl: product.displayImageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pin.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              l10n.shopPinned,
                              style: TextStyle(
                                color: theme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _LiveBagPrice(pin: pin),
                      ],
                    ),
                  ),
                  if (widget.isHost) ...[
                    IconButton(
                      tooltip: l10n.shopLiveDealTitle,
                      onPressed: () => _editDeal(pin),
                      icon: Icon(
                        LucideIcons.badgePercent,
                        color: theme.primary,
                        size: 18,
                      ),
                    ),
                    IconButton(
                      tooltip: pin.isPinned ? l10n.shopUnpin : l10n.shopPin,
                      onPressed: () => _togglePin(pin),
                      icon: Icon(
                        pin.isPinned ? LucideIcons.pinOff : LucideIcons.pin,
                        color: theme.primary,
                        size: 18,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.shopRemove,
                      onPressed: () => _removeProduct(pin),
                      icon: Icon(
                        LucideIcons.trash2,
                        color: theme.mutedText,
                        size: 18,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: AppSizes.p8),
                    FilledButton(
                      onPressed: () => _openProduct(pin),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: theme.onAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text(l10n.shopBuy),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiveBagPrice extends StatelessWidget {
  const _LiveBagPrice({required this.pin});

  final LiveProductPinEntity pin;

  @override
  Widget build(BuildContext context) {
    final bag = pin.bag;
    if (bag == null) {
      return ProductPrice(
        priceCoins: pin.product.priceCoins,
        compareAtCoins: pin.product.compareAtCoins,
      );
    }
    final theme = ShopTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductPrice(
          priceCoins: bag.livePriceCoins,
          compareAtCoins: bag.basePriceCoins > bag.livePriceCoins
              ? bag.basePriceCoins
              : null,
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 6,
          runSpacing: 3,
          children: [
            if (bag.flashActive)
              _BagChip(label: 'Flash deal', color: theme.primary),
            if (bag.hasCoupon)
              _BagChip(label: 'Coupon available', color: theme.onSurface),
            if (bag.soldCount > 0)
              _BagChip(label: '${bag.soldCount} sold', color: theme.mutedText),
          ],
        ),
      ],
    );
  }
}

class _BagChip extends StatelessWidget {
  const _BagChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
  );
}


/// What the host asked for in the deal sheet.
class _LiveDealRequest {
  const _LiveDealRequest({
    this.flashPriceCoins,
    this.flashEndsAt,
    this.couponCode,
    this.couponOffCoins,
    this.clearFlash = false,
    this.clearCoupon = false,
  });

  final int? flashPriceCoins;
  final DateTime? flashEndsAt;
  final String? couponCode;
  final int? couponOffCoins;
  final bool clearFlash;
  final bool clearCoupon;
}

/// Host editor for `PATCH …/items/:productId/deal`
/// (`lives/live-p0-parity.md` §3).
///
/// It collects a flash price with its end time and a coupon code with its
/// amount. No discount is computed here — `livePriceCoins`, `flashActive`,
/// `hasCoupon` and `dealApplied` all come back from the server.
class _LiveDealSheet extends StatefulWidget {
  const _LiveDealSheet({required this.pin});

  final LiveProductPinEntity pin;

  @override
  State<_LiveDealSheet> createState() => _LiveDealSheetState();
}

class _LiveDealSheetState extends State<_LiveDealSheet> {
  final _flashPrice = TextEditingController();
  final _flashMinutes = TextEditingController();
  final _couponCode = TextEditingController();
  final _couponOff = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _flashPrice.dispose();
    _flashMinutes.dispose();
    _couponCode.dispose();
    _couponOff.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bag = widget.pin.bag;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.shopLiveDealTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(l10n.shopLiveDealNote, style: const TextStyle(fontSize: 12)),
              TextField(
                controller: _flashPrice,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.shopLiveDealFlashPrice,
                ),
              ),
              TextField(
                controller: _flashMinutes,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.shopLiveDealFlashEnds,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _couponCode,
                maxLength: 24,
                decoration: InputDecoration(
                  labelText: l10n.shopLiveDealCouponCode,
                  counterText: '',
                ),
              ),
              TextField(
                controller: _couponOff,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.shopLiveDealCouponOff,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submit,
                child: Text(l10n.shopLiveDealSave),
              ),
              if (bag?.flashActive == true)
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(const _LiveDealRequest(clearFlash: true)),
                  child: Text(l10n.shopLiveDealClearFlash),
                ),
              if (bag?.hasCoupon == true)
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(const _LiveDealRequest(clearCoupon: true)),
                  child: Text(l10n.shopLiveDealClearCoupon),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final price = int.tryParse(_flashPrice.text.trim());
    final minutes = int.tryParse(_flashMinutes.text.trim());
    final code = _couponCode.text.trim();
    final off = int.tryParse(_couponOff.text.trim());

    // Each half of a deal needs its other half; the API rejects a lone value.
    final flashComplete = (price == null) == (minutes == null);
    final couponComplete = code.isEmpty == (off == null);
    if (!flashComplete || !couponComplete) {
      setState(() => _error = l10n.shopLiveDealNeedsBoth);
      return;
    }
    if (price == null && code.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(
      _LiveDealRequest(
        flashPriceCoins: price,
        flashEndsAt: minutes == null
            ? null
            : DateTime.now().add(Duration(minutes: minutes)),
        couponCode: code.isEmpty ? null : code,
        couponOffCoins: off,
      ),
    );
  }
}
