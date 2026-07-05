import 'dart:io';

import 'package:bimobondapp/app/sounds/data/datasources/sounds_remote_data_source.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/repositories/sounds_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class SoundsRepositoryImpl implements SoundsRepository {
  SoundsRepositoryImpl({required this.remoteDataSource});

  final SoundsRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, SoundsPageEntity>> getSounds({
    int page = 1,
    int limit = 20,
    String? search,
    SoundSort sort = SoundSort.trending,
    String? creatorId,
  }) async {
    try {
      final pageResult = await remoteDataSource.getSounds(
        page: page,
        limit: limit,
        search: search,
        sort: sort,
        creatorId: creatorId,
      );
      return Right(pageResult);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, List<SoundEntity>>> getTrending({
    int limit = 30,
  }) async {
    try {
      final sounds = await remoteDataSource.getTrending(limit: limit);
      return Right(sounds);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundsPageEntity>> getMySounds({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final pageResult = await remoteDataSource.getMySounds(
        page: page,
        limit: limit,
      );
      return Right(pageResult);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundDetailEntity>> getSoundById(String id) async {
    try {
      final detail = await remoteDataSource.getSoundById(id);
      return Right(detail);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SoundEntity>> uploadSound({
    required File audio,
    required int duration,
    String? name,
  }) async {
    try {
      final sound = await remoteDataSource.uploadSound(
        audio: audio,
        duration: duration,
        name: name,
      );
      return Right(sound);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
