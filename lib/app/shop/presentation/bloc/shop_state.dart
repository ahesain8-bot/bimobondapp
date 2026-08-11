import 'package:bimobondapp/app/shop/domain/entities/cart_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/order_entity.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:equatable/equatable.dart';

class ShopState extends Equatable {
  const ShopState({
    this.products = const [],
    this.productsByCategory = const {},
    this.categories = const [],
    this.selectedCategoryId,
    this.searchQuery = '',
    this.sortBy = 'sortOrder',
    this.sortOrder = 'asc',
    this.page = 1,
    this.hasMore = true,
    this.loading = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.error,
    this.cart,
    this.cartCount = 0,
    this.selectedProduct,
    this.loadingProduct = false,
    this.orders = const [],
    this.loadingOrders = false,
    this.checkoutPreview,
    this.addingToCart = false,
  });

  final List<ProductEntity> products;
  /// Preview rows for the All-categories home (horizontal lists).
  final Map<String, List<ProductEntity>> productsByCategory;
  final List<ProductCategoryEntity> categories;
  final String? selectedCategoryId;
  final String searchQuery;
  final String sortBy;
  final String sortOrder;
  final int page;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final bool refreshing;
  final String? error;
  final CartEntity? cart;
  final int cartCount;
  final ProductEntity? selectedProduct;
  final bool loadingProduct;
  final List<ProductOrderEntity> orders;
  final bool loadingOrders;
  final CheckoutPreviewEntity? checkoutPreview;
  final bool addingToCart;

  ShopState copyWith({
    List<ProductEntity>? products,
    Map<String, List<ProductEntity>>? productsByCategory,
    List<ProductCategoryEntity>? categories,
    String? selectedCategoryId,
    bool clearSelectedCategoryId = false,
    String? searchQuery,
    String? sortBy,
    String? sortOrder,
    int? page,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    bool? refreshing,
    String? error,
    bool clearError = false,
    CartEntity? cart,
    bool clearCart = false,
    int? cartCount,
    ProductEntity? selectedProduct,
    bool clearSelectedProduct = false,
    bool? loadingProduct,
    List<ProductOrderEntity>? orders,
    bool? loadingOrders,
    CheckoutPreviewEntity? checkoutPreview,
    bool clearCheckoutPreview = false,
    bool? addingToCart,
  }) {
    return ShopState(
      products: products ?? this.products,
      productsByCategory: productsByCategory ?? this.productsByCategory,
      categories: categories ?? this.categories,
      selectedCategoryId: clearSelectedCategoryId
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
      cart: clearCart ? null : (cart ?? this.cart),
      cartCount: cartCount ?? this.cartCount,
      selectedProduct: clearSelectedProduct
          ? null
          : (selectedProduct ?? this.selectedProduct),
      loadingProduct: loadingProduct ?? this.loadingProduct,
      orders: orders ?? this.orders,
      loadingOrders: loadingOrders ?? this.loadingOrders,
      checkoutPreview: clearCheckoutPreview
          ? null
          : (checkoutPreview ?? this.checkoutPreview),
      addingToCart: addingToCart ?? this.addingToCart,
    );
  }

  @override
  List<Object?> get props => [
        products,
        productsByCategory,
        categories,
        selectedCategoryId,
        searchQuery,
        sortBy,
        sortOrder,
        page,
        hasMore,
        loading,
        loadingMore,
        refreshing,
        error,
        cart,
        cartCount,
        selectedProduct,
        loadingProduct,
        orders,
        loadingOrders,
        checkoutPreview,
        addingToCart,
      ];
}
