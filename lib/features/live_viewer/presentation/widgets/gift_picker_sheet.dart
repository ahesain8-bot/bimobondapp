import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/gift_entity.dart';
import '../providers/live_dependencies.dart';
import 'gift_icon.dart';

class GiftPickerSheet extends ConsumerStatefulWidget {
  final int coinBalance;
  final ValueChanged<GiftEntity> onGiftSelected;

  const GiftPickerSheet({
    super.key,
    required this.coinBalance,
    required this.onGiftSelected,
  });

  @override
  ConsumerState<GiftPickerSheet> createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends ConsumerState<GiftPickerSheet> {
  List<GiftEntity> _gifts = const [];
  bool _loading = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ref.read(giftRepositoryProvider).getAllGifts();
    if (!mounted) return;
    result.fold((_) {
      setState(() => _loading = false);
    }, (gifts) {
      setState(() {
        _gifts = gifts;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.55 + bottom * 0.2,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(
                  'Gifts',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.monetization_on,
                    color: AppColors.coinGold, size: 16),
                const SizedBox(width: 3),
                Text(
                  '${widget.coinBalance}',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.coinGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.coinGold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Recharge',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.coinGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFE2C55),
                      strokeWidth: 2,
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.82,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _gifts.length,
                    itemBuilder: (context, index) {
                      final gift = _gifts[index];
                      final selected = _selectedId == gift.id;
                      final canAfford = widget.coinBalance >= gift.coinCost;
                      return GestureDetector(
                        onTap: canAfford
                            ? () {
                                setState(() => _selectedId = gift.id);
                                widget.onGiftSelected(gift);
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          decoration: BoxDecoration(
                            color: selected
                                ? gift.rarity.color.withValues(alpha: 0.16)
                                : const Color(0xFF222222),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? gift.rarity.color
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Opacity(
                            opacity: canAfford ? 1 : 0.38,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GiftIcon(gift: gift, size: 34)
                                    .animate(target: selected ? 1 : 0)
                                    .scale(
                                      begin: const Offset(1, 1),
                                      end: const Offset(1.12, 1.12),
                                    ),
                                const SizedBox(height: 3),
                                Text(
                                  gift.name,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.monetization_on,
                                        size: 10, color: AppColors.coinGold),
                                    const SizedBox(width: 1),
                                    Text(
                                      '${gift.coinCost}',
                                      style: AppTextStyles.coinAmount.copyWith(
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
