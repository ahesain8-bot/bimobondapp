import 'package:bimobondapp/app/auth/domain/entities/user_activity_entity.dart';
import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AdminActivityTypeStyle {
  AdminActivityTypeStyle._();

  static (IconData icon, Color color) forType(String type) {
    return switch (type.toUpperCase()) {
      'CREATE_POST' => (LucideIcons.video, const Color(0xFF3B82F6)),
      'COMMENT' => (
          LucideIcons.messageSquare,
          MessagesLayoutConstants.activityCommentsColor,
        ),
      'LIKE_POST' => (
          LucideIcons.heart,
          MessagesLayoutConstants.activityLikesColor,
        ),
      'SEND_GIFT' => (LucideIcons.gift, const Color(0xFFFF9500)),
      _ => (LucideIcons.activity, const Color(0xFF8E8E93)),
    };
  }
}

IconData adminActivityIcon(String type) => AdminActivityTypeStyle.forType(type).$1;

String adminActivityTypeLabel(String type, AppLocalizations l10n) {
  switch (type.toUpperCase()) {
    case 'CREATE_POST':
      return l10n.adminActivityTypeCreatePost;
    case 'COMMENT':
      return l10n.adminActivityTypeComment;
    case 'LIKE_POST':
      return l10n.adminActivityTypeLikePost;
    case 'SEND_GIFT':
      return l10n.adminActivityTypeSendGift;
    default:
      return type;
  }
}

String adminActivitySubtitle(
  UserActivityEntity activity,
  AppLocalizations l10n,
) {
  return adminActivityContent(activity, l10n).primary;
}

class AdminActivityContent {
  const AdminActivityContent({
    required this.primary,
    this.quote,
  });

  final String primary;
  final String? quote;
}

AdminActivityContent adminActivityContent(
  UserActivityEntity activity,
  AppLocalizations l10n,
) {
  final d = activity.details;
  switch (activity.type.toUpperCase()) {
    case 'CREATE_POST':
      return AdminActivityContent(
        primary: _str(d['description']) ?? l10n.adminActivityNoDetails,
      );
    case 'COMMENT':
      final content = _str(d['content']);
      final post = _str(d['postDescription']);
      final primary = post != null
          ? l10n.adminActivityOnPost(post)
          : l10n.adminActivityNoDetails;
      return AdminActivityContent(
        primary: content == null ? primary : primary,
        quote: content,
      );
    case 'LIKE_POST':
      final post = _str(d['postDescription']);
      return AdminActivityContent(
        primary: post == null ? l10n.adminActivityNoDetails : '',
        quote: post,
      );
    case 'SEND_GIFT':
      final gift = _str(d['giftName']);
      final user = _str(d['receiverUsername']);
      final price = d['priceUsd'];
      final priceStr = price is num
          ? '\$${price.toStringAsFixed(2)}'
          : _str(price);
      final parts = <String>[
        if (gift != null) gift,
        if (user != null) '@$user',
        if (priceStr != null) priceStr,
      ];
      return AdminActivityContent(
        primary: parts.isEmpty ? l10n.adminActivityNoDetails : parts.join(' · '),
      );
    default:
      return AdminActivityContent(primary: l10n.adminActivityNoDetails);
  }
}

String adminActivityTimeLabel(
  UserActivityEntity activity,
  AppLocalizations l10n,
) {
  final parsed = DateTime.tryParse(activity.createdAt);
  if (parsed == null) return l10n.adminActivityJustNow;
  final formatted = formatInboxTime(parsed, l10n);
  return formatted.isEmpty ? l10n.adminActivityJustNow : formatted;
}

String? activityThumbnailUrl(UserActivityEntity activity) {
  final d = activity.details;
  for (final key in ['thumbnailUrl', 'postThumbnailUrl', 'imageUrl']) {
    final value = _str(d[key]);
    if (value != null && MediaUtils.isLikelyImageUrl(value)) {
      return MediaUtils.resolveAbsoluteUrl(value);
    }
  }
  return null;
}

String? activityPostId(UserActivityEntity activity) {
  final id = activity.details['postId'];
  if (id == null) return null;
  final s = id.toString().trim();
  return s.isEmpty ? null : s;
}

String? activityReceiverId(UserActivityEntity activity) {
  final id = activity.details['receiverId'];
  if (id == null) return null;
  final s = id.toString().trim();
  return s.isEmpty ? null : s;
}

String? _str(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}
