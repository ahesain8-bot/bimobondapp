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
  const _LiveProductSheetBody({
    required this.liveId,
    required this.isHost,
  });

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
        final liveId = payload['liveId']?.toString() ??
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
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (_) => _load(),
    );
  }

  Future<void> _removeProduct(LiveProductPinEntity pin) async {
    final result = await _removeLiveProduct(
      liveId: widget.liveId,
      productId: pin.productId,
    );
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
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

    final catalog =
        catalogResult.fold((_) => <ProductEntity>[], (p) => p.items);
    final existingIds = _items.map((e) => e.productId).toSet();
    final available =
        catalog.where((p) => !existingIds.contains(p.id)).toList();

    if (available.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shopLiveNoProductsToAdd)),
      );
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<ProductEntity>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text(l10n.shopLiveAddProduct, style: TextStyle(color: theme.onSurface)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (_, index) {
              final product = available[index];
              return ListTile(
                title: Text(product.title, style: TextStyle(color: theme.onSurface)),
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
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
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
                child: Text(l10n.shopRetry, style: TextStyle(color: theme.primary)),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          widget.isHost
              ? l10n.shopLiveEmptyHost
              : l10n.shopLiveEmptyViewer,
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
                        ProductPrice(
                          priceCoins: product.priceCoins,
                          compareAtCoins: product.compareAtCoins,
                        ),
                      ],
                    ),
                  ),
                  if (widget.isHost) ...[
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
