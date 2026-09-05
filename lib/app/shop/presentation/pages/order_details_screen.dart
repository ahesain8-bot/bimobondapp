import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart' as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/orders_screen.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_price.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/shop_back_button.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/app_form_dialog.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({
    required this.orderId,
    this.showGoToMyProducts = false,
    super.key,
  });

  static const routeName = 'shop_order';

  final String orderId;

  /// Shown after a successful checkout purchase.
  final bool showGoToMyProducts;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final GetOrderUseCase _getOrder = shop_di.sl();
  final ShipOrderUseCase _shipOrderUseCase = shop_di.sl();
  final ReceiveOrderUseCase _receiveOrderUseCase = shop_di.sl();
  final AcceptOrderUseCase _acceptOrderUseCase = shop_di.sl();
  final DisputeOrderUseCase _disputeOrderUseCase = shop_di.sl();

  ProductOrderEntity? _order;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _getOrder(widget.orderId);
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = ErrorMessageResolver.resolve(failure);
      }),
      (order) => setState(() {
        _loading = false;
        _order = order;
      }),
    );
  }

  Future<void> _runAction(Future<dynamic> Function() action) async {
    setState(() => _actionLoading = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _actionLoading = false);
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessageResolver.resolve(failure))),
        );
      },
      (_) => _loadOrder(),
    );
  }

  Future<void> _shipOrder() async {
    final trackingController = TextEditingController();
    final noteController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppFormDialog(
        title: l10n.shopShipOrder,
        primaryLabel: l10n.shopShip,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: l10n.shopCancel,
        onSecondary: () => Navigator.pop(ctx, false),
        children: [
          AppFormField(
            controller: trackingController,
            label: l10n.shopTrackingNumber,
          ),
          AppFormField(
            controller: noteController,
            label: l10n.shopShippingNote,
            bottomGap: 0,
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _runAction(
      () => _shipOrderUseCase(
        orderId: widget.orderId,
        trackingNumber: trackingController.text.trim().isEmpty
            ? null
            : trackingController.text.trim(),
        shippingNote: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      ),
    );
  }

  Future<void> _receiveOrder() => _runAction(
        () => _receiveOrderUseCase(widget.orderId),
      );

  Future<void> _acceptOrder() => _runAction(
        () => _acceptOrderUseCase(widget.orderId),
      );

  Future<void> _disputeOrder() async {
    final noteController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppFormDialog(
        title: l10n.shopDisputeOrder,
        primaryLabel: l10n.shopDispute,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: l10n.shopCancel,
        onSecondary: () => Navigator.pop(ctx, false),
        children: [
          AppFormField(
            controller: noteController,
            label: l10n.shopNoteOptional,
            maxLines: 3,
            bottomGap: 0,
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _runAction(
      () => _disputeOrderUseCase(
        orderId: widget.orderId,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      ),
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

  String _fulfillmentLabel(
    ProductFulfillmentStatus status,
    AppLocalizations l10n,
  ) {
    return switch (status) {
      ProductFulfillmentStatus.none => l10n.shopFulfillmentNone,
      ProductFulfillmentStatus.awaitingShipment =>
        l10n.shopFulfillmentAwaitingShipment,
      ProductFulfillmentStatus.shipped => l10n.shopFulfillmentShipped,
      ProductFulfillmentStatus.delivered => l10n.shopFulfillmentDelivered,
      ProductFulfillmentStatus.accepted => l10n.shopFulfillmentAccepted,
      ProductFulfillmentStatus.disputed => l10n.shopFulfillmentDisputed,
      ProductFulfillmentStatus.unknown => l10n.shopStatusUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
            l10n.shopOrders,
            style: TextStyle(
              color: theme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: _loading
            ? const OrdersSkeleton()
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: AppSizes.p16),
                        FilledButton(
                          onPressed: _loadOrder,
                          child: Text(l10n.shopRetry),
                        ),
                      ],
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final authState = context.watch<AuthBloc>().state;
                      final currentUserId = authState is AuthSuccess
                          ? authState.user.id
                          : FirebaseAuth.instance.currentUser?.uid;
                      final order = _order!;
                      final isBuyer = currentUserId != null &&
                          currentUserId == order.buyerId;
                      final isSeller = currentUserId != null &&
                          currentUserId == order.sellerId;

                      return _OrderBody(
                        order: order,
                        statusLabel: _statusLabel(order.status, l10n),
                        fulfillmentLabel:
                            _fulfillmentLabel(order.fulfillmentStatus, l10n),
                        actionLoading: _actionLoading,
                        isBuyer: isBuyer,
                        isSeller: isSeller,
                        showGoToMyProducts: widget.showGoToMyProducts && isBuyer,
                        l10n: l10n,
                        onShip: _shipOrder,
                        onReceive: _receiveOrder,
                        onAccept: _acceptOrder,
                        onDispute: _disputeOrder,
                      );
                    },
                  ),
      ),
    );
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody({
    required this.order,
    required this.statusLabel,
    required this.fulfillmentLabel,
    required this.actionLoading,
    required this.isBuyer,
    required this.isSeller,
    required this.showGoToMyProducts,
    required this.l10n,
    required this.onShip,
    required this.onReceive,
    required this.onAccept,
    required this.onDispute,
  });

  final ProductOrderEntity order;
  final String statusLabel;
  final String fulfillmentLabel;
  final bool actionLoading;
  final bool isBuyer;
  final bool isSeller;
  final bool showGoToMyProducts;
  final AppLocalizations l10n;
  final VoidCallback onShip;
  final VoidCallback onReceive;
  final VoidCallback onAccept;
  final VoidCallback onDispute;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final address = order.shippingAddress;
    final status = order.fulfillmentStatus;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.p16),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.orderNumber}',
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSizes.p8),
                _InfoRow(label: l10n.shopStatus, value: statusLabel),
                _InfoRow(label: l10n.shopFulfillment, value: fulfillmentLabel),
                if (order.trackingNumber != null)
                  _InfoRow(
                    label: l10n.shopTracking,
                    value: order.trackingNumber!,
                  ),
              ],
            ),
          ),
          if (showGoToMyProducts) ...[
            const SizedBox(height: AppSizes.p16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.pushNamed(
                    OrdersScreen.routeName,
                    queryParameters: const {'only': 'purchases'},
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: theme.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  l10n.shopGoToMyProducts,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          if (status != ProductFulfillmentStatus.accepted &&
              status != ProductFulfillmentStatus.disputed) ...[
            const SizedBox(height: AppSizes.p16),
            _FulfillmentActions(
              status: status,
              loading: actionLoading,
              isBuyer: isBuyer,
              isSeller: isSeller,
              l10n: l10n,
              onShip: onShip,
              onReceive: onReceive,
              onAccept: onAccept,
              onDispute: onDispute,
            ),
          ],
          const SizedBox(height: AppSizes.p16),
          Text(
            l10n.shopItems,
            style: TextStyle(
              color: theme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          ...order.items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: AppSizes.p12),
              padding: const EdgeInsets.all(AppSizes.p12),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    child: SafeNetworkImage(
                      imageUrl: item.imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: theme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSizes.p4),
                        Text(
                          l10n.shopQty(item.quantity),
                          style: TextStyle(
                            color: theme.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ProductPrice(
                    priceCoins: item.lineTotalCoins,
                    showCompareAt: false,
                    fontSize: 13,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.p8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.p16),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              children: [
                _SummaryRow(label: l10n.shopSubtotal, coins: order.subtotalCoins),
                _SummaryRow(
                  label: l10n.shopCommission,
                  coins: order.commissionCoins,
                ),
                const Divider(height: AppSizes.p24),
                _SummaryRow(
                  label: l10n.shopTotalPaid,
                  coins: order.totalCoins,
                  emphasized: true,
                ),
              ],
            ),
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: AppSizes.p16),
            Text(
              l10n.shopShipping,
              style: TextStyle(
                color: theme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.p16),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(color: theme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address['name'] != null)
                    Text(
                      '${address['name']}',
                      style: TextStyle(color: theme.onSurface),
                    ),
                  if (address['line1'] != null)
                    Text(
                      '${address['line1']}',
                      style: TextStyle(color: theme.mutedText),
                    ),
                  if (address['city'] != null || address['country'] != null)
                    Text(
                      [
                        address['city'],
                        address['country'],
                      ].whereType<String>().join(', '),
                      style: TextStyle(color: theme.mutedText),
                    ),
                  if (address['phone'] != null)
                    Row(
                      children: [
                        Icon(
                          LucideIcons.phone,
                          size: 14,
                          color: theme.mutedText,
                        ),
                        const SizedBox(width: AppSizes.p4),
                        Text(
                          '${address['phone']}',
                          style: TextStyle(color: theme.mutedText),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FulfillmentActions extends StatelessWidget {
  const _FulfillmentActions({
    required this.status,
    required this.loading,
    required this.isBuyer,
    required this.isSeller,
    required this.l10n,
    required this.onShip,
    required this.onReceive,
    required this.onAccept,
    required this.onDispute,
  });

  final ProductFulfillmentStatus status;
  final bool loading;
  final bool isBuyer;
  final bool isSeller;
  final AppLocalizations l10n;
  final VoidCallback onShip;
  final VoidCallback onReceive;
  final VoidCallback onAccept;
  final VoidCallback onDispute;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final actions = <Widget>[];

    switch (status) {
      case ProductFulfillmentStatus.awaitingShipment:
        if (isSeller) {
          actions.add(
            _ActionButton(
              label: l10n.shopShip,
              icon: LucideIcons.truck,
              onPressed: loading ? null : onShip,
              theme: theme,
            ),
          );
        }
        if (isBuyer) {
          actions.add(
            _ActionButton(
              label: l10n.shopDispute,
              icon: LucideIcons.triangleAlert,
              onPressed: loading ? null : onDispute,
              theme: theme,
              outlined: true,
            ),
          );
        }
      case ProductFulfillmentStatus.shipped:
        if (isBuyer) {
          actions.addAll([
            _ActionButton(
              label: l10n.shopReceive,
              icon: LucideIcons.packageCheck,
              onPressed: loading ? null : onReceive,
              theme: theme,
            ),
            _ActionButton(
              label: l10n.shopDispute,
              icon: LucideIcons.triangleAlert,
              onPressed: loading ? null : onDispute,
              theme: theme,
              outlined: true,
            ),
          ]);
        }
      case ProductFulfillmentStatus.delivered:
        if (isBuyer) {
          actions.addAll([
            _ActionButton(
              label: l10n.shopAccept,
              icon: LucideIcons.circleCheck,
              onPressed: loading ? null : onAccept,
              theme: theme,
            ),
            _ActionButton(
              label: l10n.shopDispute,
              icon: LucideIcons.triangleAlert,
              onPressed: loading ? null : onDispute,
              theme: theme,
              outlined: true,
            ),
          ]);
        }
      default:
        break;
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSizes.p8,
      runSpacing: AppSizes.p8,
      children: actions,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.theme,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final ShopTheme theme;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.onSurface,
          side: BorderSide(color: theme.border),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: theme.primary,
        foregroundColor: theme.onAccent,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: theme.mutedText, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.coins,
    this.emphasized = false,
  });

  final String label;
  final int coins;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasized ? theme.onSurface : theme.mutedText,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          ProductPrice(
            priceCoins: coins,
            showCompareAt: false,
            fontSize: emphasized ? 16 : 13,
          ),
        ],
      ),
    );
  }
}
