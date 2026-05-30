import 'dart:ui';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LiveCommentBubble extends StatelessWidget {
  const LiveCommentBubble({
    required this.isRtl,
    required this.displayName,
    this.avatarUrl,
    required this.body,
    required this.isGift,
    required this.theme,
  });

  final bool isRtl;
  final String displayName;
  final String? avatarUrl;
  final String body;
  final bool isGift;
  final ThemeData theme;

  Color get _giftNameColor => LiveDetailsLayoutConstants.giftCommentGold
      .withValues(alpha: LiveDetailsLayoutConstants.giftCommentContentOpacity);

  Color get _giftBodyColor => LiveDetailsLayoutConstants.giftCommentGoldText
      .withValues(alpha: LiveDetailsLayoutConstants.giftCommentContentOpacity);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p12,
            vertical: AppSizes.p8,
          ),
          decoration: BoxDecoration(
            gradient: isGift
                ? LinearGradient(
                    colors: [
                      LiveDetailsLayoutConstants.giftCommentGoldDeep.withValues(
                        alpha: 0.35,
                      ),
                      LiveDetailsLayoutConstants.giftCommentGold.withValues(
                        alpha: 0.15,
                      ),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.black.withValues(alpha: 0.3),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isGift
                  ? LiveDetailsLayoutConstants.giftCommentGold.withValues(
                      alpha: 0.8,
                    )
                  : Colors.white.withValues(alpha: 0.1),
              width: isGift ? 1.5 : 1,
            ),
            boxShadow: isGift
                ? [
                    BoxShadow(
                      color: LiveDetailsLayoutConstants.giftCommentGoldDeep
                          .withValues(
                            alpha: 0.4,
                          ),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: RichText(
            text: TextSpan(
              children: [
                if (isGift)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: isRtl ? 0 : AppSizes.p6,
                        start: isRtl ? AppSizes.p6 : 0,
                      ),
                      child: Icon(
                        LucideIcons.gift,
                        size: 16,
                        color: _giftNameColor,
                      ),
                    ),
                  ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: isRtl ? 0 : AppSizes.p8,
                      start: isRtl ? AppSizes.p8 : 0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isGift 
                            ? _giftNameColor.withValues(alpha: 0.8) 
                            : Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: isGift
                            ? LiveDetailsLayoutConstants.giftCommentGoldDeep
                                  .withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.1),
                        backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                            ? NetworkImage(MediaUtils.resolveAbsoluteUrl(avatarUrl!))
                            : null,
                        child: avatarUrl == null || avatarUrl!.isEmpty
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isGift ? _giftBodyColor : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                TextSpan(
                  text: '$displayName  ',
                  style: TextStyle(
                    color: isGift
                        ? _giftNameColor
                        : theme.colorScheme.primary.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: body,
                  style: TextStyle(
                    color: isGift ? _giftBodyColor : Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: isGift ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
