/// A gift the room should celebrate, held just long enough to animate.
class LiveGiftBanner {
  const LiveGiftBanner({
    required this.id,
    required this.senderName,
    this.senderAvatarUrl,
    this.giftName,
    this.giftIcon,
    this.giftImageUrl,
    this.quantity,
    this.gifterLevel,
  });

  /// Distinguishes consecutive gifts so the banner restarts its animation
  /// even when the same person sends the same gift twice.
  final String id;

  final String senderName;
  final String? senderAvatarUrl;
  final String? giftName;
  final String? giftIcon;
  final String? giftImageUrl;
  final int? quantity;
  final int? gifterLevel;

  /// TikTok only shows the multiplier once there is more than one.
  bool get showsMultiplier => (quantity ?? 1) > 1;
}
