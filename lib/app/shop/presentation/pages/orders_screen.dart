import 'dart:async';

import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_product_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/purchased_products_query.dart';
import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart' as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/order_details_screen.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/shop_back_button.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_price.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    this.initialTabIndex = 0,
    this.purchasesOnly = false,
    super.key,
  });

  static const routeName = 'shop_orders';

  /// 0 = purchases, 1 = sales. Ignored when [purchasesOnly] is true.
  final int initialTabIndex;

  /// Settings → My Products: purchases-only gift-style grid, no Sales tab.
  final bool purchasesOnly;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    if (!widget.purchasesOnly) {
      final initialIndex = widget.initialTabIndex.clamp(0, 1);
      _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: initialIndex,
      );
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final purchasesOnly = widget.purchasesOnly;

    return ShopThemeScope(
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: const ShopBackButton(),
          iconTheme: IconThemeData(color: theme.onSurface),
          title: Text(
            purchasesOnly ? l10n.settingsMyProducts : l10n.shopOrders,
            style: TextStyle(
              color: theme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: purchasesOnly
              ? null
              : TabBar(
                  controller: _tabController,
                  indicatorColor: theme.primary,
                  labelColor: theme.onSurface,
                  unselectedLabelColor: theme.mutedText,
                  tabs: [
                    Tab(text: l10n.shopPurchases),
                    Tab(text: l10n.shopSales),
                  ],
                ),
        ),
        body: purchasesOnly
            ? const _MyProductsTab()
            : TabBarView(
                controller: _tabController,
                children: const [
                  _OrdersTab(mode: _OrdersMode.purchases),
                  _OrdersTab(mode: _OrdersMode.sales),
                ],
              ),
      ),
    );
  }
}

enum _OrdersMode { purchases, sales }

/// Settings → My Products — loads `GET /products/purchased`.
class _MyProductsTab extends StatefulWidget {
  const _MyProductsTab();

  @override
  State<_MyProductsTab> createState() => _MyProductsTabState();
}

class _MyProductsTabState extends State<_MyProductsTab> {
  final GetPurchasedProductsUseCase _getPurchased = shop_di.sl();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  Timer? _searchDebounce;

  PurchasedProductsQueryParams _query = const PurchasedProductsQueryParams();
  List<PurchasedProductEntity> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _hasMore = false;

  bool get _hasActiveFilters =>
      (_query.search?.trim().isNotEmpty ?? false) ||
      _query.minPriceCoins != null ||
      _query.maxPriceCoins != null ||
      _query.productCategoryId != null ||
      _query.sellerId != null;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
        _query = _query.copyWith(page: 1);
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() {
        _loadingMore = true;
        _query = _query.copyWith(page: _query.page + 1);
      });
    }

    final result = await _getPurchased(_query);
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        _loadingMore = false;
        _error = ErrorMessageResolver.resolve(failure);
      }),
      (data) => setState(() {
        _loading = false;
        _loadingMore = false;
        _query = _query.copyWith(page: data.page);
        _hasMore = data.hasMore;
        _items = refresh ? data.items : [..._items, ...data.items];
      }),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final next = value.trim();
      setState(() {
        _query = next.isEmpty
            ? _query.copyWith(clearSearch: true, page: 1)
            : _query.copyWith(search: next, page: 1);
      });
      _load(refresh: true);
    });
  }

  void _clearFilters() {
    _searchController.clear();
    _minPriceController.clear();
    _maxPriceController.clear();
    setState(() {
      _query = const PurchasedProductsQueryParams(
        sortBy: 'lastPurchasedAt',
        sortOrder: 'desc',
      );
    });
    _load(refresh: true);
  }

  Future<void> _openFiltersSheet() async {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    _minPriceController.text =
        _query.minPriceCoins?.toString() ?? '';
    _maxPriceController.text =
        _query.maxPriceCoins?.toString() ?? '';

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSizes.p16,
            right: AppSizes.p16,
            top: AppSizes.p16,
            bottom: MediaQuery.paddingOf(ctx).bottom + AppSizes.p16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.shopFilters,
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.p16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.shopMinPriceCoins,
                        filled: true,
                        fillColor: theme.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.shopMaxPriceCoins,
                        filled: true,
                        fillColor: theme.surface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.shopClearFilters),
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: theme.onAccent,
                      ),
                      child: Text(l10n.shopApplyFilters),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (applied == false) {
      _minPriceController.clear();
      _maxPriceController.clear();
      setState(() {
        _query = _query.copyWith(
          page: 1,
          clearMediaType: true,
          clearMinPriceCoins: true,
          clearMaxPriceCoins: true,
        );
      });
      _load(refresh: true);
      return;
    }
    if (applied != true) return;

    final minRaw = _minPriceController.text.trim();
    final maxRaw = _maxPriceController.text.trim();
    final min = minRaw.isEmpty ? null : int.tryParse(minRaw);
    final max = maxRaw.isEmpty ? null : int.tryParse(maxRaw);

    setState(() {
      _query = _query.copyWith(
        page: 1,
        clearMediaType: true,
        minPriceCoins: min,
        clearMinPriceCoins: min == null,
        maxPriceCoins: max,
        clearMaxPriceCoins: max == null,
      );
    });
    _load(refresh: true);
  }

  void _openItem(PurchasedProductEntity item) {
    // Purchased catalog rows can outlive public product listings — avoid
    // GET /products/:id (often 404). Show inventory details from list data.
    unawaited(_showPurchasedProductSheet(item));
  }

  Future<void> _showPurchasedProductSheet(PurchasedProductEntity item) async {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final orderId = item.orderId?.trim();
    final hasOrder = orderId != null && orderId.isNotEmpty;
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    String? fulfillmentLabel;
    final status = item.fulfillmentStatus;
    if (status != null && status != ProductFulfillmentStatus.unknown) {
      fulfillmentLabel = switch (status) {
        ProductFulfillmentStatus.none => l10n.shopFulfillmentNone,
        ProductFulfillmentStatus.awaitingShipment =>
          l10n.shopFulfillmentAwaitingShipment,
        ProductFulfillmentStatus.shipped => l10n.shopFulfillmentShipped,
        ProductFulfillmentStatus.delivered => l10n.shopFulfillmentDelivered,
        ProductFulfillmentStatus.accepted => l10n.shopFulfillmentAccepted,
        ProductFulfillmentStatus.disputed => l10n.shopFulfillmentDisputed,
        ProductFulfillmentStatus.unknown => null,
      };
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: hasImage
                            ? SafeNetworkImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
                                width: 88,
                                height: 88,
                                borderRadius: BorderRadius.zero,
                              )
                            : ColoredBox(
                                color: theme.surface,
                                child: Icon(
                                  LucideIcons.shoppingBag,
                                  color: theme.mutedText,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppCoinAmount(
                            iconSize: 14,
                            spacing: 4,
                            text: '${item.priceCoins}',
                            style: TextStyle(
                              color: theme.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.shopQty(item.quantity),
                            style: TextStyle(
                              color: theme.mutedText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (fulfillmentLabel != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              fulfillmentLabel,
                              style: TextStyle(
                                color: theme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.settingsComingSoon)),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: theme.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    l10n.shopMakeAuction,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (hasOrder) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.pushNamed(
                        OrderDetailsScreen.routeName,
                        pathParameters: {'orderId': orderId},
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: theme.border),
                    ),
                    child: Text(l10n.shopOrders),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // One full-page skeleton for the first load (search + grid).
    if (_loading && _items.isEmpty) {
      return const _MyProductsGiftSkeleton();
    }

    final searchRadius = BorderRadius.circular(theme.searchRadius);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.p16,
            AppSizes.p8,
            AppSizes.p16,
            AppSizes.p8,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    _searchDebounce?.cancel();
                    _onSearchChanged(_searchController.text);
                  },
                  style: TextStyle(color: theme.onSurface, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: l10n.shopMyProductsSearchHint,
                    hintStyle: TextStyle(color: theme.mutedText, fontSize: 14),
                    prefixIcon: Icon(
                      LucideIcons.search,
                      color: theme.mutedText,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            icon: Icon(
                              LucideIcons.x,
                              color: theme.mutedText,
                              size: 18,
                            ),
                          ),
                    filled: true,
                    fillColor: theme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p12,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: searchRadius,
                      borderSide: BorderSide(color: theme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: searchRadius,
                      borderSide: BorderSide(color: theme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: searchRadius,
                      borderSide: BorderSide(color: theme.primary, width: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p8),
              _HeaderIconButton(
                tooltip: l10n.shopFilters,
                icon: LucideIcons.slidersHorizontal,
                active: _query.minPriceCoins != null ||
                    _query.maxPriceCoins != null,
                onTap: _openFiltersSheet,
              ),
            ],
          ),
        ),
        Expanded(child: _buildContent(theme, l10n)),
      ],
    );
  }

  Widget _buildContent(ShopTheme theme, AppLocalizations l10n) {
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.p16),
            FilledButton(
              onPressed: () => _load(refresh: true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: theme.onAccent,
              ),
              child: Text(l10n.shopRetry),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _hasActiveFilters ? LucideIcons.searchX : LucideIcons.package,
              size: 48,
              color: theme.mutedText,
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              _hasActiveFilters
                  ? l10n.shopNoMatchingProducts
                  : l10n.shopNoPurchasesYet,
              style: TextStyle(
                color: theme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: AppSizes.p12),
              TextButton(
                onPressed: _clearFilters,
                child: Text(l10n.shopClearFilters),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: () => _load(refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 240) {
            _load();
          }
          return false;
        },
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 6,
            childAspectRatio: 0.68,
          ),
          itemCount: _items.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.primary,
                  ),
                ),
              );
            }
            final item = _items[index];
            return _GiftStylePurchasedTile(
              item: item,
              onTap: () => _openItem(item),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 20,
        color: active ? theme.primary : theme.onSurface,
      ),
    );
  }
}

class _OrdersTab extends StatefulWidget {
  const _OrdersTab({required this.mode});

  final _OrdersMode mode;

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab>
    with AutomaticKeepAliveClientMixin {
  final GetMyOrdersUseCase _getMyOrders = shop_di.sl();
  final GetSalesOrdersUseCase _getSalesOrders = shop_di.sl();

  List<ProductOrderEntity> _orders = const [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    final page = refresh ? 1 : _page + 1;
    final result = widget.mode == _OrdersMode.purchases
        ? await _getMyOrders(page: page, limit: 20)
        : await _getSalesOrders(page: page, limit: 20);

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        _loadingMore = false;
        _error = ErrorMessageResolver.resolve(failure);
      }),
      (data) => setState(() {
        _loading = false;
        _loadingMore = false;
        _page = data.page;
        _hasMore = data.hasMore;
        _orders = refresh ? data.items : [..._orders, ...data.items];
      }),
    );
  }

  String _statusLabel(ProductOrderStatus status, AppLocalizations l10n) {
    return switch (status) {
      ProductOrderStatus.pending => l10n.shopStatusPending,
      ProductOrderStatus.paid => l10n.shopStatusPaid,
      ProductOrderStatus.cancelled => l10n.shopStatusCancelled,
      ProductOrderStatus.refunded => l10n.shopStatusRefunded,
      ProductOrderStatus.unknown => l10n.shopStatusUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (_loading && _orders.isEmpty) {
      return const OrdersSkeleton();
    }

    if (_error != null && _orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.p16),
            FilledButton(
              onPressed: () => _load(refresh: true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: theme.onAccent,
              ),
              child: Text(l10n.shopRetry),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.package,
                    size: 48,
                    color: theme.mutedText,
                  ),
                  const SizedBox(height: AppSizes.p16),
                  Text(
              widget.mode == _OrdersMode.purchases
                  ? l10n.shopNoPurchasesYet
                  : l10n.shopNoSalesYet,
                    style: TextStyle(
                      color: theme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: () => _load(refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 240) {
            _load();
          }
          return false;
        },
        child: ListView.separated(
            padding: const EdgeInsets.all(AppSizes.p16),
          itemCount: _orders.length + (_loadingMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.p12),
            itemBuilder: (context, index) {
            if (index >= _orders.length) {
              return const Padding(
                padding: EdgeInsets.all(AppSizes.p16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final order = _orders[index];
              return _OrderTile(
                order: order,
              statusLabel: _statusLabel(order.status, l10n),
                onTap: () => context.pushNamed(
                  OrderDetailsScreen.routeName,
                  pathParameters: {'orderId': order.id},
                ),
              );
            },
        ),
      ),
    );
  }
}

/// Gift-style tile for `GET /products/purchased` rows.
class _GiftStylePurchasedTile extends StatelessWidget {
  const _GiftStylePurchasedTile({
    required this.item,
    required this.onTap,
  });

  final PurchasedProductEntity item;
  final VoidCallback onTap;

  IconData get _statusIcon => switch (item.fulfillmentStatus) {
        ProductFulfillmentStatus.awaitingShipment => LucideIcons.package,
        ProductFulfillmentStatus.shipped => LucideIcons.truck,
        ProductFulfillmentStatus.delivered => LucideIcons.packageCheck,
        ProductFulfillmentStatus.accepted => LucideIcons.circleCheck,
        ProductFulfillmentStatus.disputed => LucideIcons.triangleAlert,
        ProductFulfillmentStatus.none ||
        ProductFulfillmentStatus.unknown ||
        null =>
          LucideIcons.shoppingBag,
      };

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final qty = item.quantity;
    final radius = BorderRadius.circular(10);
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: radius,
                  border: Border.all(
                    color: theme.border.withValues(alpha: 0.85),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasImage)
                        SafeNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: BorderRadius.zero,
                        )
                      else
                        ColoredBox(
                          color: theme.surface,
                          child: Icon(
                            LucideIcons.shoppingBag,
                            size: 22,
                            color: theme.mutedText,
                          ),
                        ),
                      if (item.fulfillmentStatus != null &&
                          item.fulfillmentStatus !=
                              ProductFulfillmentStatus.unknown)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: theme.background.withValues(alpha: 0.88),
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.border),
                            ),
                            child: Icon(
                              _statusIcon,
                              size: 10,
                              color: theme.primary,
                            ),
                          ),
                        ),
                      if (qty > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'x$qty',
                              style: TextStyle(
                                color: theme.onAccent,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            AppCoinAmount(
              iconSize: 10,
              spacing: 2,
              text: '${item.priceCoins}',
              style: TextStyle(
                color: theme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyProductsGiftSkeleton extends StatelessWidget {
  const _MyProductsGiftSkeleton();

  static const _crossAxisCount = 4;
  static const _mainAxisSpacing = 8.0;
  static const _crossAxisSpacing = 6.0;
  static const _childAspectRatio = 0.68;
  static const _gridHPad = 16.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridTop = AppSizes.p8 + 48 + AppSizes.p8 + 4;
        final availableH =
            (constraints.maxHeight - gridTop - 28).clamp(120.0, 4000.0);
        final cellW = (constraints.maxWidth -
                _gridHPad * 2 -
                _crossAxisSpacing * (_crossAxisCount - 1)) /
            _crossAxisCount;
        final cellH = cellW / _childAspectRatio;
        final rows =
            ((availableH + _mainAxisSpacing) / (cellH + _mainAxisSpacing))
                .ceil()
                .clamp(4, 12);
        final itemCount = rows * _crossAxisCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.p16,
                AppSizes.p8,
                AppSizes.p16,
                AppSizes.p8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ShopSkeletonBox(
                      height: 48,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                  SizedBox(width: AppSizes.p8),
                  ShopSkeletonBox(
                    width: 44,
                    height: 44,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _crossAxisCount,
                  mainAxisSpacing: _mainAxisSpacing,
                  crossAxisSpacing: _crossAxisSpacing,
                  childAspectRatio: _childAspectRatio,
                ),
                itemCount: itemCount,
                itemBuilder: (_, _) {
                  return const Column(
                    children: [
                      Expanded(
                        child: ShopSkeletonBox(
                          borderRadius:
                              BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                      SizedBox(height: 5),
                      ShopSkeletonBox(height: 10, width: 52),
                      SizedBox(height: 2),
                      ShopSkeletonBox(height: 10, width: 32),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.statusLabel,
    required this.onTap,
  });

  final ProductOrderEntity order;
  final String statusLabel;
  final VoidCallback onTap;

  OrderItemEntity? get _primaryItem =>
      order.items.isEmpty ? null : order.items.first;

  String _title(AppLocalizations l10n) {
    final item = _primaryItem;
    if (item == null) return '#${order.orderNumber}';
    if (order.items.length <= 1) return item.title;
    return '${item.title} · ${l10n.shopItemsCount(order.items.length)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final item = _primaryItem;
    final radius = BorderRadius.circular(AppSizes.radiusMd);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(AppSizes.p12),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: radius,
            border: Border.all(color: theme.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: item?.imageUrl != null && item!.imageUrl!.isNotEmpty
                      ? SafeNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.zero,
                        )
                      : ColoredBox(
                          color: theme.surface,
                          child: Icon(
                            LucideIcons.package,
                            size: 28,
                            color: theme.mutedText,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSizes.p12),
              Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                    Text(
                      _title(l10n),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: AppSizes.p6),
                    ProductPrice(
                      priceCoins: order.totalCoins,
                      showCompareAt: false,
                      fontSize: 14,
                      iconSize: 14,
                    ),
                    const SizedBox(height: AppSizes.p8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p8,
                      vertical: AppSizes.p4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.surface,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm),
                          border: Border.all(color: theme.border),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: theme.accentCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
