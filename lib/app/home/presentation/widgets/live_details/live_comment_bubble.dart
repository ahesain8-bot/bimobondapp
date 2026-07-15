import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style live comment pill (compact padding, soft dark capsule).
class LiveCommentBubble extends StatelessWidget {
  const LiveCommentBubble({
    required this.isRtl,
    required this.displayName,
    this.avatarUrl,
    this.userId,
    required this.body,
    required this.isGift,
    this.giftImageUrl,
    this.onProfileTap,
  });

  final bool isRtl;
  final String displayName;
  final String? avatarUrl;
  final String? userId;
  final String body;
  final bool isGift;
  final String? giftImageUrl;
  final VoidCallback? onProfileTap;

  Color get _giftNameColor => LiveDetailsLayoutConstants.giftCommentGold
      .withValues(alpha: LiveDetailsLayoutConstants.giftCommentContentOpacity);

  Color get _giftBodyColor => LiveDetailsLayoutConstants.giftCommentGoldText
      .withValues(alpha: LiveDetailsLayoutConstants.giftCommentContentOpacity);

  @override
  Widget build(BuildContext context) {
    final nameRecognizer = onProfileTap != null
        ? (TapGestureRecognizer()..onTap = onProfileTap)
        : null;
    final giftImage = giftImageUrl?.trim();
    final hasGiftImage = giftImage != null && giftImage.isNotEmpty;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
        decoration: BoxDecoration(
          color: isGift
              ? LiveDetailsLayoutConstants.giftCommentGoldDeep.withValues(
                  alpha: 0.28,
                )
              : Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(14),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: isRtl ? 0 : 5,
                    start: isRtl ? 5 : 0,
                  ),
                  child: StoryProfileAvatar(
                    userId: userId,
                    imageUrl: avatarUrl,
                    radius: 10,
                    fallbackText: displayName,
                    onTap: onProfileTap,
                  ),
                ),
              ),
              if (isGift && !hasGiftImage)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: isRtl ? 0 : 4,
                      start: isRtl ? 4 : 0,
                    ),
                    child: Icon(
                      LucideIcons.gift,
                      size: 12,
                      color: _giftNameColor,
                    ),
                  ),
                ),
              TextSpan(
                text: '$displayName ',
                recognizer: nameRecognizer,
                style: TextStyle(
                  color: isGift
                      ? _giftNameColor
                      : Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
              TextSpan(
                text: body,
                style: TextStyle(
                  color: isGift
                      ? _giftBodyColor
                      : Colors.white.withValues(alpha: 0.88),
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isGift && hasGiftImage)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: isRtl ? 0 : AppSizes.p4,
                      end: isRtl ? AppSizes.p4 : 0,
                    ),
                    child: SafeNetworkImage(
                      imageUrl: giftImage,
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
