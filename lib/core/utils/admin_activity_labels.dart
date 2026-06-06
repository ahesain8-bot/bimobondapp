import 'package:bimobondapp/app/auth/domain/entities/user_activity_entity.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

IconData adminActivityIcon(String type) {
  switch (type.toUpperCase()) {
    case 'CREATE_POST':
      return LucideIcons.video;
    case 'COMMENT':
      return LucideIcons.messageSquare;
    case 'LIKE_POST':
      return LucideIcons.heart;
    case 'SEND_GIFT':
      return LucideIcons.gift;
    default:
      return LucideIcons.activity;
  }
}

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
  final d = activity.details;
  switch (activity.type.toUpperCase()) {
    case 'CREATE_POST':
      return _str(d['description']) ?? l10n.adminActivityNoDetails;
    case 'COMMENT':
      final content = _str(d['content']);
      final post = _str(d['postDescription']);
      if (content != null && post != null) {
        return '$content\n${l10n.adminActivityOnPost(post)}';
      }
      return content ?? post ?? l10n.adminActivityNoDetails;
    case 'LIKE_POST':
      return _str(d['postDescription']) ?? l10n.adminActivityNoDetails;
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
      return parts.isEmpty ? l10n.adminActivityNoDetails : parts.join(' · ');
    default:
      return l10n.adminActivityNoDetails;
  }
}

String? formatAdminActivityTime(String createdAt, String localeName) {
  final parsed = DateTime.tryParse(createdAt);
  if (parsed == null) return null;
  final local = parsed.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return '';
  if (diff.inHours < 24) {
    return DateFormat.jm(localeName).format(local);
  }
  if (diff.inDays < 7) {
    return DateFormat.E(localeName).add_jm().format(local);
  }
  return DateFormat.yMMMd(localeName).add_jm().format(local);
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
