import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:equatable/equatable.dart';

class GiftGroupEntity extends Equatable {
  const GiftGroupEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.sortOrder,
    required this.gifts,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String slug;
  final int sortOrder;
  final String? iconUrl;
  final List<GiftEntity> gifts;

  /// Tab label from catalog API ([name]).
  String get tabLabel {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final slugLabel = slug.trim();
    if (slugLabel.isEmpty) return '';
    return slugLabel
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  bool get isSongsShelf {
    final s = slug.toLowerCase();
    final n = name.toLowerCase();
    return s.contains('song') ||
        s.contains('music') ||
        s.contains('audio') ||
        n.contains('song') ||
        n.contains('music');
  }

  @override
  List<Object?> get props => [id, name, slug, sortOrder, iconUrl, gifts];
}
