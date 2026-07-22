import 'package:bimobondapp/app/auctions/domain/entities/auction_fulfillment_entity.dart';
import 'package:bimobondapp/app/auctions/domain/repositories/auctions_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetAuctionFulfillmentUseCase
    implements UseCase<AuctionFulfillmentEntity, GetAuctionFulfillmentParams> {
  GetAuctionFulfillmentUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, AuctionFulfillmentEntity>> call(
    GetAuctionFulfillmentParams params,
  ) {
    return repository.getFulfillment(params.auctionId);
  }
}

class GetAuctionFulfillmentParams extends Equatable {
  const GetAuctionFulfillmentParams(this.auctionId);

  final String auctionId;

  @override
  List<Object?> get props => [auctionId];
}

class ShipAuctionFulfillmentUseCase
    implements UseCase<AuctionFulfillmentEntity, ShipAuctionFulfillmentParams> {
  ShipAuctionFulfillmentUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, AuctionFulfillmentEntity>> call(
    ShipAuctionFulfillmentParams params,
  ) {
    return repository.shipFulfillment(
      params.auctionId,
      trackingNumber: params.trackingNumber,
      shippingNote: params.shippingNote,
    );
  }
}

class ShipAuctionFulfillmentParams extends Equatable {
  const ShipAuctionFulfillmentParams({
    required this.auctionId,
    this.trackingNumber,
    this.shippingNote,
  });

  final String auctionId;
  final String? trackingNumber;
  final String? shippingNote;

  @override
  List<Object?> get props => [auctionId, trackingNumber, shippingNote];
}

class ReceiveAuctionFulfillmentUseCase
    implements UseCase<AuctionFulfillmentEntity, String> {
  ReceiveAuctionFulfillmentUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, AuctionFulfillmentEntity>> call(String auctionId) {
    return repository.receiveFulfillment(auctionId);
  }
}

class AcceptAuctionFulfillmentUseCase
    implements UseCase<AuctionFulfillmentEntity, String> {
  AcceptAuctionFulfillmentUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, AuctionFulfillmentEntity>> call(String auctionId) {
    return repository.acceptFulfillment(auctionId);
  }
}

class DisputeAuctionFulfillmentUseCase
    implements
        UseCase<AuctionFulfillmentEntity, DisputeAuctionFulfillmentParams> {
  DisputeAuctionFulfillmentUseCase(this.repository);

  final AuctionsRepository repository;

  @override
  Future<Either<Failure, AuctionFulfillmentEntity>> call(
    DisputeAuctionFulfillmentParams params,
  ) {
    return repository.disputeFulfillment(
      params.auctionId,
      reason: params.reason,
    );
  }
}

class DisputeAuctionFulfillmentParams extends Equatable {
  const DisputeAuctionFulfillmentParams({
    required this.auctionId,
    this.reason,
  });

  final String auctionId;
  final String? reason;

  @override
  List<Object?> get props => [auctionId, reason];
}
