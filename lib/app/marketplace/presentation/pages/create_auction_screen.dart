import 'package:bimobondapp/app/auctions/domain/entities/create_auction_input.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/create_auction_usecase.dart';
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_badges.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/price_display.dart';
import 'package:bimobondapp/app/shop/presentation/widgets/shop_back_button.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreateAuctionScreen extends StatefulWidget {
  const CreateAuctionScreen({
    required this.productId,
    required this.title,
    required this.purchasePriceCoins,
    this.imageUrl,
    super.key,
  });

  static const routeName = 'marketplace_create_auction';

  final String productId;
  final String title;
  final int purchasePriceCoins;
  final String? imageUrl;

  @override
  State<CreateAuctionScreen> createState() => _CreateAuctionScreenState();
}

class _CreateAuctionScreenState extends State<CreateAuctionScreen> {
  final CreateAuctionUseCase _createAuction = auctions_di.sl();
  final _startingController = TextEditingController();
  final _reserveController = TextEditingController();
  final _buyNowController = TextEditingController();
  final _descriptionController = TextEditingController();

  Duration _duration = const Duration(hours: 24);
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final base = (widget.purchasePriceCoins * 0.85).round();
    _startingController.text = '$base';
    _reserveController.text = '${widget.purchasePriceCoins}';
    _buyNowController.text = '${(widget.purchasePriceCoins * 1.15).round()}';
  }

  @override
  void dispose() {
    _startingController.dispose();
    _reserveController.dispose();
    _buyNowController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final starting = double.tryParse(_startingController.text.trim());
    if (starting == null || starting <= 0) return;

    setState(() => _submitting = true);
    final now = DateTime.now().toUtc();
    final result = await _createAuction(
      CreateAuctionInput(
        targetPrice: starting,
        startingPrice: starting,
        itemName: widget.title,
        itemImageUrl: widget.imageUrl,
        startedAt: now,
        endedAt: now.add(_duration),
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMessageResolver.resolve(f))),
      ),
      (auction) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.marketplaceAuctionPublished),
          ),
        );
        context.pop(auction.id);
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
            l10n.marketplaceSellAtAuction,
            style: TextStyle(
              color: theme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: theme.cardDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(MarketplaceTheme.radiusSm),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: SafeNetworkImage(
                            imageUrl: widget.imageUrl,
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
                              widget.title,
                              style: TextStyle(
                                color: theme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.marketplacePurchasePrice,
                              style: TextStyle(color: theme.mutedText, fontSize: 12),
                            ),
                            PriceDisplay(
                              priceCoins: widget.purchasePriceCoins,
                              size: PriceDisplaySize.small,
                            ),
                            const SizedBox(height: 6),
                            const OwnershipBadge(),
                            const SizedBox(height: 4),
                            DeliveryStatusChip(
                              status: l10n.marketplaceDeliveryPending,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _field(l10n.marketplaceStartingPrice, _startingController, theme),
              const SizedBox(height: 12),
              _field(l10n.marketplaceReservePrice, _reserveController, theme),
              const SizedBox(height: 12),
              _field(l10n.marketplaceBuyNowPrice, _buyNowController, theme),
              const SizedBox(height: 16),
              Text(
                l10n.marketplaceAuctionDuration,
                style: TextStyle(
                  color: theme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _durationChip(const Duration(hours: 1), '1h', theme),
                  _durationChip(const Duration(hours: 6), '6h', theme),
                  _durationChip(const Duration(hours: 12), '12h', theme),
                  _durationChip(const Duration(hours: 24), '24h', theme),
                  _durationChip(const Duration(days: 3), '3d', theme),
                  _durationChip(const Duration(days: 7), '7d', theme),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.marketplaceDescription,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.marketplaceAuctionPreview,
                style: TextStyle(
                  color: theme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: theme.cardDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        '${l10n.marketplaceStartingPrice}: ${_startingController.text}',
                      ),
                      Text('${l10n.marketplaceAuctionDuration}: ${_formatDuration(_duration)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _publish,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.marketplacePublishAuction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    MarketplaceTheme theme,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _durationChip(Duration d, String label, MarketplaceTheme theme) {
    final selected = _duration == d;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _duration = d),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d';
    return '${d.inHours}h';
  }
}
