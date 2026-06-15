import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/get_auction_details_usecase.dart';
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionGiftsSheet {
  AuctionGiftsSheet._();

  static Future<void> show(
    BuildContext context, {
    required String auctionId,
  }) {
    return GlassBottomSheet.open<void>(
      context,
      isScrollControlled: true,
      builder: (_) => _AuctionGiftsSheetBody(auctionId: auctionId),
    );
  }
}

class _AuctionGiftsSheetBody extends StatefulWidget {
  const _AuctionGiftsSheetBody({required this.auctionId});

  final String auctionId;

  @override
  State<_AuctionGiftsSheetBody> createState() => _AuctionGiftsSheetBodyState();
}

class _AuctionGiftsSheetBodyState extends State<_AuctionGiftsSheetBody> {
  final _getAuctionDetails = auctions_di.sl<GetAuctionDetailsUseCase>();

  AuctionDetailsEntity? _details;
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

    final result = await _getAuctionDetails(
      GetAuctionDetailsParams(auctionId: widget.auctionId),
    );
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (details) => setState(() {
        _details = details;
        _loading = false;
      }),
    );
  }

  String _formatUsd(double amount, Locale locale) {
    final text = amount == amount.roundToDouble()
        ? amount.round().toString()
        : amount.toStringAsFixed(2);
    return LocaleFormatUtils.localizeDigits(text, locale);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final details = _details;

    return GlassBottomSheetFrame(
      showHandle: true,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: AppSizes.p4),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.gift,
                      color: LiveDetailsLayoutConstants.giftCommentGold,
                      size: 22,
                    ),
                    const SizedBox(width: AppSizes.p8),
                    Expanded(
                      child: Text(
                        l10n.auctionGiftsTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              if (details != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.p24,
                    vertical: AppSizes.p8,
                  ),
                  child: _AuctionGiftsSummaryBar(
                    itemName: details.itemName,
                    summary: l10n.auctionGiftsSummary(
                      _formatUsd(details.currentTotalUsd, locale),
                      _formatUsd(details.targetPriceUsd, locale),
                      l10n.currencyUsd,
                    ),
                  ),
                ),
              ],
              Expanded(child: _buildBody(l10n, locale)),
            ],
          ),
        ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, Locale locale) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p20,
          vertical: AppSizes.p8,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: AppSizes.p12),
          child: _AuctionGiftRowSkeleton(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
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

    final transactions = _details?.giftTransactions ?? [];
    if (transactions.isEmpty) {
      return Center(
        child: Text(
          l10n.auctionGiftsEmpty,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    final sorted = [...transactions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p20,
        AppSizes.p8,
        AppSizes.p20,
        AppSizes.p24,
      ),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.p10),
      itemBuilder: (context, index) {
        return _AuctionGiftTransactionTile(
          transaction: sorted[index],
          locale: locale,
          contributionLabel: (amount) => l10n.auctionGiftsContribution(
            amount,
            l10n.currencyUsd,
          ),
        );
      },
    );
  }
}

class _AuctionGiftsSummaryBar extends StatelessWidget {
  const _AuctionGiftsSummaryBar({
    required this.itemName,
    required this.summary,
  });

  final String itemName;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LiveDetailsLayoutConstants.giftCommentGoldDeep
                .withValues(alpha: 0.5),
            LiveDetailsLayoutConstants.giftCommentGold.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LiveDetailsLayoutConstants.giftCommentGold.withValues(
            alpha: 0.6,
          ),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: LiveDetailsLayoutConstants.giftCommentGoldDeep.withValues(
              alpha: 0.25,
            ),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            itemName,
            style: const TextStyle(
              color: LiveDetailsLayoutConstants.giftCommentGoldText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSizes.p4),
          Text(
            summary,
            style: const TextStyle(
              color: LiveDetailsLayoutConstants.giftCommentGold,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuctionGiftTransactionTile extends StatelessWidget {
  const _AuctionGiftTransactionTile({
    required this.transaction,
    required this.locale,
    required this.contributionLabel,
  });

  final AuctionGiftTransactionEntity transaction;
  final Locale locale;
  final String Function(String amount) contributionLabel;

  @override
  Widget build(BuildContext context) {
    final sender = transaction.sender;
    final gift = transaction.gift;
    final senderName = (sender.fullName?.trim().isNotEmpty == true
            ? sender.fullName!.trim()
            : sender.username) ??
        'User';
    final thumb = gift.thumbnailUrl;
    final contribution = transaction.contributionUsd == transaction.contributionUsd.roundToDouble()
        ? transaction.contributionUsd.round().toString()
        : transaction.contributionUsd.toStringAsFixed(2);
    final localizedContribution =
        LocaleFormatUtils.localizeDigits(contribution, locale);

    return Container(
      padding: const EdgeInsets.all(AppSizes.p12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: LiveDetailsLayoutConstants.giftCommentGoldDeep
                .withValues(alpha: 0.5),
            backgroundImage: sender.avatarUrl != null &&
                    sender.avatarUrl!.isNotEmpty
                ? NetworkImage(MediaUtils.resolveAbsoluteUrl(sender.avatarUrl!))
                : null,
            child: sender.avatarUrl == null || sender.avatarUrl!.isEmpty
                ? Text(
                    senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: LiveDetailsLayoutConstants.giftCommentGoldText,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSizes.p10),
          _GiftThumbnail(url: thumb),
          const SizedBox(width: AppSizes.p10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senderName,
                  style: const TextStyle(
                    color: LiveDetailsLayoutConstants.giftCommentGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  gift.name,
                  style: const TextStyle(
                    color: LiveDetailsLayoutConstants.giftCommentGoldText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            contributionLabel(localizedContribution),
            style: const TextStyle(
              color: LiveDetailsLayoutConstants.giftCommentGold,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftThumbnail extends StatelessWidget {
  const _GiftThumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: LiveDetailsLayoutConstants.giftCommentGold.withValues(
            alpha: 0.4,
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? Image.network(
              MediaUtils.resolveAbsoluteUrl(url!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                LucideIcons.gift,
                color: LiveDetailsLayoutConstants.giftCommentGold,
                size: 20,
              ),
            )
          : const Icon(
              LucideIcons.gift,
              color: LiveDetailsLayoutConstants.giftCommentGold,
              size: 20,
            ),
    );
  }
}

class _AuctionGiftRowSkeleton extends StatelessWidget {
  const _AuctionGiftRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.p16),
      ),
      child: const Row(
        children: [
          SkeletonWidget.circular(size: 40),
          SizedBox(width: AppSizes.p10),
          SkeletonWidget(height: 40, width: 40, borderRadius: 10),
          SizedBox(width: AppSizes.p10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonWidget(height: 12, width: 100),
                SizedBox(height: 6),
                SkeletonWidget(height: 10, width: 72),
              ],
            ),
          ),
          SkeletonWidget(height: 12, width: 56),
        ],
      ),
    );
  }
}
