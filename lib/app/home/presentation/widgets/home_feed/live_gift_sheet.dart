import 'package:bimobondapp/app/gifts/data/models/gift_model.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_group_entity.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_groups_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_inventory_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gifts_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/purchase_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/send_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import 'dart:async';

import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/gifts/presentation/utils/gift_accent_color.dart';
import 'package:bimobondapp/app/gifts/presentation/utils/gift_catalog_audio_preview.dart';
import 'package:bimobondapp/app/gifts/presentation/utils/gift_lottie_cache.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/gift_vinyl_record_icon.dart';
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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

typedef OnGiftSentCallback = void Function(GiftEntity gift);

String giftGroupTabLabel(GiftGroupEntity group, AppLocalizations l10n) {
  final fromBackend = group.tabLabel;
  if (fromBackend.isNotEmpty) return fromBackend;
  return l10n.liveGiftTabGifts;
}

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
    String? liveId,
    bool canSendToHost = true,
    OnGiftSentCallback? onGiftSent,
    OnGiftSentCallback? onSmallGiftOptimistic,
  }) {
    return GlassBottomSheet.open<void>(
      context,
      isScrollControlled: true,
      builder: (_) => _LiveGiftSheetBody(
        postId: postId,
        receiverId: receiverId,
        auctionId: auctionId,
        liveId: liveId,
        canSendToHost: canSendToHost,
        onGiftSent: onGiftSent,
        onSmallGiftOptimistic: onSmallGiftOptimistic,
      ),
    );
  }
}

class _LiveGiftSheetBody extends StatefulWidget {
  const _LiveGiftSheetBody({
    this.postId,
    this.receiverId,
    this.auctionId,
    this.liveId,
    this.canSendToHost = true,
    this.onGiftSent,
    this.onSmallGiftOptimistic,
  });

  final String? postId;
  final String? receiverId;
  final String? auctionId;
  final String? liveId;
  final bool canSendToHost;
  final OnGiftSentCallback? onGiftSent;
  final OnGiftSentCallback? onSmallGiftOptimistic;

  @override
  State<_LiveGiftSheetBody> createState() => _LiveGiftSheetBodyState();
}

class _LiveGiftSheetBodyState extends State<_LiveGiftSheetBody> {
  static const _sheetBg = Color(0xFF161618);
  static const _footerBg = Color(0xFF121214);
  static const _accent = LiveDetailsLayoutConstants.liveBadgeColor;

  final _getGiftGroups = gifts_di.sl<GetGiftGroupsUseCase>();
  final _getGifts = gifts_di.sl<GetGiftsUseCase>();
  final _getInventory = gifts_di.sl<GetGiftInventoryUseCase>();
  final _purchaseGift = gifts_di.sl<PurchaseGiftUseCase>();
  final _sendGift = gifts_di.sl<SendGiftUseCase>();

  List<GiftGroupEntity> _groups = [];
  List<GiftEntity> _catalog = [];
  final Set<String> _pinnedIds = {};
  GiftInventoryEntity? _inventory;
  int? _selectedIndex;
  int _selectedGroupIndex = 0;
  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  late final GiftCatalogAudioPreview _giftAudioPreview;

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  bool get _canSend {
    if (!widget.canSendToHost) return false;
    final receiverId = widget.receiverId?.trim() ?? '';
    final hasAuction = widget.auctionId?.trim().isNotEmpty == true;
    final hasPost = widget.postId?.trim().isNotEmpty == true;
    final hasLive = widget.liveId?.trim().isNotEmpty == true;
    if (hasAuction) return receiverId.isNotEmpty || hasLive;
    if (hasLive) return receiverId.isNotEmpty;
    if (receiverId.isEmpty) return false;
    return hasPost || receiverId.isNotEmpty;
  }

  GiftGroupEntity? get _activeGroup {
    if (_groups.isEmpty) return null;
    final index = _selectedGroupIndex.clamp(0, _groups.length - 1);
    return _groups[index];
  }

  bool get _showSongRecommendationBanner {
    final group = _activeGroup;
    if (group == null || !group.isSongsShelf) return false;
    return _selectedGift != null;
  }

  void _applyGroupCatalog(int index) {
    if (_groups.isEmpty) return;
    final safeIndex = index.clamp(0, _groups.length - 1);
    _selectedGroupIndex = safeIndex;
    _catalog = List<GiftEntity>.from(_groups[safeIndex].gifts);
    if (_selectedIndex != null && _selectedIndex! >= _catalog.length) {
      _selectedIndex = null;
    }
  }

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
    _giftAudioPreview = GiftCatalogAudioPreview(
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    _load();
  }

  @override
  void dispose() {
    _giftAudioPreview.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final groupsResult = await _getGiftGroups(NoParams());
    GiftInventoryEntity? inventory;

    if (_isLoggedIn) {
      final inventoryResult = await _getInventory(NoParams());
      inventoryResult.fold((_) => null, (data) => inventory = data);
    }

    if (!mounted) return;

    await groupsResult.fold(
      (failure) async {
        await _loadFlatCatalog(failure.message, inventory);
      },
      (groups) async {
        if (groups.isEmpty) {
          await _loadFlatCatalog(null, inventory);
          return;
        }
        setState(() {
          _groups = groups;
          _applyGroupCatalog(0);
          _inventory = inventory;
          _loading = false;
          _loadError = null;
        });
        GiftLottieCache.instance.prefetch(
          _catalog.map((gift) => gift.animationUrl),
        );
      },
    );
  }

  Future<void> _loadFlatCatalog(
    String? groupsError,
    GiftInventoryEntity? inventory,
  ) async {
    final giftsResult = await _getGifts(const GetGiftsParams());
    if (!mounted) return;

    giftsResult.fold(
      (failure) {
        setState(() {
          _loading = false;
          _loadError = groupsError ?? failure.message;
          _groups = [];
          _catalog = [];
        });
      },
      (gifts) {
        final fallbackGroup = GiftGroupEntity(
          id: 'catalog',
          name: 'Gifts',
          slug: 'gifts',
          sortOrder: 0,
          gifts: gifts,
        );
        setState(() {
          _groups = gifts.isEmpty ? [] : [fallbackGroup];
          if (_groups.isNotEmpty) {
            _applyGroupCatalog(0);
          } else {
            _catalog = [];
          }
          _inventory = inventory;
          _loading = false;
          _loadError = gifts.isEmpty ? groupsError : null;
        });
        GiftLottieCache.instance.prefetch(
          gifts.map((gift) => gift.animationUrl),
        );
      },
    );
  }

  void _selectGroup(int index) {
    if (index == _selectedGroupIndex || index < 0 || index >= _groups.length) {
      return;
    }
    unawaited(_giftAudioPreview.stop());
    setState(() {
      _applyGroupCatalog(index);
      _selectedIndex = null;
    });
    GiftLottieCache.instance.prefetch(
      _catalog.map((gift) => gift.animationUrl),
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
    await context.push('/settings/wallet?tab=0');
    if (!mounted) return;
    await _load();
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

  Future<void> _giftSendTaskChain = Future.value();

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

    final isSmallGift = !gift.isAudioGift && gift.size == GiftCatalogSize.small;

    // Small gifts: keep sheet open, no loading spinner — same as suggested shelf.
    if (isSmallGift) {
      // Instant combo card — do not wait for socket.
      widget.onSmallGiftOptimistic?.call(gift);
      _giftSendTaskChain = _giftSendTaskChain
          .then((_) async {
            if (!mounted) return;
            await _sendSmallGiftKeepOpen(gift);
          })
          .catchError((Object err) {
            if (mounted) {
              PopupDialogs.showErrorDialog(context, err.toString());
            }
          });
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

    final receiverId = widget.receiverId?.trim() ?? '';
    if (receiverId.isEmpty) {
      PopupDialogs.showErrorDialog(
        context,
        AppLocalizations.of(context)!.liveGiftNoRecipient,
      );
      setState(() => _busy = false);
      return;
    }

    final auctionId = widget.auctionId?.trim();
    final hasAuction = auctionId != null && auctionId.isNotEmpty;
    final postId = widget.postId?.trim();
    final hasPost = postId != null && postId.isNotEmpty;
    final liveId = widget.liveId?.trim();
    final hasLive = liveId != null && liveId.isNotEmpty;

    // Prefer socket sendGift for live/auction (qty 1); HTTP for post gifts / offline.
    if (hasLive || hasAuction) {
      final socket = auctions_di.sl<AuctionSocketService>();
      await socket.ensureJoined(
        postId: hasPost ? postId : null,
        auctionId: hasAuction ? auctionId : null,
        liveId: hasLive ? liveId : null,
      );
      final socketResult = await socket.sendGift(
        giftId: gift.id,
        liveId: hasLive ? liveId : null,
        auctionId: hasAuction ? auctionId : null,
        quantity: 1,
        receiverId: receiverId,
      );

      if (socketResult != null) {
        if (!mounted) return;
        if (!socketResult.isSuccess) {
          setState(() => _busy = false);
          PopupDialogs.showErrorDialog(
            context,
            socketResult.errorMessage ?? 'Failed to send gift',
          );
          return;
        }

        final invGiftId = socketResult.inventoryGiftId ?? gift.id;
        final invQty = socketResult.inventoryQuantity;
        if (invQty != null) {
          _applyInventoryUpdate(
            GiftInventoryModel(
              balanceCoins: _inventory?.balanceCoins ?? 0,
              items: [
                GiftInventoryItemModel(giftId: invGiftId, quantity: invQty),
              ],
            ),
          );
        }
        final inventoryResult = await _getInventory(NoParams());
        if (!mounted) return;
        inventoryResult.fold((_) {}, _applyInventoryUpdate);

        if (!mounted) return;
        setState(() => _busy = false);
        final onSent = widget.onGiftSent;
        Navigator.of(context).pop();
        // Medium/large video from auctionGiftCombo; refresh totals/comments only.
        onSent?.call(gift);
        return;
      }
    }

    final result = await _sendGift(
      SendGiftParams(
        giftId: gift.id,
        receiverId: receiverId,
        quantity: 1,
        postId: hasPost ? postId : null,
        auctionId: hasAuction ? auctionId : null,
        liveId: hasLive ? liveId : null,
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
        }
        final inventoryResult = await _getInventory(NoParams());
        if (!mounted) return;
        inventoryResult.fold((_) {}, _applyInventoryUpdate);

        if (!mounted) return;
        setState(() => _busy = false);
        final onSent = widget.onGiftSent;
        Navigator.of(context).pop();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        onSent?.call(gift);
      },
    );
  }

  /// Fire-and-forget small gift: socket only, sheet stays open, no busy spinner.
  Future<void> _sendSmallGiftKeepOpen(GiftEntity gift) async {
    final needsPurchase = _ownedQuantity(gift.id) < 1;
    if (needsPurchase) {
      if (!_canAfford(gift)) {
        if (mounted) await _offerTopUp();
        return;
      }
      final purchased = await _purchaseGiftInternal(gift);
      if (!purchased || !mounted) return;
    }

    final receiverId = widget.receiverId?.trim() ?? '';
    if (receiverId.isEmpty) {
      if (mounted) {
        PopupDialogs.showErrorDialog(
          context,
          AppLocalizations.of(context)!.liveGiftNoRecipient,
        );
      }
      return;
    }

    final auctionId = widget.auctionId?.trim();
    final hasAuction = auctionId != null && auctionId.isNotEmpty;
    final postId = widget.postId?.trim();
    final hasPost = postId != null && postId.isNotEmpty;
    final liveId = widget.liveId?.trim();
    final hasLive = liveId != null && liveId.isNotEmpty;

    if (hasLive || hasAuction) {
      final socket = auctions_di.sl<AuctionSocketService>();
      await socket.ensureJoined(
        postId: hasPost ? postId : null,
        auctionId: hasAuction ? auctionId : null,
        liveId: hasLive ? liveId : null,
      );
      final socketResult = await socket.sendGift(
        giftId: gift.id,
        liveId: hasLive ? liveId : null,
        auctionId: hasAuction ? auctionId : null,
        quantity: 1,
        receiverId: receiverId,
      );

      if (socketResult != null) {
        if (!mounted) return;
        if (!socketResult.isSuccess) {
          PopupDialogs.showErrorDialog(
            context,
            socketResult.errorMessage ?? 'Failed to send gift',
          );
          return;
        }

        final invGiftId = socketResult.inventoryGiftId ?? gift.id;
        final invQty = socketResult.inventoryQuantity;
        if (invQty != null) {
          _applyInventoryUpdate(
            GiftInventoryModel(
              balanceCoins: _inventory?.balanceCoins ?? 0,
              items: [
                GiftInventoryItemModel(giftId: invGiftId, quantity: invQty),
              ],
            ),
          );
        } else {
          final inventoryResult = await _getInventory(NoParams());
          if (!mounted) return;
          inventoryResult.fold((_) {}, _applyInventoryUpdate);
        }
        // Keep sheet open — combo card comes from auctionGiftCombo.
        widget.onGiftSent?.call(gift);
        return;
      }
    }

    final result = await _sendGift(
      SendGiftParams(
        giftId: gift.id,
        receiverId: receiverId,
        quantity: 1,
        postId: hasPost ? postId : null,
        auctionId: hasAuction ? auctionId : null,
        liveId: hasLive ? liveId : null,
      ),
    );
    if (!mounted) return;

    await result.fold(
      (failure) async {
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
        widget.onGiftSent?.call(gift);
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
            if (_showSongRecommendationBanner)
              _SongRecommendationBanner(
                gift: _selectedGift!,
                isSpinning: _giftAudioPreview.isActiveGift(_selectedGift!.id),
              )
            else
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
              groups: _groups,
              selectedGroupIndex: _selectedGroupIndex,
              onGroupSelected: _selectGroup,
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
    return _buildGrid(l10n);
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
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: LiveDetailsLayoutConstants.giftGridCrossCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: ordered.length,
      itemBuilder: (context, index) {
        final gift = ordered[index];
        final audioPlaying =
            gift.isAudioGift &&
            _selectedIndex == index &&
            _giftAudioPreview.isPlayingGift(gift.id);
        final audioPaused =
            gift.isAudioGift &&
            _selectedIndex == index &&
            _giftAudioPreview.isPausedGift(gift.id);
        return _GiftTile(
          gift: gift,
          isSelected: _selectedIndex == index,
          isAudioSpinning: audioPlaying,
          isAudioPaused: audioPaused,
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
                  if (gift.isAudioGift) {
                    if (_giftAudioPreview.isActiveGift(gift.id)) {
                      unawaited(_giftAudioPreview.toggleGift(gift));
                    } else {
                      unawaited(_giftAudioPreview.playGift(gift));
                    }
                  } else {
                    unawaited(_giftAudioPreview.stop());
                  }
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

class _SongRecommendationBanner extends StatelessWidget {
  const _SongRecommendationBanner({
    required this.gift,
    this.isSpinning = false,
  });

  final GiftEntity gift;
  final bool isSpinning;

  @override
  Widget build(BuildContext context) {
    final ring = giftAccentColor(gift.color);
    final subtitleStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.55),
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.15,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Material(
        color: ring.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              isSpinning
                  ? SpinningGiftVinylRecordIcon(
                      gift: gift,
                      spinning: true,
                      size: 44,
                      isSelected: true,
                      showPauseIcon: true,
                    )
                  : GiftVinylRecordIcon(gift: gift, size: 40, isSelected: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gift.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.soundFindRelatedHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: subtitleStyle,
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
    required this.isAudioSpinning,
    required this.isAudioPaused,
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
  final bool isAudioSpinning;
  final bool isAudioPaused;
  final bool isPinned;
  final int owned;
  final bool busy;
  final Color accent;
  final String sendLabel;
  final VoidCallback? onSelect;
  final VoidCallback? onSend;

  static const double _footerSlotHeight = 24;
  static const double _metaSlotHeight = 18;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final priceStyle = TextStyle(
      color: Colors.white.withValues(alpha: isSelected ? 0.95 : 0.75),
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );

    final isAudio = gift.isAudioGift;

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        clipBehavior: Clip.none,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF26262A) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Transform.translate(
                        offset: isSelected && !isAudio
                            ? const Offset(0, -6)
                            : Offset.zero,
                        child: isAudio
                            ? AnimatedScale(
                                scale: !isSelected
                                    ? 1.0
                                    : isAudioSpinning
                                    ? 1.22
                                    : 1.08,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutBack,
                                child: _GiftIcon(
                                  gift: gift,
                                  isSelected: isSelected,
                                  isAudioSpinning: isAudioSpinning,
                                  isAudioPaused: isAudioPaused,
                                  size: isSelected && isAudioSpinning ? 68 : 62,
                                ),
                              )
                            : AnimatedRotation(
                                turns: isSelected ? (-15 / 360) : 0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                child: AnimatedScale(
                                  scale: isSelected ? 1.18 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutBack,
                                  child: _GiftIcon(
                                    gift: gift,
                                    isSelected: isSelected,
                                    isAudioSpinning: false,
                                    size: 70,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _metaSlotHeight,
                    child: Center(
                      child: isSelected
                          ? AppCoinAmount(
                              iconSize: 13,
                              spacing: 3,
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
                              iconSize: 13,
                              spacing: 3,
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
              )
            else if (gift.tag != null)
              Positioned(top: 4, left: 4, child: _GiftTagBadge(tag: gift.tag!)),
          ],
        ),
      ),
    );
  }
}

class _GiftTagBadge extends StatelessWidget {
  const _GiftTagBadge({required this.tag});

  final GiftCatalogTag tag;

  @override
  Widget build(BuildContext context) {
    final label = switch (tag) {
      GiftCatalogTag.newBadge => 'NEW',
      GiftCatalogTag.recent => 'RECENT',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFE2C55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.groups,
    required this.selectedGroupIndex,
    required this.onGroupSelected,
    required this.onRecharge,
    required this.balanceCoins,
    required this.loadingBalance,
    required this.bottomInset,
  });

  final List<GiftGroupEntity> groups;
  final int selectedGroupIndex;
  final ValueChanged<int> onGroupSelected;
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if (groups.isEmpty)
                    _TabChip(
                      label: l10n.liveGiftTabGifts,
                      selected: true,
                      onTap: () {},
                    )
                  else
                    for (var i = 0; i < groups.length; i++)
                      _TabChip(
                        label: giftGroupTabLabel(groups[i], l10n),
                        selected: i == selectedGroupIndex,
                        onTap: () => onGroupSelected(i),
                      ),
                ],
              ),
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
  const _GiftIcon({
    required this.gift,
    required this.isSelected,
    this.isAudioSpinning = false,
    this.isAudioPaused = false,
    this.size,
  });

  final GiftEntity gift;
  final bool isSelected;
  final bool isAudioSpinning;
  final bool isAudioPaused;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? (isSelected ? 52.0 : 46.0);
    if (gift.isAudioGift) {
      if (isAudioSpinning) {
        return SpinningGiftVinylRecordIcon(
          gift: gift,
          spinning: true,
          size: iconSize,
          isSelected: isSelected,
          showPauseIcon: isSelected,
        );
      }
      return GiftVinylRecordIcon(
        gift: gift,
        size: iconSize,
        isSelected: isSelected,
        showPlayIcon: isSelected && isAudioPaused,
      );
    }
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
      if (icon.toLowerCase().endsWith('.svg')) {
        return SvgPicture.asset(
          icon,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        );
      }
      return Image.asset(
        icon,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          LucideIcons.gift,
          size: iconSize * 0.85,
          color: Colors.white70,
        ),
      );
    }
    return Text(icon, style: TextStyle(fontSize: iconSize));
  }
}
