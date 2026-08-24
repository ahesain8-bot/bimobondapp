import 'package:bimobondapp/app/auctions/domain/usecases/get_active_auctions_usecase.dart';
import 'package:bimobondapp/app/marketplace/presentation/bloc/marketplace_home_state.dart';
import 'package:bimobondapp/app/shop/domain/repositories/shop_repository.dart';
import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class MarketplaceHomeEvent {}

class MarketplaceHomeStarted extends MarketplaceHomeEvent {}

class MarketplaceHomeRefreshed extends MarketplaceHomeEvent {}

class MarketplaceHomeBloc
    extends Bloc<MarketplaceHomeEvent, MarketplaceHomeState> {
  MarketplaceHomeBloc({
    required GetProductCategoriesUseCase getProductCategoriesUseCase,
    required GetPlatformShopUseCase getPlatformShopUseCase,
    required GetActiveAuctionsUseCase getActiveAuctionsUseCase,
  })  : _getProductCategoriesUseCase = getProductCategoriesUseCase,
        _getPlatformShopUseCase = getPlatformShopUseCase,
        _getActiveAuctionsUseCase = getActiveAuctionsUseCase,
        super(const MarketplaceHomeState()) {
    on<MarketplaceHomeStarted>(_onStarted);
    on<MarketplaceHomeRefreshed>(_onRefreshed);
  }

  final GetProductCategoriesUseCase _getProductCategoriesUseCase;
  final GetPlatformShopUseCase _getPlatformShopUseCase;
  final GetActiveAuctionsUseCase _getActiveAuctionsUseCase;

  Future<void> _onStarted(
    MarketplaceHomeStarted event,
    Emitter<MarketplaceHomeState> emit,
  ) async {
    emit(state.copyWith(loading: true, clearError: true));
    await _load(emit, refreshing: false);
  }

  Future<void> _onRefreshed(
    MarketplaceHomeRefreshed event,
    Emitter<MarketplaceHomeState> emit,
  ) async {
    emit(state.copyWith(refreshing: true, clearError: true));
    await _load(emit, refreshing: true);
  }

  Future<void> _load(
    Emitter<MarketplaceHomeState> emit, {
    required bool refreshing,
  }) async {
    final categoriesResult = await _getProductCategoriesUseCase();
    final shopResult = await _getPlatformShopUseCase(
      const BrowseProductsParams(limit: 12, sortBy: 'sortOrder'),
    );
    final auctionsResult = await _getActiveAuctionsUseCase(NoParams());

    String? error;
    var categories = state.categories;
    var recommended = state.recommended;
    var auctions = state.endingSoonAuctions;

    categoriesResult.fold(
      (f) => error ??= ErrorMessageResolver.resolve(f),
      (list) {
        categories = [...list]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      },
    );

    shopResult.fold(
      (f) => error ??= ErrorMessageResolver.resolve(f),
      (page) => recommended = page.page.items,
    );

    auctionsResult.fold(
      (f) => error ??= ErrorMessageResolver.resolve(f),
      (list) {
        auctions = [...list]
            .where((a) => a.isActive && a.endedAt != null)
            .toList()
          ..sort((a, b) {
            final ae = a.endedAt!.toUtc();
            final be = b.endedAt!.toUtc();
            return ae.compareTo(be);
          });
        auctions = auctions.take(8).toList();
      },
    );

    emit(
      state.copyWith(
        loading: false,
        refreshing: false,
        error: error,
        clearError: error == null,
        categories: categories,
        recommended: recommended,
        endingSoonAuctions: auctions,
      ),
    );
  }
}
