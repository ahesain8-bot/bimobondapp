import 'package:shared_preferences/shared_preferences.dart';
import 'package:bimobondapp/app/wallets/data/models/wallet_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart';
import 'package:bimobondapp/app/auth/domain/usecases/get_profile_usecase.dart';
import 'package:bimobondapp/app/wallets/domain/usecases/wallet_usecases.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import '../../data/live_promotions_repository.dart';
import '../../domain/live_promotion_models.dart';
import '../controllers/live_promotions_controller.dart';

// Explicit client build configuration, default-on per API documentation.
// No backend environment variable is assumed to arrive in an HTTP response.
const livePromotionsEnabled = bool.fromEnvironment(
  'PROMOTIONS_ENABLED',
  defaultValue: true,
);
Future<void> initLivePromotions() async {
  sl.registerLazySingleton<LivePromotionsRepository>(
    () => LivePromotionsRepository(
      dio: sl<ApiClient>().dio,
      initialUncertainPayments:
          sl<SharedPreferences>()
              .getStringList('LIVE_PROMOTION_UNCERTAIN_PAYMENTS')
              ?.toSet() ??
          {},
      persistUncertainPayments: (ids) async {
        final saved = await sl<SharedPreferences>().setStringList(
          'LIVE_PROMOTION_UNCERTAIN_PAYMENTS',
          ids.toList(),
        );
        if (!saved) throw const LivePromotionUnavailable();
      },
      idTokenProvider: () =>
          FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(null),
    ),
  );
}

Future<int> refreshLivePromotionWallet() async {
  final result = await sl<GetMyWalletUseCase>()(NoParams());
  return result.fold((f) => throw const LivePromotionUnavailable(), (wallet) {
    if (wallet is! WalletModel || !wallet.hasVerifiedCoinBalance) {
      throw const LivePromotionUnavailable();
    }
    return wallet.balanceCoins;
  });
}

Future<LivePromotionEligibility> refreshLivePromotionEligibility(
  String liveId,
) async {
  final profile = await sl<GetProfileUseCase>()(NoParams());
  final user = profile.fold(
    (f) => throw const LivePromotionUnavailable(),
    (u) => u,
  );
  final api = sl<LiveApiClient>();
  final live = await api.get('/lives/${Uri.encodeComponent(liveId)}');
  // Public visibility is NOT in the supplied live-object schema. Never infer
  // it from guestRequestMode or account privacy. Await the verified adapter.
  return LivePromotionEligibility(
    liveId: liveId,
    authenticatedUserId: user.id,
    hostUserId: live['userId'] is String ? live['userId'] as String : null,
    liveStatus: live['status'] is String ? live['status'] as String : null,
    visibility: null,
    accountPrivate: user.isPrivate,
    accountBanned: user.isBanned,
    promotionsEnabled: livePromotionsEnabled,
  );
}

LivePromotionsController createLivePromotionsController() =>
    LivePromotionsController(
      repository: sl<LivePromotionsRepository>(),
      refreshWallet: refreshLivePromotionWallet,
      refreshEligibility: refreshLivePromotionEligibility,
    );
