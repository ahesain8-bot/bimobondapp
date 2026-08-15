/// Shop / auction item shown in the live gallery tab.
class LiveGalleryItem {
  const LiveGalleryItem({
    required this.id,
    required this.itemName,
    this.itemImageUrl,
    this.pinned = false,
    this.status,
    this.targetPrice,
    this.currentPrice,
  });

  final String id;
  final String itemName;
  final String? itemImageUrl;
  final bool pinned;
  final String? status;
  final num? targetPrice;
  final num? currentPrice;
}
