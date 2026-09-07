import 'dart:math';
import 'package:bimobondapp/app/shop/domain/entities/checkout_snapshot.dart';
import 'package:bimobondapp/core/error/failures.dart';

import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/domain/services/payment_service.dart';
import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:bimobondapp/app/shop/presentation/cubit/shop_cart_cubit.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart'
    as shop_di;
import 'package:bimobondapp/app/shop/presentation/pages/order_details_screen.dart';
import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/product_skeleton.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/shop_back_button.dart';
import 'package:bimobondapp/app/wallets/domain/usecases/wallet_usecases.dart';
import 'package:bimobondapp/app/wallets/presentation/di/wallets_injector.dart'
    as wallets_di;
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    this.liveId,
    this.couponCode,
    this.postId,
    this.items,
    super.key,
  });

  static const routeName = 'shop_checkout';

  final String? liveId;
  final String? couponCode;
  final String? postId;

  /// When set (Buy Now), checkout these items instead of the cart.
  final List<CheckoutItemInput>? items;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final GetCartUseCase _getCart = shop_di.sl();
  final ClearCartUseCase _clearCart = shop_di.sl();
  final PreviewCheckoutUseCase _previewCheckout = shop_di.sl();
  final PaymentService _paymentService = shop_di.sl();
  final GetMyWalletUseCase _getWallet = wallets_di.sl();

  final _quote = CheckoutQuoteState();
  CheckoutPreviewEntity? get _preview => _quote.preview;
  int _balanceCoins = 0;
  bool _loading = true;
  bool _placingOrder = false;
  bool _previewLoading = false;
  bool _paymentUnresolved = false;
  String? _error;
  String? _idempotencyKey;
  late final TextEditingController _couponController;

  String? get _couponCode {
    final value = _couponController.text.trim();
    return value.isEmpty ? null : value;
  }

  bool get _hasEnoughCoins {
    final due = _preview?.coinDueCoins ?? 0;
    return _balanceCoins >= due;
  }

  @override
  void initState() {
    super.initState();
    _couponController = TextEditingController(text: widget.couponCode ?? '');
    _couponController.addListener(_invalidateQuote);
    _load();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _paymentUnresolved = await _paymentService.hasUnresolvedPayment();
    } catch (_) {
      _paymentUnresolved = true;
    }
    if (!mounted) return;
    if (_paymentUnresolved) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!.livePaymentUnresolved;
      });
      return;
    }
    await Future.wait([_loadPreview(), _loadBalance()]);

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadBalance() async {
    final result = await _getWallet(NoParams());
    result.fold((_) {}, (wallet) {
      if (mounted) {
        setState(() => _balanceCoins = wallet.balanceCoins);
      }
    });
  }

  List<CheckoutItemInput>? get _directItems {
    final items = widget.items;
    if (items == null || items.isEmpty) return null;
    return items;
  }

  Future<List<CheckoutItemInput>?> _resolveCheckoutItems() async {
    final direct = _directItems;
    if (direct != null) return direct;

    final cartResult = await _getCart();
    return cartResult.fold(
      (failure) {
        if (mounted) {
          setState(() => _error = ErrorMessageResolver.resolve(failure));
        }
        return null;
      },
      (cart) {
        if (cart.isEmpty) {
          if (mounted) {
            setState(
              () => _error = AppLocalizations.of(context)!.shopCartEmpty,
            );
          }
          return null;
        }
        return cart.items
            .map(
              (item) => CheckoutItemInput(
                productId: item.productId,
                variantId: item.variantId,
                quantity: item.quantity,
              ),
            )
            .toList();
      },
    );
  }

  void _invalidateQuote() {
    if (!mounted) return;
    setState(() {
      _quote.invalidate();
      _previewLoading = false;
      _error = null;
    });
  }

  @override
  void didUpdateWidget(covariant CheckoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liveId != widget.liveId ||
        oldWidget.postId != widget.postId ||
        oldWidget.items != widget.items ||
        oldWidget.couponCode != widget.couponCode) {
      _invalidateQuote();
      if (!_placingOrder) _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    if (_placingOrder || _paymentUnresolved) return;
    final generation = _quote.invalidate();
    final coupon = _couponCode;
    setState(() {
      _previewLoading = true;
      _error = null;
    });
    final items = await _resolveCheckoutItems();
    if (!mounted || !_quote.isCurrent(generation)) return;
    if (items == null || items.isEmpty) {
      setState(() => _previewLoading = false);
      return;
    }
    final snapshot = CheckoutSnapshot(
      items: items,
      couponCode: coupon,
      liveId: widget.liveId,
      postId: widget.postId,
    );
    final result = await _previewCheckout(
      items: snapshot.items,
      paymentMethod: snapshot.method,
      liveId: snapshot.liveId,
      couponCode: snapshot.couponCode,
    );
    if (!mounted || !_quote.isCurrent(generation)) return;
    setState(() {
      _previewLoading = false;
      result.fold(
        (failure) => _error = ErrorMessageResolver.resolve(failure),
        (preview) => _quote.accept(generation, snapshot, preview),
      );
    });
  }

  Future<void> _applyCoupon() => _loadPreview();

  Future<void> _goBuyCoins() async {
    await context.pushNamed('wallet', queryParameters: const {'tab': '0'});
    if (!mounted) return;
    await _loadBalance();
  }

  Future<void> _onPrimaryAction() async {
    if (_placingOrder || _paymentUnresolved || !_quote.canPay) return;
    final snapshot = _quote.snapshot!;

    if (!_hasEnoughCoins) {
      await _goBuyCoins();
      return;
    }

    setState(() => _placingOrder = true);
    _idempotencyKey ??=
        'chk_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 32)}';

    final items = await _resolveCheckoutItems();
    if (items == null || items.isEmpty) {
      if (mounted) setState(() => _placingOrder = false);
      return;
    }

    final current = CheckoutSnapshot(
      items: items,
      couponCode: _couponCode,
      liveId: widget.liveId,
      postId: widget.postId,
    );
    if (current != snapshot || !_quote.canPay) {
      if (!mounted) return;
      setState(() => _placingOrder = false);
      await _loadPreview();
      return;
    }
    final result = await _paymentService.pay(
      items: snapshot.items,
      method: snapshot.method,
      couponCode: snapshot.couponCode,
      liveId: snapshot.liveId,
      postId: snapshot.postId,
      idempotencyKey: _idempotencyKey,
    );

    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() => _placingOrder = false);
        final message = failure is UnresolvedPaymentFailure
            ? AppLocalizations.of(context)!.livePaymentUnresolved
            : ErrorMessageResolver.resolve(failure);
        if (failure is UnresolvedPaymentFailure) {
          setState(() {
            _paymentUnresolved = true;
            _error = message;
          });
        }
        final insufficient =
            message.toLowerCase().contains('insufficient') &&
            message.toLowerCase().contains('wallet');
        if (insufficient) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.shopNotEnoughCoins)));
          await _goBuyCoins();
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      (order) async {
        // An acknowledged order is final even if a later cart refresh fails.
        _idempotencyKey = null;
        if (_directItems == null) {
          try {
            final cleared = await _clearCart();
            if (mounted && cleared.isRight())
              context.read<ShopCartCubit>().clear();
          } catch (_) {
            /* Order navigation must survive cache/refresh failures. */
          }
        }
        if (!mounted) return;
        setState(() => _placingOrder = false);
        context.pushReplacementNamed(
          OrderDetailsScreen.routeName,
          pathParameters: {'orderId': order.id},
          queryParameters: const {'fromCheckout': '1'},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShopThemeScope(
      child: Builder(
        builder: (context) {
          final theme = ShopTheme.of(context);
          return Scaffold(
            backgroundColor: theme.background,
            appBar: AppBar(
              backgroundColor: theme.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: const ShopBackButton(),
            ),
            body: _loading
                ? const CheckoutSkeleton()
                : _CheckoutBody(
                    preview: _preview,
                    previewLoading: _previewLoading,
                    error: _error,
                    paymentUnresolved: _paymentUnresolved,
                    balanceCoins: _balanceCoins,
                    hasEnoughCoins: _hasEnoughCoins,
                    placingOrder: _placingOrder,
                    onPrimaryAction: _onPrimaryAction,
                    onBuyCoins: _goBuyCoins,
                    liveId: widget.liveId,
                    couponController: _couponController,
                    onCouponApplied: _applyCoupon,
                  ),
          );
        },
      ),
    );
  }
}

class _CheckoutBody extends StatelessWidget {
  const _CheckoutBody({
    required this.preview,
    required this.previewLoading,
    required this.error,
    required this.paymentUnresolved,
    required this.balanceCoins,
    required this.hasEnoughCoins,
    required this.placingOrder,
    required this.onPrimaryAction,
    required this.onBuyCoins,
    required this.liveId,
    required this.couponController,
    required this.onCouponApplied,
  });

  final CheckoutPreviewEntity? preview;
  final bool previewLoading;
  final String? error;
  final bool paymentUnresolved;
  final int balanceCoins;
  final bool hasEnoughCoins;
  final bool placingOrder;
  final VoidCallback onPrimaryAction;
  final VoidCallback onBuyCoins;
  final String? liveId;
  final TextEditingController couponController;
  final Future<void> Function() onCouponApplied;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final fieldFill = theme.surface;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.p20,
              0,
              AppSizes.p20,
              AppSizes.p24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: l10n.shopPayWithCoins),
                const SizedBox(height: AppSizes.p16),
                if (liveId != null && liveId!.isNotEmpty) ...[
                  _LiveCouponField(
                    controller: couponController,
                    enabled: !placingOrder && !paymentUnresolved,
                    onApply: onCouponApplied,
                  ),
                  const SizedBox(height: AppSizes.p16),
                ],
                if (previewLoading) const LinearProgressIndicator(),
                if (error != null || preview == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(error ?? l10n.shopPreviewChanged),
                  ),
                if (preview == null && !previewLoading && !paymentUnresolved)
                  TextButton(
                    onPressed: onCouponApplied,
                    child: Text(l10n.shopCouponApply),
                  ),
                if (preview != null)
                  _CoinsPaymentCard(
                    preview: preview!,
                    balanceCoins: balanceCoins,
                    hasEnoughCoins: hasEnoughCoins,
                    onBuyCoins: onBuyCoins,
                    fillColor: fieldFill,
                    l10n: l10n,
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSizes.p20,
            AppSizes.p12,
            AppSizes.p20,
            AppSizes.p16 + MediaQuery.paddingOf(context).bottom,
          ),
          color: theme.background,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  placingOrder ||
                      paymentUnresolved ||
                      preview == null ||
                      previewLoading
                  ? null
                  : onPrimaryAction,
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: theme.onAccent,
                disabledBackgroundColor: theme.primary.withValues(alpha: 0.45),
                elevation: 0,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: placingOrder
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.onAccent,
                      ),
                    )
                  : Text(
                      preview == null
                          ? l10n.shopPayWithCoins
                          : hasEnoughCoins
                          ? l10n.shopPayCoinsAmount(preview!.coinDueCoins)
                          : l10n.shopBuyCoins,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveCouponField extends StatelessWidget {
  const _LiveCouponField({
    required this.controller,
    required this.onApply,
    required this.enabled,
  });

  final bool enabled;

  final TextEditingController controller;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.shopCouponLabel,
              hintText: AppLocalizations.of(context)!.shopCouponHint,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.p8),
        FilledButton(
          onPressed: enabled ? () => onApply() : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.primary,
            foregroundColor: theme.onAccent,
          ),
          child: Text(AppLocalizations.of(context)!.shopCouponApply),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.primary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: AppSizes.p12),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: theme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoinsPaymentCard extends StatelessWidget {
  const _CoinsPaymentCard({
    required this.preview,
    required this.balanceCoins,
    required this.hasEnoughCoins,
    required this.onBuyCoins,
    required this.fillColor,
    required this.l10n,
  });

  final CheckoutPreviewEntity preview;
  final int balanceCoins;
  final bool hasEnoughCoins;
  final VoidCallback onBuyCoins;
  final Color fillColor;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.coins, size: 20, color: theme.primary),
              const SizedBox(width: AppSizes.p8),
              Expanded(
                child: Text(
                  l10n.shopYourBalance,
                  style: TextStyle(
                    color: theme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '$balanceCoins',
                style: TextStyle(
                  color: hasEnoughCoins ? theme.onSurface : errorColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          ...preview.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.p8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.title} × ${line.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.mutedText, fontSize: 13),
                    ),
                  ),
                  Text(
                    '${line.lineTotalCoins}',
                    style: TextStyle(
                      color: theme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: AppSizes.p20, color: theme.border),
          _PayRow(label: l10n.shopSubtotal, value: preview.subtotalCoins),
          _PayRow(
            label: l10n.shopDueNow,
            value: preview.coinDueCoins,
            bold: true,
          ),
          if (!hasEnoughCoins) ...[
            const SizedBox(height: AppSizes.p12),
            Text(
              l10n.shopNeedMoreCoins(preview.coinDueCoins - balanceCoins),
              style: TextStyle(
                color: errorColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            TextButton(
              onPressed: onBuyCoins,
              style: TextButton.styleFrom(
                foregroundColor: theme.primary,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                l10n.shopBuyCoins,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({required this.label, required this.value, this.bold = false});

  final String label;
  final int value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? theme.onSurface : theme.mutedText,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontSize: bold ? 15 : 13,
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: bold ? theme.primary : theme.onSurface,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
