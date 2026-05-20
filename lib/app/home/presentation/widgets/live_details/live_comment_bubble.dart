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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p12,
        vertical: AppSizes.p6,
      ),
      decoration: BoxDecoration(
        gradient: isGift
            ? LinearGradient(
                colors: [
                  LiveDetailsLayoutConstants.giftCommentGoldDeep.withValues(
                    alpha:
                        LiveDetailsLayoutConstants.giftCommentFillOpacityDeep,
                  ),
                  LiveDetailsLayoutConstants.giftCommentGold.withValues(
                    alpha:
                        LiveDetailsLayoutConstants.giftCommentFillOpacityLight,
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isGift ? null : Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(
          LiveDetailsLayoutConstants.chatBubbleRadius,
        ),
        border: Border.all(
          color: isGift
              ? LiveDetailsLayoutConstants.giftCommentGold.withValues(
                  alpha: LiveDetailsLayoutConstants.giftCommentBorderOpacity,
                )
              : Colors.white.withValues(alpha: 0.08),
          width: isGift ? 1.2 : 1,
        ),
        boxShadow: isGift
            ? [
                BoxShadow(
                  color: LiveDetailsLayoutConstants.giftCommentGoldDeep
                      .withValues(
                        alpha:
                            LiveDetailsLayoutConstants.giftCommentGlowOpacity,
                      ),
                  blurRadius: 10,
                  spreadRadius: 0.5,
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
                    size: 14,
                    color: _giftNameColor,
                  ),
                ),
              ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: isRtl ? 0 : AppSizes.p6,
                  start: isRtl ? AppSizes.p6 : 0,
                ),
                child: CircleAvatar(
                  radius: LiveDetailsLayoutConstants.chatAvatarRadius,
                  backgroundColor: isGift
                      ? LiveDetailsLayoutConstants.giftCommentGoldDeep
                            .withValues(
                              alpha: LiveDetailsLayoutConstants
                                  .giftCommentAvatarFillOpacity,
                            )
                      : null,
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
                            color: isGift ? _giftBodyColor : null,
                          ),
                        )
                      : null,
                ),
              ),
            ),

            TextSpan(
              text: '$displayName  ',
              style: TextStyle(
                color: isGift
                    ? _giftNameColor
                    : theme.colorScheme.primary.withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            TextSpan(
              text: body,
              style: TextStyle(
                color: isGift ? _giftBodyColor : Colors.white,
                fontSize: 13,
                height: 1.35,
                fontWeight: isGift ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
