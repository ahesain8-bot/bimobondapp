import 'package:bimobondapp/app/marketplace/presentation/pages/create_auction_screen.dart';
import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_badges.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/price_display.dart';
import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_products_query.dart';
import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart' as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/order_details_screen.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/shop_back_button.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum MyProductsTab {
  purchased,
  pendingDelivery,
  delivered,
  auctioned,
  sold,
}

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  static const routeName = 'marketplace_my_products';

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GetPurchasedProductsUseCase _getPurchased = shop_di.sl();

  List<PurchasedProductEntity> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: MyProductsTab.values.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _getPurchased(
      const PurchasedProductsQueryParams(limit: 100),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = ErrorMessageResolver.resolve(f);
      }),
      (page) => setState(() {
        _loading = false;
        _items = page.items;
      }),
    );
  }

  List<PurchasedProductEntity> _filtered(MyProductsTab tab) {
    return _items.where((item) {
      final status = item.fulfillmentStatus;
      return switch (tab) {
        MyProductsTab.purchased => true,
        MyProductsTab.pendingDelivery =>
          status == ProductFulfillmentStatus.awaitingShipment ||
              status == ProductFulfillmentStatus.none,
        MyProductsTab.delivered =>
          status == ProductFulfillmentStatus.delivered ||
              status == ProductFulfillmentStatus.accepted,
        MyProductsTab.auctioned => false,
        MyProductsTab.sold => false,
      };
    }).toList();
  }

  String _deliveryLabel(PurchasedProductEntity item, AppLocalizations l10n) {
    return switch (item.fulfillmentStatus) {
      ProductFulfillmentStatus.awaitingShipment ||
      ProductFulfillmentStatus.none =>
        l10n.marketplaceDeliveryPending,
      ProductFulfillmentStatus.shipped => l10n.marketplaceDeliveryShipped,
      ProductFulfillmentStatus.delivered ||
      ProductFulfillmentStatus.accepted =>
        l10n.marketplaceDeliveryDelivered,
      _ => l10n.marketplaceDeliveryPending,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return MarketplaceThemeScope(
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: const ShopBackButton(),
          title: Text(
            l10n.settingsMyProducts,
            style: TextStyle(
              color: theme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: theme.primary,
            labelColor: theme.onSurface,
            unselectedLabelColor: theme.mutedText,
            tabs: [
              Tab(text: l10n.marketplaceTabPurchased),
              Tab(text: l10n.marketplaceTabPending),
              Tab(text: l10n.marketplaceTabDelivered),
              Tab(text: l10n.marketplaceTabAuctioned),
              Tab(text: l10n.marketplaceTabSold),
            ],
          ),
        ),
        body: _loading
            ? const ProductSkeletonGrid()
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!),
                        FilledButton(
                          onPressed: _load,
                          child: Text(l10n.shopRetry),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: MyProductsTab.values.map((tab) {
                      final items = _filtered(tab);
                      if (items.isEmpty) {
                        return Center(child: Text(l10n.marketplaceNoProducts));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _OwnedProductCard(
                            item: item,
                            deliveryLabel: _deliveryLabel(item, l10n),
                            onTrack: item.orderId == null
                                ? null
                                : () => context.pushNamed(
                                      OrderDetailsScreen.routeName,
                                      pathParameters: {
                                        'orderId': item.orderId!,
                                      },
                                    ),
                            onSellAtAuction: () => context.pushNamed(
                              CreateAuctionScreen.routeName,
                              queryParameters: {
                                'productId': item.productId,
                                'title': item.title,
                                'priceCoins': '${item.priceCoins}',
                                if (item.imageUrl != null)
                                  'imageUrl': item.imageUrl!,
                              },
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
      ),
    );
  }
}

class _OwnedProductCard extends StatelessWidget {
  const _OwnedProductCard({
    required this.item,
    required this.deliveryLabel,
    this.onTrack,
    this.onSellAtAuction,
  });

  final PurchasedProductEntity item;
  final String deliveryLabel;
  final VoidCallback? onTrack;
  final VoidCallback? onSellAtAuction;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: theme.cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: SafeNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: theme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      PriceDisplay(
                        priceCoins: item.priceCoins,
                        size: PriceDisplaySize.small,
                      ),
                      const SizedBox(height: 6),
                      const OwnershipBadge(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.marketplacePurchaseConfirmed,
              style: TextStyle(color: theme.success, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${l10n.marketplaceDeliveryLabel}: ',
                  style: TextStyle(color: theme.mutedText),
                ),
                DeliveryStatusChip(status: deliveryLabel),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (onTrack != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onTrack,
                      child: Text(l10n.marketplaceTrackDelivery),
                    ),
                  ),
                if (onTrack != null) const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onSellAtAuction,
                    child: Text(l10n.marketplaceSellAtAuction),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
