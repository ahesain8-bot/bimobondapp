import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ShopCartCubit extends Cubit<int> {
  ShopCartCubit({required GetCartUseCase getCartUseCase})
      : _getCartUseCase = getCartUseCase,
        super(0);

  final GetCartUseCase _getCartUseCase;

  void setCount(int count) {
    if (!isClosed) emit(count < 0 ? 0 : count);
  }

  void clear() => setCount(0);

  Future<void> refresh() async {
    final result = await _getCartUseCase();
    result.fold(
      (_) {},
      (cart) {
        if (!isClosed) emit(cart.itemCount);
      },
    );
  }
}
