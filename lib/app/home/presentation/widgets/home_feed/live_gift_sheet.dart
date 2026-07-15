import 'package:bimobondapp/app/gifts/data/models/gift_model.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_inventory_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gifts_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/purchase_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/send_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart' as gifts_di;
import 'package:bimobondapp/app/gifts/presentation/utils/gift_lottie_cache.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

typedef OnGiftSentCallback = void Function(GiftEntity gift);

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
        GiftLottieCache.instance.prefetch(
          gifts.map((gift) => gift.animationUrl),
        );
      },
    );
  }

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
        final onSent = widget.onGiftSent;
        // Close gift picker first, then play TikTok-style animation on the live screen.
        Navigator.of(context).pop();
        onSent?.call(gift);
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: const Color(0xFF161618),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.46,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.liveSendGift,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (_loading && _isLoggedIn)
                    const GiftBalanceChipSkeleton()
                  else
                    _CoinBalanceChip(
                      coins: _inventory?.balanceCoins ?? 0,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildGrid(l10n)),
            if (_loading)
              const GiftSheetFooterSkeleton()
            else
              _buildFooter(l10n, selected, owned, bottomInset),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
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
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 14,
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: _catalog.length,
      itemBuilder: (context, index) {
        final gift = _catalog[index];
        return _buildGiftTile(
          l10n: l10n,
          gift: gift,
          index: index,
          owned: _ownedQuantity(gift.id),
        );
      },
    );
  }

  Widget _buildGiftTile({
    required AppLocalizations l10n,
    required GiftEntity gift,
    required int index,
    required int owned,
  }) {
    final isSelected = _selectedIndex == index;
    final locale = Localizations.localeOf(context);

    return GestureDetector(
      onTap: _busy
          ? null
          : () {
              setState(() => _selectedIndex = index);
              GiftLottieCache.instance.prefetch([
                _catalog[index].animationUrl,
              ]);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: _GiftIcon(
                        gift: gift,
                        isSelected: isSelected,
                        size: isSelected ? 36 : 32,
                      ),
                    ),
                  ),
                  Text(
                    shortGiftName(gift.name),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: isSelected ? 0.95 : 0.7,
                      ),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AppCoinAmount(
                    iconSize: 10,
                    spacing: 2,
                    text: gift.priceCoinsLabel(locale),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (owned > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'x$owned',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(
    AppLocalizations l10n,
    GiftEntity? selected,
    int owned,
    double bottomInset,
  ) {
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

    final canTap = selected != null && !_busy && onPrimary != null;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
      decoration: BoxDecoration(
        color: const Color(0xFF121214),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          if (selected != null) ...[
            _GiftIcon(gift: selected, isSelected: true, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shortGiftName(selected.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AppCoinAmount(
                    iconSize: 11,
                    spacing: 3,
                    text: selected.priceCoinsLabel(
                      Localizations.localeOf(context),
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Expanded(
              child: Text(
                l10n.liveSelectGift,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: canTap ? onPrimary : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFE2C55),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ],
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
    final imageUrl = gift.displayImageUrl ?? icon;
    if (gift.hasNetworkIcon ||
        imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://') ||
        imageUrl.startsWith('/')) {
      return SafeNetworkImage(
        imageUrl: imageUrl,
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
  const _CoinBalanceChip({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final label = LocaleFormatUtils.localizeDigits(coins.toString(), locale);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppCoinIcon(size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
