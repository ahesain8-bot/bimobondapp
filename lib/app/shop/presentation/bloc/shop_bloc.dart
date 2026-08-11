import 'dart:async';

import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/app/shop/domain/repositories/shop_repository.dart';
import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:bimobondapp/app/shop/presentation/cubit/shop_cart_cubit.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart'
    as shop_di;
import 'package:bimobondapp/app/shop/presentation/bloc/shop_event.dart';
import 'package:bimobondapp/app/shop/presentation/bloc/shop_state.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _ShopSearchDebounced extends ShopEvent {
  const _ShopSearchDebounced(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class ShopBloc extends Bloc<ShopEvent, ShopState> {
  ShopBloc({
    required GetPlatformShopUseCase getPlatformShopUseCase,
    required GetProductCategoriesUseCase getProductCategoriesUseCase,
    required GetCartUseCase getCartUseCase,
    required AddCartItemUseCase addCartItemUseCase,
    required GetProductUseCase getProductUseCase,
    required PreviewCheckoutUseCase previewCheckoutUseCase,
    required CheckoutUseCase checkoutUseCase,
    required GetMyOrdersUseCase getMyOrdersUseCase,
    required GetOrderUseCase getOrderUseCase,
  }) : _getPlatformShopUseCase = getPlatformShopUseCase,
       _getProductCategoriesUseCase = getProductCategoriesUseCase,
       _getCartUseCase = getCartUseCase,
       _addCartItemUseCase = addCartItemUseCase,
       _getProductUseCase = getProductUseCase,
       _previewCheckoutUseCase = previewCheckoutUseCase,
       _checkoutUseCase = checkoutUseCase,
       _getMyOrdersUseCase = getMyOrdersUseCase,
       _getOrderUseCase = getOrderUseCase,
       super(const ShopState()) {
    on<ShopStarted>(_onStarted);
    on<ShopRefreshed>(_onRefreshed);
    on<ShopCategorySelected>(_onCategorySelected);
    on<ShopSearchChanged>(_onSearchChanged);
    on<_ShopSearchDebounced>(_onSearchDebounced);
    on<ShopSortChanged>(_onSortChanged);
    on<ShopLoadMore>(_onLoadMore);
    on<ShopAddToCart>(_onAddToCart);
    on<ShopLoadCart>(_onLoadCart);
    on<ShopLoadProduct>(_onLoadProduct);
    on<ShopLoadOrders>(_onLoadOrders);
  }

  final GetPlatformShopUseCase _getPlatformShopUseCase;
  final GetProductCategoriesUseCase _getProductCategoriesUseCase;
  final GetCartUseCase _getCartUseCase;
  final AddCartItemUseCase _addCartItemUseCase;
  final GetProductUseCase _getProductUseCase;
  // Reserved for checkout/order flows wired in dedicated screens.
  // ignore: unused_field
  final PreviewCheckoutUseCase _previewCheckoutUseCase;
  // ignore: unused_field
  final CheckoutUseCase _checkoutUseCase;
  final GetMyOrdersUseCase _getMyOrdersUseCase;
  // ignore: unused_field
  final GetOrderUseCase _getOrderUseCase;

  Timer? _searchDebounce;

  static const _pageSize = 20;
  static const _categoryPreviewLimit = 12;
  static const _searchDebounceMs = 350;

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }

  Future<void> _onStarted(ShopStarted event, Emitter<ShopState> emit) async {
    emit(state.copyWith(loading: true, clearError: true));

    final categoriesResult = await _getProductCategoriesUseCase();
    final categoriesError = categoriesResult.fold<String?>(
      (failure) => ErrorMessageResolver.resolve(failure),
      (_) => null,
    );
    final sorted = categoriesResult.fold<List<ProductCategoryEntity>>(
      (_) => const [],
      (categories) {
        final list = [...categories]
          ..sort((a, b) {
            final byOrder = a.sortOrder.compareTo(b.sortOrder);
            if (byOrder != 0) return byOrder;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return list;
      },
    );

    // Keep categories in state for product fetch, but UI stays on one skeleton
    // until loading flips false (avoid categories flash + second loader).
    if (sorted.isNotEmpty) {
      emit(state.copyWith(categories: sorted));
    } else if (categoriesError != null) {
      emit(
        state.copyWith(
          loading: false,
          error: categoriesError,
        ),
      );
      return;
    }

    await _fetchProducts(emit, page: 1, append: false);
    await _loadCartSilently(emit);

    emit(state.copyWith(loading: false));
  }

  Future<void> _onRefreshed(
    ShopRefreshed event,
    Emitter<ShopState> emit,
  ) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    await _fetchProducts(emit, page: 1, append: false);
    await _loadCartSilently(emit);
    emit(state.copyWith(refreshing: false));
  }

  Future<void> _onCategorySelected(
    ShopCategorySelected event,
    Emitter<ShopState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedCategoryId: event.categoryId,
        clearSelectedCategoryId: event.categoryId == null,
        loading: true,
        clearError: true,
        products: const [],
        productsByCategory: const {},
        page: 1,
        hasMore: event.categoryId != null,
      ),
    );
    await _fetchProducts(emit, page: 1, append: false);
    emit(state.copyWith(loading: false));
  }

  void _onSearchChanged(ShopSearchChanged event, Emitter<ShopState> emit) {
    _searchDebounce?.cancel();
    emit(state.copyWith(searchQuery: event.query));
    _searchDebounce = Timer(
      const Duration(milliseconds: _searchDebounceMs),
      () => add(_ShopSearchDebounced(event.query)),
    );
  }

  Future<void> _onSearchDebounced(
    _ShopSearchDebounced event,
    Emitter<ShopState> emit,
  ) async {
    if (event.query != state.searchQuery) return;
    emit(state.copyWith(loading: true, clearError: true));
    await _fetchProducts(emit, page: 1, append: false);
    emit(state.copyWith(loading: false));
  }

  Future<void> _onSortChanged(
    ShopSortChanged event,
    Emitter<ShopState> emit,
  ) async {
    emit(
      state.copyWith(
        sortBy: event.sortBy,
        sortOrder: event.sortOrder,
        loading: true,
        clearError: true,
      ),
    );
    await _fetchProducts(emit, page: 1, append: false);
    emit(state.copyWith(loading: false));
  }

  Future<void> _onLoadMore(ShopLoadMore event, Emitter<ShopState> emit) async {
    if (state.loadingMore || !state.hasMore || state.loading) return;

    emit(state.copyWith(loadingMore: true, clearError: true));
    await _fetchProducts(emit, page: state.page + 1, append: true);
    emit(state.copyWith(loadingMore: false));
  }

  Future<void> _onAddToCart(
    ShopAddToCart event,
    Emitter<ShopState> emit,
  ) async {
    emit(state.copyWith(addingToCart: true, clearError: true));

    final result = await _addCartItemUseCase(
      productId: event.productId,
      variantId: event.variantId,
      quantity: event.quantity,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          addingToCart: false,
          error: ErrorMessageResolver.resolve(failure),
        ),
      ),
      (cart) {
        emit(
          state.copyWith(
            addingToCart: false,
            cart: cart,
            cartCount: cart.itemCount,
          ),
        );
        shop_di.sl<ShopCartCubit>().refresh();
      },
    );
  }

  Future<void> _onLoadCart(ShopLoadCart event, Emitter<ShopState> emit) async {
    await _loadCart(emit);
  }

  Future<void> _onLoadProduct(
    ShopLoadProduct event,
    Emitter<ShopState> emit,
  ) async {
    emit(
      state.copyWith(
        loadingProduct: true,
        clearSelectedProduct: true,
        clearError: true,
      ),
    );

    final result = await _getProductUseCase(event.productId);
    result.fold(
      (failure) => emit(
        state.copyWith(
          loadingProduct: false,
          error: ErrorMessageResolver.resolve(failure),
        ),
      ),
      (product) =>
          emit(state.copyWith(loadingProduct: false, selectedProduct: product)),
    );
  }

  Future<void> _onLoadOrders(
    ShopLoadOrders event,
    Emitter<ShopState> emit,
  ) async {
    emit(state.copyWith(loadingOrders: true, clearError: true));

    final result = await _getMyOrdersUseCase(page: event.page);
    result.fold(
      (failure) => emit(
        state.copyWith(
          loadingOrders: false,
          error: ErrorMessageResolver.resolve(failure),
        ),
      ),
      (page) => emit(
        state.copyWith(
          loadingOrders: false,
          orders: event.page == 1
              ? page.items
              : [...state.orders, ...page.items],
        ),
      ),
    );
  }

  Future<void> _fetchProducts(
    Emitter<ShopState> emit, {
    required int page,
    required bool append,
  }) async {
    // All categories: one horizontal preview list per category.
    if (state.selectedCategoryId == null && page == 1 && !append) {
      await _fetchProductsByCategory(emit);
      return;
    }

    final params = BrowseProductsParams(
      page: page,
      limit: _pageSize,
      productCategoryId: state.selectedCategoryId,
      search: state.searchQuery.trim().isEmpty
          ? null
          : state.searchQuery.trim(),
      sortBy: state.sortBy,
      sortOrder: state.sortOrder,
    );

    final result = await _getPlatformShopUseCase(params);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: ErrorMessageResolver.resolve(failure))),
      (platformShop) {
        final shopPage = platformShop.page;
        final products = append
            ? _mergeProducts(state.products, shopPage.items)
            : shopPage.items;

        emit(
          state.copyWith(
            products: products,
            productsByCategory: const {},
            page: shopPage.page,
            hasMore: shopPage.hasMore,
          ),
        );
      },
    );
  }

  Future<void> _fetchProductsByCategory(Emitter<ShopState> emit) async {
    final categories = state.categories;
    if (categories.isEmpty) {
      final params = BrowseProductsParams(
        page: 1,
        limit: _pageSize,
        search: state.searchQuery.trim().isEmpty
            ? null
            : state.searchQuery.trim(),
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
      );
      final result = await _getPlatformShopUseCase(params);
      result.fold(
        (failure) =>
            emit(state.copyWith(error: ErrorMessageResolver.resolve(failure))),
        (platformShop) {
          final shopPage = platformShop.page;
          emit(
            state.copyWith(
              products: shopPage.items,
              productsByCategory: const {},
              page: shopPage.page,
              hasMore: shopPage.hasMore,
            ),
          );
        },
      );
      return;
    }

    final search = state.searchQuery.trim().isEmpty
        ? null
        : state.searchQuery.trim();
    final map = <String, List<ProductEntity>>{};

    await Future.wait(
      categories.map((category) async {
        final result = await _getPlatformShopUseCase(
          BrowseProductsParams(
            page: 1,
            limit: _categoryPreviewLimit,
            productCategoryId: category.id,
            search: search,
            sortBy: 'sortOrder',
            sortOrder: 'asc',
          ),
        );
        result.fold(
          (_) {},
          (platformShop) {
            final items = [...platformShop.page.items]
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            map[category.id] = items;
          },
        );
      }),
    );

    // Order category chips / carousels by the lowest product.sortOrder in
    // each category (matches GET /products/shop?sortBy=sortOrder).
    final orderedCategories = [...categories]
      ..sort((a, b) {
        final byProductOrder = _minProductSortOrder(map[a.id])
            .compareTo(_minProductSortOrder(map[b.id]));
        if (byProductOrder != 0) return byProductOrder;
        final byCategoryOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byCategoryOrder != 0) return byCategoryOrder;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final flat = <ProductEntity>[];
    for (final category in orderedCategories) {
      flat.addAll(map[category.id] ?? const []);
    }

    emit(
      state.copyWith(
        categories: orderedCategories,
        productsByCategory: Map<String, List<ProductEntity>>.unmodifiable(map),
        products: flat,
        page: 1,
        hasMore: false,
      ),
    );
  }

  int _minProductSortOrder(List<ProductEntity>? items) {
    if (items == null || items.isEmpty) return 1 << 30;
    var min = items.first.sortOrder;
    for (final item in items) {
      if (item.sortOrder < min) min = item.sortOrder;
    }
    return min;
  }

  List<ProductEntity> _mergeProducts(
    List<ProductEntity> existing,
    List<ProductEntity> incoming,
  ) {
    final ids = existing.map((p) => p.id).toSet();
    return [...existing, ...incoming.where((p) => !ids.contains(p.id))];
  }

  Future<void> _loadCartSilently(Emitter<ShopState> emit) async {
    final result = await _getCartUseCase();
    result.fold(
      (_) {},
      (cart) => emit(state.copyWith(cart: cart, cartCount: cart.itemCount)),
    );
  }

  Future<void> _loadCart(Emitter<ShopState> emit) async {
    final result = await _getCartUseCase();
    result.fold(
      (failure) =>
          emit(state.copyWith(error: ErrorMessageResolver.resolve(failure))),
      (cart) => emit(state.copyWith(cart: cart, cartCount: cart.itemCount)),
    );
  }
}
