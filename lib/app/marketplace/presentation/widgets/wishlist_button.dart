import 'package:bimobondapp/app/shop/data/datasources/shop_favorites_local_store.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart' as shop_di;
import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WishlistButton extends StatefulWidget {
  const WishlistButton({
    required this.productId,
    this.size = 20,
    super.key,
  });

  final String productId;
  final double size;

  @override
  State<WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends State<WishlistButton> {
  late final ShopFavoritesLocalStore _store;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _store = shop_di.sl<ShopFavoritesLocalStore>();
    _isFavorite = _store.isFavorite(widget.productId);
  }

  Future<void> _toggle() async {
    final next = await _store.toggle(widget.productId);
    if (!mounted) return;
    setState(() => _isFavorite = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            _isFavorite ? LucideIcons.heart : LucideIcons.heart,
            size: widget.size,
            color: _isFavorite ? theme.primary : theme.mutedText,
            fill: _isFavorite ? 1.0 : 0.0,
          ),
        ),
      ),
    );
  }
}
