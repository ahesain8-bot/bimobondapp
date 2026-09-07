/// Shop / auction item shown in the live gallery tab.
class LiveGalleryItem {
  const LiveGalleryItem({
    required this.id,
    required this.itemName,
    this.itemImageUrl,
    this.pinned = false,
    this.pinOrder,
    this.status,
    this.targetPrice,
    this.currentPrice,
  });

  final String id;
  final String itemName;
  final String? itemImageUrl;
  final bool pinned;

  /// Display order the server assigns (`pinned` first, then `pinOrder`).
  /// Null when the server did not send one; the snapshot order is kept as-is.
  final int? pinOrder;
  final String? status;
  final num? targetPrice;
  final num? currentPrice;
}
