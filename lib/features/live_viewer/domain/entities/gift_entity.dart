import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class GiftEntity extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String iconUrl;
  final String? animationUrl;
  final int coinCost;
  final GiftRarity rarity;
  final bool hasAnimation;
  final int? durationMs;
  final Map<String, dynamic>? metadata;

  const GiftEntity({
    required this.id,
    required this.name,
    this.description,
    required this.iconUrl,
    this.animationUrl,
    required this.coinCost,
    this.rarity = GiftRarity.common,
    this.hasAnimation = false,
    this.durationMs,
    this.metadata,
  });

  GiftEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    String? animationUrl,
    int? coinCost,
    GiftRarity? rarity,
    bool? hasAnimation,
    int? durationMs,
    Map<String, dynamic>? metadata,
  }) {
    return GiftEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      animationUrl: animationUrl ?? this.animationUrl,
      coinCost: coinCost ?? this.coinCost,
      rarity: rarity ?? this.rarity,
      hasAnimation: hasAnimation ?? this.hasAnimation,
      durationMs: durationMs ?? this.durationMs,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        iconUrl,
        animationUrl,
        coinCost,
        rarity,
        hasAnimation,
        durationMs,
        metadata,
      ];
}

enum GiftRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
  mythic,
}

extension GiftRarityExtension on GiftRarity {
  String get displayName {
    switch (this) {
      case GiftRarity.common:
        return 'Common';
      case GiftRarity.uncommon:
        return 'Uncommon';
      case GiftRarity.rare:
        return 'Rare';
      case GiftRarity.epic:
        return 'Epic';
      case GiftRarity.legendary:
        return 'Legendary';
      case GiftRarity.mythic:
        return 'Mythic';
    }
  }

  int get colorValue {
    switch (this) {
      case GiftRarity.common:
        return 0xFFB3B3B3;
      case GiftRarity.uncommon:
        return 0xFF00C853;
      case GiftRarity.rare:
        return 0xFF00B0FF;
      case GiftRarity.epic:
        return 0xFFAA00FF;
      case GiftRarity.legendary:
        return 0xFFFFD700;
      case GiftRarity.mythic:
        return 0xFFFF0050;
    }
  }

  Color get color => Color(colorValue);
}

class GiftSentEntity extends Equatable {
  final String id;
  final String giftId;
  final String liveId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final int quantity;
  final int totalCost;
  final DateTime sentAt;
  final GiftEntity? giftDetails;

  const GiftSentEntity({
    required this.id,
    required this.giftId,
    required this.liveId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.quantity = 1,
    required this.totalCost,
    required this.sentAt,
    this.giftDetails,
  });

  @override
  List<Object?> get props => [
        id,
        giftId,
        liveId,
        senderId,
        senderName,
        senderAvatar,
        quantity,
        totalCost,
        sentAt,
        giftDetails,
      ];
}
