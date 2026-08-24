import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/get_auction_details_usecase.dart';
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/auction_countdown.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_buttons.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/price_display.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/shop_back_button.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MarketplaceAuctionDetailsScreen extends StatefulWidget {
  const MarketplaceAuctionDetailsScreen({
    required this.auctionId,
    super.key,
  });

  static const routeName = 'marketplace_auction_details';

  final String auctionId;

  @override
  State<MarketplaceAuctionDetailsScreen> createState() =>
      _MarketplaceAuctionDetailsScreenState();
}

class _MarketplaceAuctionDetailsScreenState
    extends State<MarketplaceAuctionDetailsScreen> {
  final GetAuctionDetailsUseCase _getDetails = auctions_di.sl();
  AuctionDetailsEntity? _auction;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _getDetails(
      GetAuctionDetailsParams(auctionId: widget.auctionId),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = ErrorMessageResolver.resolve(f);
      }),
      (details) => setState(() {
        _loading = false;
        _auction = details;
      }),
    );
  }

  void _openLiveAuction(AuctionDetailsEntity auction) {
    if (auction.postId != null && auction.postId!.isNotEmpty) {
      context.pushNamed(
        'post-detail',
        queryParameters: {'postId': auction.postId!},
      );
      return;
    }
    if (auction.liveId != null && auction.liveId!.isNotEmpty) {
      context.pushNamed(
        'live-details',
        queryParameters: {'liveId': auction.liveId!},
      );
    }
  }

  Future<void> _placeBidSheet(AuctionDetailsEntity auction) async {
    final l10n = AppLocalizations.of(context)!;
    final current = auction.displayHighestPriceCoins;
    var bid = current + 25;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = MarketplaceTheme.of(context);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(MarketplaceTheme.radiusXl),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.marketplacePlaceBid,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.marketplaceCurrentBid),
                    PriceDisplay(priceCoins: current),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.marketplaceYourBid,
                      ),
                      controller: TextEditingController(text: '$bid'),
                      onChanged: (v) => bid = int.tryParse(v) ?? bid,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [25, 50, 100].map((inc) {
                        return ActionChip(
                          label: Text('+\$$inc'),
                          onPressed: () => setSheetState(() => bid = current + inc),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openLiveAuction(auction);
                      },
                      child: Text(l10n.marketplaceConfirmBid),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
            l10n.marketplaceLiveAuction,
            style: TextStyle(
              color: theme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
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
                : _buildBody(context, _auction!, theme, l10n),
        bottomNavigationBar: _auction == null || !_auction!.isActive
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AuctionButton(
                    label: l10n.marketplacePlaceBid,
                    onPressed: () => _placeBidSheet(_auction!),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AuctionDetailsEntity auction,
    MarketplaceTheme theme,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(MarketplaceTheme.radiusLg),
            child: AspectRatio(
              aspectRatio: 1,
              child: SafeNetworkImage(
                imageUrl: auction.itemImageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            auction.itemName,
            style: TextStyle(
              color: theme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.marketplaceCurrentBid),
          PriceDisplay(
            priceCoins: auction.displayHighestPriceCoins,
            color: theme.auctionAccent,
            size: PriceDisplaySize.large,
          ),
          const SizedBox(height: 4),
          Text(l10n.marketplaceBidCount(auction.giftCount)),
          const SizedBox(height: 8),
          AuctionCountdown(
            endsAt: auction.endedAt,
            prefix: l10n.marketplaceEndsIn,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.marketplaceBidHistory,
            style: TextStyle(
              color: theme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (auction.giftTransactions.isEmpty)
            Text(l10n.marketplaceNoBidsYet)
          else
            ...auction.giftTransactions.take(10).map((tx) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tx.sender.username ?? tx.sender.fullName ?? '—'),
                trailing: PriceDisplay(
                  priceCoins: tx.contributionCoins,
                  size: PriceDisplaySize.small,
                ),
              );
            }),
        ],
      ),
    );
  }
}
