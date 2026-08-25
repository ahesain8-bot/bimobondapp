import 'package:bimobondapp/app/marketplace/domain/utils/marketplace_category_config.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:equatable/equatable.dart';

class MarketplaceSpecLine extends Equatable {
  const MarketplaceSpecLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  List<Object?> get props => [label, value];
}

/// Builds category-aware specification lines from product data.
class MarketplaceSpecBuilder {
  const MarketplaceSpecBuilder._();

  static String shortSubtitle(ProductEntity product) {
    final attrs = _mergedAttributes(product);
    final slug = product.productCategory?.slug.toLowerCase();

    if (isPropertyCategory(slug)) {
      final beds = attrs['bedrooms'] ?? attrs['beds'];
      final baths = attrs['bathrooms'] ?? attrs['baths'];
      final area = attrs['area'] ?? attrs['size'];
      final parts = <String>[];
      if (beds != null) parts.add('$beds Bed');
      if (baths != null) parts.add('$baths Bath');
      if (area != null) parts.add('$area m²');
      if (parts.isNotEmpty) return parts.join(' • ');
    }

    if (slug == 'buildings') {
      final floors = attrs['floors'];
      final units = attrs['units'];
      final area = attrs['area'];
      final parts = <String>[];
      if (floors != null) parts.add('$floors Floors');
      if (units != null) parts.add('$units Units');
      if (area != null) parts.add('$area m²');
      if (parts.isNotEmpty) return parts.join(' • ');
    }

    if (slug == 'cars') {
      final year = attrs['year'];
      final mileage = attrs['mileage'];
      final parts = <String>[];
      if (year != null) parts.add('$year');
      if (mileage != null) parts.add('$mileage km');
      if (parts.isNotEmpty) return parts.join(' • ');
    }

    final storage = attrs['storage'] ?? attrs['Storage'];
    final color = attrs['color'] ?? attrs['Color'];
    final ram = attrs['ram'] ?? attrs['RAM'];
    final parts = <String>[];
    if (storage != null) parts.add('$storage');
    if (ram != null && storage == null) parts.add('$ram RAM');
    if (color != null) parts.add('$color');
    if (parts.isNotEmpty) return parts.join(' • ');

    if (product.variants.isNotEmpty) {
      return product.variants.first.name;
    }
    return product.description?.split('\n').first.trim() ?? '';
  }

  static List<MarketplaceSpecLine> detailSpecs(ProductEntity product) {
    final slug = product.productCategory?.slug.toLowerCase();
    final attrs = _mergedAttributes(product);

    List<String> keys;
    switch (slug) {
      case 'phones':
        keys = ['storage', 'ram', 'color', 'condition', 'warranty'];
      case 'laptops':
        keys = ['cpu', 'ram', 'storage', 'gpu', 'condition'];
      case 'cars':
        keys = ['brand', 'model', 'year', 'mileage', 'condition'];
      case 'properties':
      case 'apartments':
        keys = [
          'location',
          'area',
          'bedrooms',
          'bathrooms',
          'propertyType',
        ];
      case 'buildings':
        keys = ['location', 'floors', 'units', 'area', 'buildingType'];
      case 'land':
        keys = ['location', 'area', 'zoning', 'condition'];
      default:
        keys = attrs.keys.toList();
    }

    final lines = <MarketplaceSpecLine>[];
    for (final key in keys) {
      final value = attrs[key];
      if (value == null || '$value'.trim().isEmpty) continue;
      lines.add(
        MarketplaceSpecLine(
          label: _labelize(key),
          value: '$value',
        ),
      );
    }

    if (lines.isEmpty && product.description != null) {
      lines.add(
        MarketplaceSpecLine(label: 'Description', value: product.description!),
      );
    }
    return lines;
  }

  static Map<String, dynamic> _mergedAttributes(ProductEntity product) {
    final map = <String, dynamic>{};
    for (final variant in product.variants) {
      map.addAll(variant.attributes);
    }
    return map;
  }

  static String _labelize(String key) {
    if (key.isEmpty) return key;
    final spaced = key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => ' ${m.group(0)}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
