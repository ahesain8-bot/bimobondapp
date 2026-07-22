import 'package:bimobondapp/app/gifts/data/models/gift_model.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_inventory_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gifts_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/purchase_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/send_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import 'package:bimobondapp/app/gifts/presentation/utils/gift_lottie_cache.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/first_recharge_offer_sheet.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

typedef OnGiftSentCallback = void Function(GiftEntity gift);

enum _GiftSheetTab { gifts, songs, interactive }

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
  static const _sheetBg = Color(0xFF161618);
  static const _footerBg = Color(0xFF121214);
  static const _accent = LiveDetailsLayoutConstants.liveBadgeColor;

  final _getGifts = gifts_di.sl<GetGiftsUseCase>();
  final _getInventory = gifts_di.sl<GetGiftInventoryUseCase>();
  final _purchaseGift = gifts_di.sl<PurchaseGiftUseCase>();
  final _sendGift = gifts_di.sl<SendGiftUseCase>();

  List<GiftEntity> _catalog = [];
  final Set<String> _pinnedIds = {};
  GiftInventoryEntity? _inventory;
  int? _selectedIndex;
  _GiftSheetTab _tab = _GiftSheetTab.gifts;
  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  bool get _canSend =>
      widget.canSendToHost &&
      ((widget.postId != null && widget.postId!.isNotEmpty) ||
          (widget.receiverId != null && widget.receiverId!.isNotEmpty));

  ColorScheme get _scheme => Theme.of(context).colorScheme;

  List<GiftEntity> get _orderedCatalog {
    if (_pinnedIds.isEmpty) return _catalog;
    final pinned = <GiftEntity>[];
    final rest = <GiftEntity>[];
    for (final gift in _catalog) {
      if (_pinnedIds.contains(gift.id)) {
        pinned.add(gift);
      } else {
        rest.add(gift);
      }
    }
    return [...pinned, ...rest];
  }

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
          if (_selectedIndex != null && _selectedIndex! >= _catalog.length) {
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
    final ordered = _orderedCatalog;
    final index = _selectedIndex;
    if (index == null || index < 0 || index >= ordered.length) {
      return null;
    }
    return ordered[index];
  }

  int _ownedQuantity(String giftId) => _inventory?.quantityFor(giftId) ?? 0;

  bool _canAfford(GiftEntity gift) {
    if (_ownedQuantity(gift.id) > 0) return true;
    final balance = _inventory?.balanceCoins ?? 0;
    return balance >= gift.priceCoins;
  }

  Future<void> _openRecharge() async {
    final toppedUp = await FirstRechargeOfferSheet.show(context);
    if (!mounted) return;
    if (toppedUp == true) {
      await _load();
    }
  }

  Future<bool> _offerTopUp() async {
    await _openRecharge();
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
    final result = await _purchaseGift(PurchaseGiftParams(giftId: gift.id));
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
    });

    if (needsPurchase) {
      final purchased = await _purchaseGiftInternal(gift);
      if (!mounted) return;
      if (!purchased) {
        setState(() {
          _busy = false;
        });
        return;
      }
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

  void _togglePinSelected() {
    final gift = _selectedGift;
    if (gift == null) return;
    setState(() {
      if (_pinnedIds.contains(gift.id)) {
        _pinnedIds.remove(gift.id);
      } else {
        _pinnedIds.add(gift.id);
      }
      // Keep selection on the same gift after reorder.
      final ordered = _orderedCatalog;
      _selectedIndex = ordered.indexWhere((g) => g.id == gift.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final height =
        MediaQuery.sizeOf(context).height *
        LiveDetailsLayoutConstants.giftSheetHeightFactor;

    return Material(
      color: _sheetBg,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(LiveDetailsLayoutConstants.giftSheetRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height.clamp(320.0, 560.0),
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
            const SizedBox(height: 10),
            _LevelBanner(onTap: _openRecharge),
            _PinRow(
              selected: _selectedGift != null,
              isPinned:
                  _selectedGift != null &&
                  _pinnedIds.contains(_selectedGift!.id),
              onPin: _selectedGift == null ? null : _togglePinSelected,
            ),
            Expanded(child: _buildTabBody(l10n)),
            _BottomBar(
              tab: _tab,
              onTabChanged: (tab) => setState(() => _tab = tab),
              onRecharge: _openRecharge,
              balanceCoins: _inventory?.balanceCoins ?? 0,
              loadingBalance: _loading && _isLoggedIn,
              bottomInset: bottomInset,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody(AppLocalizations l10n) {
    switch (_tab) {
      case _GiftSheetTab.gifts:
        return _buildGrid(l10n);
      case _GiftSheetTab.songs:
      case _GiftSheetTab.interactive:
        return Center(
          child: Text(
            l10n.liveGiftTabComingSoon,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
    }
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
                style: TextButton.styleFrom(foregroundColor: _accent),
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

    final ordered = _orderedCatalog;
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: LiveDetailsLayoutConstants.giftGridCrossCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: ordered.length,
      itemBuilder: (context, index) {
        final gift = ordered[index];
        return _GiftTile(
          gift: gift,
          isSelected: _selectedIndex == index,
          isPinned: _pinnedIds.contains(gift.id),
          owned: _ownedQuantity(gift.id),
          busy: _busy && _selectedIndex == index,
          accent: _scheme.primary,
          sendLabel: l10n.liveGiftSendAction,
          onSelect: _busy
              ? null
              : () {
                  setState(() => _selectedIndex = index);
                  GiftLottieCache.instance.prefetch([gift.animationUrl]);
                },
          onSend: _busy || !_canSend ? null : () => _send(gift),
        );
      },
    );
  }
}

class _LevelBanner extends StatelessWidget {
  const _LevelBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muted = Colors.white.withValues(alpha: 0.72);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.gift, size: 14, color: muted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.liveGiftLevelBanner,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
                DirectionalChevronIcon(
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.selected,
    required this.isPinned,
    required this.onPin,
  });

  final bool selected;
  final bool isPinned;
  final VoidCallback? onPin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.liveGiftPinHint,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onPin,
            style: TextButton.styleFrom(
              foregroundColor: selected
                  ? accent
                  : Colors.white.withValues(alpha: 0.28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isPinned ? l10n.liveGiftUnpinAction : l10n.liveGiftPinAction,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({
    required this.gift,
    required this.isSelected,
    required this.isPinned,
    required this.owned,
    required this.busy,
    required this.accent,
    required this.sendLabel,
    required this.onSelect,
    required this.onSend,
  });

  final GiftEntity gift;
  final bool isSelected;
  final bool isPinned;
  final int owned;
  final bool busy;
  final Color accent;
  final String sendLabel;
  final VoidCallback? onSelect;
  final VoidCallback? onSend;

  static const double _footerSlotHeight = 24;
  static const double _metaSlotHeight = 16;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final priceStyle = TextStyle(
      color: Colors.white.withValues(alpha: isSelected ? 0.9 : 0.55),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFE2C55).withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
              child: Column(
                children: [
                  // Same icon slot for selected + unselected → stable cell size.
                  Expanded(
                    child: Center(
                      child: _GiftIcon(
                        gift: gift,
                        isSelected: isSelected,
                        size: 36,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _metaSlotHeight,
                    child: Center(
                      child: isSelected
                          ? AppCoinAmount(
                              iconSize: 10,
                              spacing: 2,
                              text: gift.priceCoinsLabel(locale),
                              style: priceStyle,
                            )
                          : Text(
                              shortGiftName(gift.name),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: _footerSlotHeight,
                    width: double.infinity,
                    child: isSelected
                        ? FilledButton(
                            onPressed: busy ? null : onSend,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFE2C55),
                              disabledBackgroundColor: const Color(
                                0xFFFE2C55,
                              ).withValues(alpha: 0.55),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, _footerSlotHeight),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: busy
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    sendLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                          )
                        : Center(
                            child: AppCoinAmount(
                              iconSize: 10,
                              spacing: 2,
                              text: gift.priceCoinsLabel(locale),
                              style: priceStyle,
                            ),
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
            if (isPinned)
              Positioned(
                top: 4,
                left: 4,
                child: Icon(
                  LucideIcons.pin,
                  size: 11,
                  color: accent.withValues(alpha: 0.95),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tab,
    required this.onTabChanged,
    required this.onRecharge,
    required this.balanceCoins,
    required this.loadingBalance,
    required this.bottomInset,
  });

  final _GiftSheetTab tab;
  final ValueChanged<_GiftSheetTab> onTabChanged;
  final VoidCallback onRecharge;
  final int balanceCoins;
  final bool loadingBalance;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.fromLTRB(8, 6, 12, 8 + bottomInset),
      decoration: BoxDecoration(
        color: _LiveGiftSheetBodyState._footerBg,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _TabChip(
                  label: l10n.liveGiftTabGifts,
                  selected: tab == _GiftSheetTab.gifts,
                  onTap: () => onTabChanged(_GiftSheetTab.gifts),
                ),
                _TabChip(
                  label: l10n.liveGiftTabSongs,
                  selected: tab == _GiftSheetTab.songs,
                  onTap: () => onTabChanged(_GiftSheetTab.songs),
                ),
                _TabChip(
                  label: l10n.liveGiftTabInteractive,
                  selected: tab == _GiftSheetTab.interactive,
                  onTap: () => onTabChanged(_GiftSheetTab.interactive),
                ),
              ],
            ),
          ),
          if (loadingBalance)
            const GiftBalanceChipSkeleton()
          else
            _RechargeButton(
              coins: balanceCoins,
              accent: accent,
              onTap: onRecharge,
            ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: selected ? 0.95 : 0.45),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: selected ? 10 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RechargeButton extends StatelessWidget {
  const _RechargeButton({
    required this.coins,
    required this.accent,
    required this.onTap,
  });

  final int coins;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final label = LocaleFormatUtils.localizeDigits(coins.toString(), locale);

    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
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
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.liveGiftRecharge,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              DirectionalChevronIcon(
                size: 14,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftIcon extends StatelessWidget {
  const _GiftIcon({required this.gift, required this.isSelected, this.size});

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
            Icon(LucideIcons.gift, size: iconSize * 0.7, color: Colors.white70),
      );
    }
    return Text(icon, style: TextStyle(fontSize: iconSize));
  }
}
