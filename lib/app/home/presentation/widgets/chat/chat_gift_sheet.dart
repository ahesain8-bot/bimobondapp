import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_inventory_usecase.dart';
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatGiftPickResult {
  const ChatGiftPickResult({
    required this.giftId,
    this.name,
    this.thumbnailUrl,
  });

  final String giftId;
  final String? name;
  final String? thumbnailUrl;
}

class ChatGiftSheet {
  ChatGiftSheet._();

  static Future<ChatGiftPickResult?> show(BuildContext context) {
    return GlassBottomSheet.open<ChatGiftPickResult>(
      context,
      isScrollControlled: true,
      builder: (_) => const _ChatGiftSheetBody(),
    );
  }
}

class _ChatGiftSheetBody extends StatefulWidget {
  const _ChatGiftSheetBody();

  @override
  State<_ChatGiftSheetBody> createState() => _ChatGiftSheetBodyState();
}

class _ChatGiftSheetBodyState extends State<_ChatGiftSheetBody> {
  final _getInventory = gifts_di.sl<GetGiftInventoryUseCase>();

  bool _loading = true;
  String? _error;
  List<GiftInventoryItemEntity> _items = const [];

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
    final result = await _getInventory(NoParams());
    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() {
          _loading = false;
          _error = failure.message;
          _items = const [];
        });
      },
      (inventory) {
        setState(() {
          _loading = false;
          _items = inventory.items.where((e) => e.quantity > 0).toList();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.chatGiftSheetTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.p4),
            Text(
              l10n.chatGiftSheetSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSizes.p16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: AppSizes.p12),
                    TextButton(onPressed: _load, child: Text(l10n.notificationsRetry)),
                  ],
                ),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.gift,
                      size: 40,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    Text(
                      l10n.chatGiftInventoryEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 280,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final gift = item.gift;
                    final name = gift?.name ?? l10n.chatMoreGift;
                    final image = gift?.imageUrl?.trim().isNotEmpty == true
                        ? gift!.imageUrl
                        : (gift != null && gift.hasNetworkIcon ? gift.icon : null);
                    final resolved = image != null && image.isNotEmpty
                        ? MediaUtils.resolveAbsoluteUrl(image)
                        : null;

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(
                          context,
                          ChatGiftPickResult(
                            giftId: item.giftId,
                            name: gift?.name,
                            thumbnailUrl: resolved,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.55),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: resolved != null
                                  ? SafeNetworkImage(
                                      imageUrl: resolved,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      LucideIcons.gift,
                                      color: theme.colorScheme.primary,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                          Text(
                            '×${item.quantity}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
