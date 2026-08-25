import 'package:bimobondapp/app/calls/domain/repositories/calls_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class GetCallHistoryUseCase {
  final CallsRepository repository;

  GetCallHistoryUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
  }) {
    return repository.getCallHistory(
      page: page,
      limit: limit,
      status: status,
      type: type,
    );
  }
}
