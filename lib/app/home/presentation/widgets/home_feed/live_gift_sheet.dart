import 'package:bimobondapp/app/gifts/data/models/gift_model.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_inventory_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gifts_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/purchase_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/send_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart' as gifts_di;
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

typedef OnGiftSentCallback = void Function();

String shortGiftName(String name) {
  const maxLen = LiveDetailsLayoutConstants.giftNameMaxLength;
  final trimmed = name.trim();
  if (trimmed.length <= maxLen) return trimmed;
  return '${trimmed.substring(0, maxLen)}…';
}

class LiveGiftSheet {
  LiveGiftSheet._();

  static Future<void> show(
    BuildContext context, {
    String? postId,
    String? receiverId,
    String? auctionId,
    bool canSendToHost = true,
    OnGiftSentCallback? onGiftSent,
  }) {
    return GlassBottomSheet.open<void>(
      context,
      isScrollControlled: true,
      builder: (_) => _LiveGiftSheetBody(
        postId: postId,
        receiverId: receiverId,
        auctionId: auctionId,
        canSendToHost: canSendToHost,
        onGiftSent: onGiftSent,
      ),
    );
  }
}

class _LiveGiftSheetBody extends StatefulWidget {
  const _LiveGiftSheetBody({
    this.postId,
    this.receiverId,
    this.auctionId,
    this.canSendToHost = true,
    this.onGiftSent,
  });

  final String? postId;
  final String? receiverId;
  final String? auctionId;
  final bool canSendToHost;
  final OnGiftSentCallback? onGiftSent;

  @override
  State<_LiveGiftSheetBody> createState() => _LiveGiftSheetBodyState();
}

class _LiveGiftSheetBodyState extends State<_LiveGiftSheetBody> {
  static const _giftColors = [
    Colors.redAccent,
    Colors.brown,
    Colors.pinkAccent,
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.blueAccent,
    Colors.cyanAccent,
    Colors.purpleAccent,
    Colors.teal,
  ];

  final _getGifts = gifts_di.sl<GetGiftsUseCase>();
  final _getInventory = gifts_di.sl<GetGiftInventoryUseCase>();
  final _purchaseGift = gifts_di.sl<PurchaseGiftUseCase>();
  final _sendGift = gifts_di.sl<SendGiftUseCase>();

  List<GiftEntity> _catalog = [];
  GiftInventoryEntity? _inventory;
  int? _selectedIndex;
  bool _loading = true;
  bool _busy = false;
  bool _isPurchasing = false;
  String? _loadError;

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  bool get _canSend =>
      widget.canSendToHost &&
      ((widget.postId != null && widget.postId!.isNotEmpty) ||
          (widget.receiverId != null && widget.receiverId!.isNotEmpty));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final giftsResult = await _getGifts(NoParams());
    GiftInventoryEntity? inventory;

    if (_isLoggedIn) {
      final inventoryResult = await _getInventory(NoParams());
      inventoryResult.fold((_) => null, (data) => inventory = data);
    }

    if (!mounted) return;

    giftsResult.fold(
      (failure) {
        setState(() {
          _loading = false;
          _loadError = failure.message;
        });
      },
      (gifts) {
        setState(() {
          _catalog = gifts;
          _inventory = inventory;
          _loading = false;
          if (_selectedIndex != null &&
              _selectedIndex! >= _catalog.length) {
            _selectedIndex = null;
          }
        });
      },
    );
  }

  Color _colorForIndex(int index) =>
      _giftColors[index % _giftColors.length];

  GiftEntity? get _selectedGift {
    final index = _selectedIndex;
    if (index == null || index < 0 || index >= _catalog.length) {
      return null;
    }
    return _catalog[index];
  }

  int _ownedQuantity(String giftId) =>
      _inventory?.quantityFor(giftId) ?? 0;

  bool _canAfford(GiftEntity gift) {
    if (_ownedQuantity(gift.id) > 0) return true;
    final balance = _inventory?.balanceCoins ?? 0;
    return balance >= gift.priceCoins;
  }

  Future<bool> _offerTopUp() async {
    final l10n = AppLocalizations.of(context)!;
    var confirmed = false;
    await PopupDialogs.showConfirmDialog(
      context,
      title: l10n.coinsInsufficientBalance,
      message: '',
      confirmLabel: l10n.walletTopUpButton,
      cancelLabel: l10n.cancel,
      onConfirm: () => confirmed = true,
    );
    if (!mounted || !confirmed) return false;
    Navigator.pop(context);
    context.push('/settings/wallet?tab=0');
    return false;
  }

  void _applyInventoryUpdate(GiftInventoryEntity inventory) {
    final update = inventory is GiftInventoryModel
        ? inventory
        : GiftInventoryModel(
            balanceCoins: inventory.balanceCoins,
            items: inventory.items,
          );
    setState(() {
      _inventory = GiftInventoryModel.merge(_inventory, update);
    });
  }

  Future<bool> _purchaseGiftInternal(GiftEntity gift) async {
    final result = await _purchaseGift(
      PurchaseGiftParams(giftId: gift.id),
    );
    if (!mounted) return false;

    return result.fold(
      (failure) {
        PopupDialogs.showErrorDialog(context, failure.message);
        return false;
      },
      (inventory) {
        _applyInventoryUpdate(inventory);
        return true;
      },
    );
  }

  Future<void> _purchase(GiftEntity gift) async {
    if (!_isLoggedIn) {
      _showLoginRequired();
      return;
    }
    if (!_canAfford(gift)) {
      await _offerTopUp();
      return;
    }

    setState(() {
      _busy = true;
      _isPurchasing = true;
    });
    final purchased = await _purchaseGiftInternal(gift);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _isPurchasing = false;
    });

    if (!purchased) return;

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.liveGiftPurchaseSuccess(gift.name)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _send(GiftEntity gift) async {
    if (!_isLoggedIn) {
      _showLoginRequired();
      return;
    }
    if (!widget.canSendToHost) {
      PopupDialogs.showErrorDialog(
        context,
        AppLocalizations.of(context)!.liveGiftCannotSendToSelf,
      );
      return;
    }
    if (!_canSend) {
      PopupDialogs.showErrorDialog(
        context,
        AppLocalizations.of(context)!.liveGiftNoRecipient,
      );
      return;
    }

    final needsPurchase = _ownedQuantity(gift.id) < 1;
    if (needsPurchase && !_canAfford(gift)) {
      await _offerTopUp();
      return;
    }

    setState(() {
      _busy = true;
      _isPurchasing = needsPurchase;
    });

    if (needsPurchase) {
      final purchased = await _purchaseGiftInternal(gift);
      if (!mounted) return;
      if (!purchased) {
        setState(() {
          _busy = false;
          _isPurchasing = false;
        });
        return;
      }
      setState(() => _isPurchasing = false);
    }

    if (!mounted) return;

    final result = await _sendGift(
      SendGiftParams(
        giftId: gift.id,
        postId: widget.postId,
        receiverId: widget.receiverId,
        auctionId: widget.auctionId,
      ),
    );
    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() => _busy = false);
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (inventoryUpdate) async {
        if (inventoryUpdate != null) {
          _applyInventoryUpdate(inventoryUpdate);
        } else {
          final inventoryResult = await _getInventory(NoParams());
          if (!mounted) return;
          inventoryResult.fold((_) {}, _applyInventoryUpdate);
        }

        if (!mounted) return;
        setState(() => _busy = false);
        widget.onGiftSent?.call();
        Navigator.pop(context);
      },
    );
  }

  void _showLoginRequired() {
    PopupDialogs.showErrorDialog(
      context,
      AppLocalizations.of(context)!.liveGiftLoginRequired,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = _selectedGift;
    final owned = selected == null ? 0 : _ownedQuantity(selected.id);

    return GlassBottomSheetFrame(
      showHandle: true,
      child: SizedBox(
        height: MediaQuery.of(context).size.height *
            LiveDetailsLayoutConstants.giftSheetHeightFactor,
        child: Column(
          children: [
            const SizedBox(height: AppSizes.p4),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      l10n.liveSendGift,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _loading && _isLoggedIn
                          ? const GiftBalanceChipSkeleton()
                          : _CoinBalanceChip(
                              label: l10n.liveCoinsBalance(
                                _inventory?.balanceCoins ?? 0,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.p20),
              Expanded(child: _buildGrid(l10n)),
              if (_loading)
                const GiftSheetFooterSkeleton()
              else
                _buildFooter(l10n, selected, owned),
            ],
          ),
        ),
    );
  }

  Widget _buildGrid(AppLocalizations l10n) {
    if (_loading) {
      return const GiftSheetSkeleton();
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: AppSizes.p16),
              TextButton(
                onPressed: _load,
                child: Text(l10n.liveGiftRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (_catalog.isEmpty) {
      return Center(
        child: Text(
          l10n.liveGiftCatalogEmpty,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    final crossCount = LiveDetailsLayoutConstants.giftGridCrossCount;
    const horizontalPadding = AppSizes.p20;
    const spacing = AppSizes.p16;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final itemWidth =
        (screenWidth - horizontalPadding * 2 - spacing * (crossCount - 1)) /
        crossCount;
    final itemHeight =
        itemWidth / LiveDetailsLayoutConstants.giftGridAspectRatio;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: spacing,
        runSpacing: spacing,
        children: List.generate(_catalog.length, (index) {
          final gift = _catalog[index];
          return SizedBox(
            width: itemWidth,
            height: itemHeight,
            child: _buildGiftTile(
              l10n: l10n,
              gift: gift,
              index: index,
              owned: _ownedQuantity(gift.id),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGiftTile({
    required AppLocalizations l10n,
    required GiftEntity gift,
    required int index,
    required int owned,
  }) {
    final color = _colorForIndex(index);
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: _busy ? null : () => setState(() => _selectedIndex = index),
      child: Transform.scale(
        scale: isSelected ? 1.05 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppSizes.p16),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.p4,
                  AppSizes.p4,
                  AppSizes.p4,
                  LiveDetailsLayoutConstants.giftTilePriceBoxHeight +
                      AppSizes.p6,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GiftIcon(
                          gift: gift,
                          isSelected: isSelected,
                          size: isSelected ? 26 : 22,
                        ),
                        const SizedBox(height: AppSizes.p4),
                        Text(
                          shortGiftName(gift.name),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSizes.p4,
                right: AppSizes.p4,
                bottom: AppSizes.p4,
                child: _GiftPriceChip(
                  l10n: l10n,
                  gift: gift,
                  compact: true,
                  emphasized: isSelected,
                ),
              ),
              if (owned > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l10n.liveGiftOwned(owned),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(
    AppLocalizations l10n,
    GiftEntity? selected,
    int owned,
  ) {
    final index = _selectedIndex;
    final accentColor = index == null
        ? Colors.grey.shade700
        : _colorForIndex(index);

    String primaryLabel;
    VoidCallback? onPrimary;

    if (selected == null) {
      primaryLabel = l10n.liveSelectGift;
    } else if (_busy) {
      primaryLabel = _isPurchasing
          ? l10n.liveGiftBuying
          : l10n.liveGiftSending;
    } else if (_canSend) {
      primaryLabel = l10n.liveSendToHost;
      onPrimary = () => _send(selected);
    } else if (owned > 0) {
      primaryLabel = l10n.liveGiftBuyMore;
      onPrimary = () => _purchase(selected);
    } else {
      primaryLabel = l10n.liveGiftBuy(
        selected.priceCoinsLabel(Localizations.localeOf(context)),
      );
      onPrimary = () => _purchase(selected);
    }

    return Container(
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (selected != null) ...[
              _GiftIcon(gift: selected, isSelected: true, size: 48),
              const SizedBox(height: AppSizes.p8),
              Text(
                shortGiftName(selected.name),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: AppSizes.p4),
              _GiftPriceChip(
                l10n: l10n,
                gift: selected,
                compact: false,
                emphasized: true,
              ),
              const SizedBox(height: AppSizes.p12),
            ],
            if (selected != null && owned > 0 && !_canSend && !_busy) ...[
              TextButton(
                onPressed: () => _purchase(selected),
                child: Text(
                  l10n.liveGiftBuyMore,
                  style: const TextStyle(color: Colors.amberAccent),
                ),
              ),
              const SizedBox(height: AppSizes.p4),
            ],
            GestureDetector(
              onTap: _busy || onPrimary == null ? null : onPrimary,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: selected != null && !_busy ? 1 : 0.5,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: selected != null
                          ? [
                              accentColor.withValues(alpha: 0.8),
                              accentColor,
                            ]
                          : [
                              Colors.grey.shade800,
                              Colors.grey.shade700,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: selected != null
                        ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          primaryLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftPriceChip extends StatelessWidget {
  const _GiftPriceChip({
    required this.l10n,
    required this.gift,
    required this.compact,
    required this.emphasized,
  });

  final AppLocalizations l10n;
  final GiftEntity gift;
  final bool compact;
  final bool emphasized;

  String _formattedAmount(Locale locale) {
    return LocaleFormatUtils.localizeDigits(
      gift.priceCoins.toString(),
      locale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final amountText = _formattedAmount(locale);
    final priceText = l10n.liveGiftPriceAmount(amountText, l10n.coinsUnit);
    final priceFontSize = compact
        ? LiveDetailsLayoutConstants.giftTilePriceFontSize
        : LiveDetailsLayoutConstants.giftFooterPriceFontSize;
    final labelFontSize = compact
        ? LiveDetailsLayoutConstants.giftTilePriceLabelFontSize
        : LiveDetailsLayoutConstants.giftFooterPriceLabelFontSize;

    final boxHeight = compact
        ? LiveDetailsLayoutConstants.giftTilePriceBoxHeight
        : LiveDetailsLayoutConstants.giftFooterPriceBoxHeight;
    final boxWidth = compact
        ? double.infinity
        : LiveDetailsLayoutConstants.giftFooterPriceBoxWidth;

    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: emphasized ? 0.35 : 0.25),
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          border: Border.all(
            color: LiveDetailsLayoutConstants.giftCommentGold.withValues(
              alpha: emphasized ? 0.9 : 0.55,
            ),
            width: emphasized ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: compact ? 3 : AppSizes.p4,
              ),
              decoration: BoxDecoration(
                color: LiveDetailsLayoutConstants.giftCommentGold.withValues(
                  alpha: emphasized ? 0.35 : 0.22,
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(compact ? 9 : 13),
                ),
              ),
              child: Text(
                l10n.liveGiftPriceLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: LiveDetailsLayoutConstants.giftCommentGoldText,
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  height: 1.1,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.p4),
                    child: Text(
                      priceText,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: emphasized
                            ? LiveDetailsLayoutConstants.giftCommentGoldText
                            : Colors.amberAccent,
                        fontSize: priceFontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftIcon extends StatelessWidget {
  const _GiftIcon({
    required this.gift,
    required this.isSelected,
    this.size,
  });

  final GiftEntity gift;
  final bool isSelected;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? (isSelected ? 32.0 : 28.0);
    final icon = gift.icon.trim();
    if (gift.hasNetworkIcon ||
        icon.startsWith('http://') ||
        icon.startsWith('https://')) {
      return SafeNetworkImage(
        imageUrl: icon,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        showLoadingIndicator: false,
        errorIcon: Icons.card_giftcard_outlined,
      );
    }
    if (icon.startsWith('assets/')) {
      return Image.asset(
        icon,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            Text('🎁', style: TextStyle(fontSize: iconSize)),
      );
    }
    return Text(icon, style: TextStyle(fontSize: iconSize));
  }
}

class _CoinBalanceChip extends StatelessWidget {
  const _CoinBalanceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p12,
        vertical: AppSizes.p6,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Colors.amber,
            size: 16,
          ),
          const SizedBox(width: AppSizes.p4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
