import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:equatable/equatable.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';

class MarketplaceCategoryConfig extends Equatable {
  const MarketplaceCategoryConfig({
    required this.slug,
    required this.fallbackName,
    required this.icon,
    this.emoji,
  });

  final String slug;
  final String fallbackName;
  final IconData icon;
  final String? emoji;

  @override
  List<Object?> get props => [slug, fallbackName, icon, emoji];
}

/// Static marketplace categories aligned with Bimo-Bond design.
const kMarketplaceCategories = <MarketplaceCategoryConfig>[
  MarketplaceCategoryConfig(
    slug: 'phones',
    fallbackName: 'Phones',
    icon: LucideIcons.smartphone,
    emoji: '📱',
  ),
  MarketplaceCategoryConfig(
    slug: 'laptops',
    fallbackName: 'Laptops',
    icon: LucideIcons.laptop,
    emoji: '💻',
  ),
  MarketplaceCategoryConfig(
    slug: 'cars',
    fallbackName: 'Cars',
    icon: LucideIcons.car,
    emoji: '🚗',
  ),
  MarketplaceCategoryConfig(
    slug: 'electronics',
    fallbackName: 'Electronics',
    icon: LucideIcons.headphones,
    emoji: '🎧',
  ),
  MarketplaceCategoryConfig(
    slug: 'fashion',
    fallbackName: 'Fashion',
    icon: LucideIcons.shirt,
    emoji: '👕',
  ),
  MarketplaceCategoryConfig(
    slug: 'watches',
    fallbackName: 'Watches',
    icon: LucideIcons.watch,
    emoji: '⌚',
  ),
  MarketplaceCategoryConfig(
    slug: 'properties',
    fallbackName: 'Properties',
    icon: LucideIcons.house,
    emoji: '🏠',
  ),
  MarketplaceCategoryConfig(
    slug: 'buildings',
    fallbackName: 'Buildings',
    icon: LucideIcons.building2,
    emoji: '🏢',
  ),
  MarketplaceCategoryConfig(
    slug: 'apartments',
    fallbackName: 'Apartments',
    icon: LucideIcons.building,
    emoji: '🏘',
  ),
  MarketplaceCategoryConfig(
    slug: 'land',
    fallbackName: 'Land',
    icon: LucideIcons.map,
    emoji: '🌍',
  ),
  MarketplaceCategoryConfig(
    slug: 'jewelry',
    fallbackName: 'Jewelry',
    icon: LucideIcons.gem,
    emoji: '💎',
  ),
  MarketplaceCategoryConfig(
    slug: 'other',
    fallbackName: 'Other',
    icon: LucideIcons.grid2x2,
    emoji: '•••',
  ),
];

MarketplaceCategoryConfig categoryConfigForSlug(String? slug) {
  if (slug == null || slug.isEmpty) return kMarketplaceCategories.last;
  final normalized = slug.toLowerCase();
  return kMarketplaceCategories.firstWhere(
    (c) => c.slug == normalized,
    orElse: () => kMarketplaceCategories.last,
  );
}

MarketplaceCategoryConfig categoryConfigForEntity(ProductCategoryEntity? cat) {
  if (cat == null) return kMarketplaceCategories.last;
  final bySlug = kMarketplaceCategories.where(
    (c) => c.slug == cat.slug.toLowerCase(),
  );
  if (bySlug.isNotEmpty) return bySlug.first;
  final byName = kMarketplaceCategories.where(
    (c) => cat.name.toLowerCase().contains(c.slug),
  );
  if (byName.isNotEmpty) return byName.first;
  return MarketplaceCategoryConfig(
    slug: cat.slug,
    fallbackName: cat.name,
    icon: LucideIcons.tag,
  );
}

const kPhoneBrands = [
  'All',
  'Apple',
  'Samsung',
  'Google',
  'OnePlus',
  'Xiaomi',
  'Other',
];

bool isPropertyCategory(String? slug) {
  if (slug == null) return false;
  const propertySlugs = {'properties', 'buildings', 'apartments', 'land'};
  return propertySlugs.contains(slug.toLowerCase());
}

bool isAssetCategory(String? slug) => isPropertyCategory(slug);
