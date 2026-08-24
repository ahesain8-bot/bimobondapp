import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/app/auctions/data/datasources/auctions_remote_data_source.dart';
import 'package:bimobondapp/app/auctions/data/repositories/auctions_repository_impl.dart';
import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/auction_fulfillment_usecases.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/cancel_auction_usecase.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/create_auction_usecase.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/get_active_auctions_usecase.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/get_auction_details_usecase.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/get_auction_pricing_preview_usecase.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/get_auction_seller_eligibility_usecase.dart';
import 'package:bimobondapp/app/auctions/domain/usecases/get_my_auctions_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gifts_usecase.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initAuctions() async {
  sl.registerLazySingleton<AuctionSocketService>(
    () => AuctionSocketService(
      // Server combo payloads are flat (giftId/giftName only), so the catalog
      // supplies the animation url and size the gift renderer needs.
      giftCatalogLoader: () async {
        final result = await sl<GetGiftsUseCase>()(const GetGiftsParams());
        return result.fold((_) => const <GiftEntity>[], (gifts) => gifts);
      },
    ),
  );

  sl.registerLazySingleton<AuctionsRemoteDataSource>(
    () => AuctionsRemoteDataSourceImpl(apiClient: sl()),
  );

  sl.registerLazySingleton<AuctionsRepository>(
    () => AuctionsRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetAuctionDetailsUseCase(sl()));
  sl.registerLazySingleton(() => GetAuctionPricingPreviewUseCase(sl()));
  sl.registerLazySingleton(() => GetActiveAuctionsUseCase(sl()));
  sl.registerLazySingleton(() => GetAuctionSellerEligibilityUseCase(sl()));
  sl.registerLazySingleton(() => CreateAuctionUseCase(sl()));
  sl.registerLazySingleton(() => CancelAuctionUseCase(sl()));
  sl.registerLazySingleton(() => GetMyAuctionsUseCase(sl()));
  sl.registerLazySingleton(() => GetAuctionFulfillmentUseCase(sl()));
  sl.registerLazySingleton(() => ShipAuctionFulfillmentUseCase(sl()));
  sl.registerLazySingleton(() => ReceiveAuctionFulfillmentUseCase(sl()));
  sl.registerLazySingleton(() => AcceptAuctionFulfillmentUseCase(sl()));
  sl.registerLazySingleton(() => DisputeAuctionFulfillmentUseCase(sl()));
}
