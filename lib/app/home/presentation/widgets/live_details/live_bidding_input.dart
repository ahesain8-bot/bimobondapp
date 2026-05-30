import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/quick_bid_chip.dart';

class LiveBiddingInput extends StatelessWidget {
  const LiveBiddingInput({
    required this.controller,
    required this.hintText,
    this.enabled = true,
    this.showGiftButton = true,
    required this.quickBidAmounts,
    required this.quickBidLabelBuilder,
    required this.theme,
    required this.onSend,
    required this.onGift,
    required this.onQuickBid,
  });

  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final bool showGiftButton;
  final List<int> quickBidAmounts;
  final String Function(int amount) quickBidLabelBuilder;
  final ThemeData theme;
  final VoidCallback onSend;
  final VoidCallback onGift;
  final ValueChanged<int> onQuickBid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: LiveDetailsLayoutConstants.inputPadding,
      child: Column(
        children: [
          if (quickBidAmounts.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (var i = 0; i < quickBidAmounts.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSizes.p8),
                    QuickBidChip(
                      amount: quickBidAmounts[i],
                      label: quickBidLabelBuilder(quickBidAmounts[i]),
                      onTap: () => onQuickBid(quickBidAmounts[i]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSizes.p12),
          ],
          Row(
            children: [
              if (showGiftButton) ...[
                GestureDetector(
                  onTap: onGift,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF3366), Color(0xFFFF9933)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3366).withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.gift,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.p12),
              ],
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: Icon(
                                LucideIcons.smile,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 22,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                enabled: enabled,
                                readOnly: !enabled,
                                style: TextStyle(
                                  color: enabled
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.4),
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: hintText,
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.only(
                                    bottom: AppSizes.p4,
                                  ),
                                ),
                                onSubmitted: (_) => onSend(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p12),
              GestureDetector(
                onTap: enabled ? onSend : null,
                child: Opacity(
                  opacity: enabled ? 1 : 0.45,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.5,
                          ),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
